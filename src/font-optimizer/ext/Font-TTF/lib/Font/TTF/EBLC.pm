package Font::TTF::EBLC;

=head1 NAME

Font::TTF::EBLC - Embeeded Bitmap Location Table

=head1 DESCRIPTION

Contains the sizes and glyph ranges of bitmaps, and the offsets to
glyph bitmap data in indexSubTables for EBDT.

Possibly contains glyph metrics information.

=head1 INSTANCE VARIABLES
The information specified 'B<(R)>ead only' is read only, those
are calculated from EBDT, when it is 'update'-ed.

=over 4

=item bitmapSizeTable
An array of tables of following information

=over 8
=item indexSubTableArrayOffset (R)
=item indexTablesSize (R)
=item numberOfIndexSubTables (R)
=item colorRef
=item hori
=item vert
=item startGlyphIndex (R)
=item endGlyphIndex (R)
=item ppemX
=item ppemY
=item bitDepth
=item flags
=back

=item indexSubTableArray (R)
An array which contains range information.

=item indexSubTable (R)
An array which contains offsets of EBDT table.

=back

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);
require Font::TTF::Table;

@ISA = qw(Font::TTF::Table);


=head2 $t->read

Reads the location information of embedded bitmap from the TTF file into memory

=cut

sub read
{
    my ($self) = @_;
    my ($fh) = $self->{' INFILE'};
    my ($i, $dat);
    my ($indexSubTableArrayOffset,
        $indexTablesSize,
        $numberOfIndexSubTables,
        $colorRef);
    my ($startGlyphIndex,
        $endGlyphIndex,
        $ppemX, $ppemY,
        $bitDepth, $flags);
    my (@hori, @vert);
    my ($bst, $ista, $ist);
    my ($j);

    $self->SUPER::read or return $self;

    # eblcHeader
    $fh->read($dat, 4);
    $self->{'version'} = unpack("N",$dat);

    $fh->read($dat, 4);
    $self->{'Num'} = unpack("N",$dat);

    # bitmapSizeTable
    for ($i = 0; $i < $self->{'Num'}; $i++) {
        $fh->read($dat, 16);
        ($indexSubTableArrayOffset, $indexTablesSize,
         $numberOfIndexSubTables, $colorRef) = unpack("NNNN", $dat);
        $fh->read($dat, 12); @hori = unpack("cccccccccccc", $dat);
        $fh->read($dat, 12); @vert = unpack("cccccccccccc", $dat);

        $fh->read($dat, 8);
        ($startGlyphIndex, $endGlyphIndex,
         $ppemX, $ppemY, $bitDepth, $flags) = unpack("nnCCCC", $dat);

        $self->{'bitmapSizeTable'}[$i] = {
            'indexSubTableArrayOffset' => $indexSubTableArrayOffset,
            'indexTablesSize' => $indexTablesSize,
            'numberOfIndexSubTables' => $numberOfIndexSubTables,
            'colorRef' => $colorRef,
            'hori' => [@hori],
            'vert' => [@vert],
            'startGlyphIndex' => $startGlyphIndex,
            'endGlyphIndex' => $endGlyphIndex,
            'ppemX' => $ppemX,
            'ppemY' => $ppemY,
            'bitDepth' => $bitDepth,
            'flags' => $flags
            };
    }

    for ($i = 0; $i < $self->{'Num'}; $i++) {
        my ($count, $x);

        $bst = $self->{'bitmapSizeTable'}[$i];

        for ($j = 0; $j < $bst->{'numberOfIndexSubTables'}; $j++) {
            $ista = {};

            # indexSubTableArray
            $self->{'indexSubTableArray'}[$i][$j] = $ista;
            $fh->read($dat, 8);
            ($ista->{'firstGlyphIndex'},
             $ista->{'lastGlyphIndex'},
             $ista->{'additionalOffsetToIndexSubtable'})
                = unpack("nnN", $dat);
        }

        # indexSubTable
        # indexSubHeader
        $fh->read($dat, 8);
        ($bst->{'indexFormat'}, 
         $bst->{'imageFormat'}, 
         $bst->{'imageDataOffset'}) = unpack("nnN", $dat);

        die "Only indexFormat == 1 is supported" unless ($bst->{'indexFormat'} == 1);

        for ($j = 0; $j < $bst->{'numberOfIndexSubTables'}; $j++) {
            $ista = $self->{'indexSubTableArray'}[$i][$j];
            $count = $ista->{'lastGlyphIndex'} - $ista->{'firstGlyphIndex'} + 1 + 1;
            $fh->seek($self->{' OFFSET'} + $bst->{'indexSubTableArrayOffset'}
                      + $ista->{'additionalOffsetToIndexSubtable'} + 8, 0);

#           $count += 2 if $j < $bst->{'numberOfIndexSubTables'} - 1;

            $fh->read($dat, 4*$count);

            $self->{'indexSubTable'}[$i][$j] = [unpack("N*", $dat)];
        }
    }

    $self;
}

=head2 $t->out($fh)

Outputs the location information of embedded bitmap for this font.

=cut

sub out
{
    my ($self, $fh) = @_;
    my ($i);
    my ($bst_array) = $self->{'bitmapSizeTable'};

    $fh->print(pack("N", 0x00020000));
    $fh->print(pack("N", $self->{'Num'}));

    for ($i = 0; $i < $self->{'Num'}; $i++) {
        my ($bst) = $bst_array->[$i];

        $fh->print(pack("NNNN", 
                        $bst->{'indexSubTableArrayOffset'},
                        $bst->{'indexTablesSize'},
                        $bst->{'numberOfIndexSubTables'},
                        $bst->{'colorRef'}));
        $fh->print(pack("cccccccccccc", @{$bst->{'hori'}}));
        $fh->print(pack("cccccccccccc", @{$bst->{'vert'}}));
        $fh->print(pack("nnCCCC", $bst->{'startGlyphIndex'}, 
                        $bst->{'endGlyphIndex'}, $bst->{'ppemX'},
                        $bst->{'ppemY'}, $bst->{'bitDepth'}, $bst->{'flags'}));
    }

    for ($i = 0; $i < $self->{'Num'}; $i++) {
        my ($bst) = $bst_array->[$i];
        my ($j);

        for ($j = 0; $j < $bst->{'numberOfIndexSubTables'}; $j++) {
            my ($ista) = $self->{'indexSubTableArray'}[$i][$j];

            $fh->print("nnN",
                       $ista->{'firstGlyphIndex'},
                       $ista->{'lastGlyphIndex'},
                       $ista->{'additionalOffsetToIndexSubtable'});
        }

        $fh->print(pack("nnN", $bst->{'indexFormat'}, $bst->{'imageFormat'}, 
                        $bst->{'imageDataOffset'}));

        die "Only indexFormat == 1 is supported" unless ($bst->{'indexFormat'} == 1);

        for ($j = 0; $j < $bst->{'numberOfIndexSubTables'}; $j++) {
            $fh->print(pack("N*", $self->{'indexSubTable'}[$i][$j]));
        }
    }
}

1;

=head1 BUGS

Only indexFormat ==1 is implemented.  XML output is not supported (yet).

=head1 AUTHOR

NIIBE Yutaka L<gniibe@fsij.org>.  See L<Font::TTF::Font> for copyright and
licensing.

This was written at the CodeFest Akihabara 2006 hosted by FSIJ.

=cut

