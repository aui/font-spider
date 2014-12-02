package Font::TTF::EBDT;

=head1 NAME

Font::TTF::EBDT - Embeeded Bitmap Data Table

=head1 DESCRIPTION

Contains the metrics and bitmap image data.

=head1 INSTANCE VARIABLES

Only has 'bitmap' instance variable.  It is an array of assosiative
array keyed by glyph-id.  The element is an object which consists
of metric information and image data.

=over 4

=item bitmap object

=over 8
=item format
Only 7 is supported.
=item height
=item width
=item horiBearingX
=item horiBearingY
=item horiAdvance
=item vertBearingX
=item vertBearingY
=item vertAdvance
=item imageData

=back

=back

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);
require Font::TTF::Table;

@ISA = qw(Font::TTF::Table);


=head2 $t->read

Reads the embedded bitmap data from the TTF file into memory.
This routine should be called _after_ {'EBLC'}->read.

=cut

sub read
{
    my ($self) = shift;
    my ($fh) = $self->{' INFILE'};
    my ($i, $dat);
    my ($eblc) = $self->{' PARENT'}->{'EBLC'};
    my ($bst_array);

    $eblc->read;
    $self->SUPER::read || return $self;

    # ebdtHeader
    $fh->read($dat, 4);	# version

    $bst_array = $eblc->{'bitmapSizeTable'};

    for ($i = 0; $i < $eblc->{'Num'}; $i++)
    {
        my ($bst) = $bst_array->[$i];
        my ($format) = $bst->{'imageFormat'};
        my ($offset) = $bst->{'imageDataOffset'};
        my ($j);
        my ($ist_array) = $eblc->{'indexSubTableArray'}[$i];
        my ($bitmap) = {};

        die "Only EBDT format 7 is implemented." unless  ($format == 7);

        $self->{'bitmap'}[$i] = $bitmap;

        for ($j = 0; $j < $bst->{'numberOfIndexSubTables'}; $j++) {
            my ($ista) = $ist_array->[$j];
            my ($offsetArray) = $eblc->{'indexSubTable'}[$i][$j];
            my ($p, $o0, $c);

#           if ($fh->tell != $self->{' OFFSET'} + $offset) {
#               $fh->seek($self->{' OFFSET'} + $offset, 0);
#           }

            $p = 0;
            $o0 = $offsetArray->[$p++];
            for ($c = $ista->{'firstGlyphIndex'}; $c <= $ista->{'lastGlyphIndex'}; $c++)
            {
                my ($b) = {};
                my ($o1) = $offsetArray->[$p++];
                my ($len) = $o1 - $o0 - 8;

#               if ($fh->tell != $self->{' OFFSET'} + $offset + $o0) {
#                   $fh->seek($self->{' OFFSET'} + $offset + $o0, 0);
#               }

                $fh->read($dat, 8);
                ($b->{'height'},
                 $b->{'width'},
                 $b->{'horiBearingX'},
                 $b->{'horiBearingY'},
                 $b->{'horiAdvance'},
                 $b->{'vertBearingX'},
                 $b->{'vertBearingY'},
                 $b->{'vertAdvance'})
                    = unpack("cccccccc", $dat);

                $fh->read($dat, $len);
                $b->{'imageData'} = $dat;
                $b->{'format'} = 7; # bitmap and bigMetrics

                $bitmap->{$c} = $b;
                $o0 = $o1;
            }

            $offset += $o0;
        }
    }

    $self;
}


=head2 $t->update

Update EBLC information using EBDT data.

=cut

sub get_regions
{
    my (@l) = @_;
    my (@r) = ();
    my ($e);
    my ($first);
    my ($last);

    $first = $l[0];
    $last = $first - 1;
    foreach $e (@l) {
        if ($last + 1 != $e) {	# not contiguous
            $r[++$#r] = [$first, $last];
            $first = $e;
        }

        $last = $e;
    }

    $r[++$#r] = [$first, $last];
    @r;
}

sub update
{
    my ($self) = @_;
    my ($eblc) = $self->{' PARENT'}->{'EBLC'};
    my ($bst_array) = [];
    my ($offset) = 4;
    my ($i);
    my ($bitmap_array) = $self->{'bitmap'};
    my ($istao) = 8 + 48 * $eblc->{'Num'};

    $eblc->{'bitmapSizeTable'} = $bst_array;

    for ($i = 0; $i < $eblc->{'Num'}; $i++) {
        my ($bst) = {};
        my ($ist_array) = [];
        my ($j);
        my ($bitmap) = $bitmap_array->[$i];
        my (@regions) = get_regions(sort {$a <=> $b} keys (%$bitmap));
        my ($aotis) = 8 * (1+$#regions);

        $bst->{'indexFormat'} = 1;
        $bst->{'imageFormat'} = 7;
        $bst->{'imageDataOffset'} = $offset;
        $bst->{'numberOfIndexSubTables'} = 1+$#regions;
        $bst->{'indexSubTableArrayOffset'} = $istao;
        $bst->{'colorRef'} = 0;

        $bst->{'startGlyphIndex'} = $regions[0][0];
        $bst->{'endGlyphIndex'} = $regions[-1][1];
        $bst->{'bitDepth'} = 1;
        $bst->{'flags'} = 1;	# Horizontal
        $bst_array->[$i] = $bst;

        $eblc->{'indexSubTableArray'}[$i] = $ist_array;
        for ($j = 0; $j <= $#regions; $j++) {
            my ($ista) = {};
            my ($offsetArray) = [];
            my ($p, $o0, $c);
            $ist_array->[$j] = $ista;

            $ista->{'firstGlyphIndex'} = $regions[$j][0];
            $ista->{'lastGlyphIndex'} = $regions[$j][1];
            $ista->{'additionalOffsetToIndexSubtable'} = $aotis;
            $eblc->{'indexSubTable'}[$i][$j] = $offsetArray;
            $p = 0;
            $o0 = 0;
            for ($c = $regions[$j][0]; $c <= $regions[$j][1]; $c++) {
                my ($b) = $bitmap->{$c};

                $offsetArray->[$p++] = $o0;
                $o0 += 8 + length($b->{'imageData'});
            }

            $offsetArray->[$p++] = $o0;

            $aotis += ($regions[$j][1] - $regions[$j][0] + 1 + 1)*4;
            $offset += $o0;

            # Do we need the element of 0x10007 and absolute offset here,
            # at the end of offsetArray?
#               if ($j + 1 <= $#regions) {
#       	$offsetArray->[$p++] = 0x10007;
#       	$offsetArray->[$p++] = $offset;
#       	$aotis += 8;
#           }
        }

        $istao += $aotis + 8;
        $bst->{'indexTablesSize'} = $aotis + 8;
    }
}

=head2 $t->out($fh)

Outputs the bitmap data of embedded bitmap for this font.

=cut

sub out
{
    my ($self, $fh) = @_;
    my ($eblc) = $self->{' PARENT'}->{'EBLC'};
    my ($i);
    my ($bitmap_array) = $self->{'bitmap'};

    $fh->print(pack("N", 0x00020000));

    for ($i = 0; $i < $eblc->{'Num'}; $i++) {
        my ($j);
        my ($bitmap) = $bitmap_array->[$i];
        my (@regions) = get_regions(sort {$a <=> $b} keys (%$bitmap));

        for ($j = 0; $j <= $#regions; $j++) {
            my ($c);

            for ($c = $regions[$j][0]; $c <= $regions[$j][1]; $c++) {
                my ($b) = $bitmap->{$c};

                $fh->print(pack("cccccccc",
                                $b->{'height'}, $b->{'width'},
                                $b->{'horiBearingX'}, $b->{'horiBearingY'},
                                $b->{'horiAdvance'}, $b->{'vertBearingX'},
                                $b->{'vertBearingY'}, $b->{'vertAdvance'}));
                $fh->print($b->{'imageData'});
            }
        }
    }
}

1;

=head1 BUGS

Only Format 7 is implemented.  XML output is not supported (yet).

=head1 AUTHOR

NIIBE Yutaka L<gniibe@fsij.org>.  See L<Font::TTF::Font> for copyright and
licensing.

This was written at the CodeFest Akihabara 2006 hosted by FSIJ.

=cut

