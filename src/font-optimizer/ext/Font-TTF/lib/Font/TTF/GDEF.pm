package Font::TTF::GDEF;

=head1 NAME

Font::TTF::GDEF - Opentype GDEF table support

=head1 DESCRIPTION

The GDEF table contains various global lists of information which are apparantly
used in other places in an OpenType renderer. But precisely where is open to
speculation...

=head1 INSTANCE VARIABLES

There are 4 tables in the GDEF table, each with their own structure:

=over 4

=item GLYPH

This is an L<Font::TTF::Coverage> Class Definition table containing information
as to what type each glyph is.

=item ATTACH

The attach table consists of a coverage table and then attachment points for
each glyph in the coverage table:

=over 8

=item COVERAGE

This is a coverage table

=item POINTS

This is an array of point elements. Each element is an array of curve points
corresponding to the attachment points on that glyph. The order of the curve points
in the array corresponds to the attachment point number specified in the MARKS
coverage table (see below).

=back

=item LIG

This contains the ligature caret positioning information for ligature glyphs

=over 8

=item COVERAGE

A coverage table to say which glyphs are ligatures

=item LIGS

An array of elements for each ligature. Each element is an array of information
for each caret position in the ligature (there being number of components - 1 of
these, generally)

=over 12

=item FMT

This is the format of the information and is important to provide the semantics
for the value. This value must be set correctly before output

=item VAL

The value which has meaning according to FMT

=item DEVICE

For FMT = 3, a device table is also referenced which is stored here

=back

=back

=item MARKS

Due to confusion in the GDEF specification, this field is currently withdrawn until
the confusion is resolved. That way, perhaps this stuff will work!

This class definition table stores the mark attachment point numbers for each
attachment mark, to indicate which attachment point the mark attaches to on its
base glyph.

=back


=head1 METHODS

=cut

use strict;
use Font::TTF::Table;
use Font::TTF::Utils;
use Font::TTF::Ttopen;
use vars qw(@ISA $new_gdef);

@ISA = qw(Font::TTF::Table);
$new_gdef = 1;

=head2 $t->read

Reads the table into the data structure

=cut

sub read
{
    my ($self) = @_;
    my ($fh) = $self->{' INFILE'};
    my ($boff) = $self->{' OFFSET'};
    my ($dat, $goff, $loff, $aoff, $moff, $r, $s, $bloc);

    $self->SUPER::read or return $self;
    $bloc = $fh->tell();
    if ($new_gdef)
    {
        $fh->read($dat, 12);
        ($self->{'Version'}, $goff, $aoff, $loff, $moff) = TTF_Unpack('fS4', $dat);
    }
    else
    {
        $fh->read($dat, 10);
        ($self->{'Version'}, $goff, $aoff, $loff) = TTF_Unpack('fS3', $dat);
    }

    if ($goff > 0)
    {
        $fh->seek($goff + $boff, 0);
        $self->{'GLYPH'} = Font::TTF::Coverage->new(0)->read($fh);
    }

    if ($new_gdef && $moff > 0 && $moff < $self->{' LENGTH'})
    {
        $fh->seek($moff + $boff, 0);
        $self->{'MARKS'} = Font::TTF::Coverage->new(0)->read($fh);
    }

    if ($aoff > 0)
    {
        my ($off, $gcount, $pcount);
        
        $fh->seek($aoff + $boff, 0);
        $fh->read($dat, 4);
        ($off, $gcount) = TTF_Unpack('SS', $dat);
        $fh->read($dat, $gcount << 1);

        $fh->seek($aoff + $boff +  $off, 0);
        $self->{'ATTACH'}{'COVERAGE'} = Font::TTF::Coverage->new(1)->read($fh);

        foreach $r (TTF_Unpack('S*', $dat))
        {
            unless ($r)
            {
                push (@{$self->{'ATTACH'}{'POINTS'}}, []);
                next;
            }
            $fh->seek($aoff + $boff + $r, 0);
            $fh->read($dat, 2);
            $pcount = TTF_Unpack('S', $dat);
            $fh->read($dat, $pcount << 1);
            push (@{$self->{'ATTACH'}{'POINTS'}}, [TTF_Unpack('S*', $dat)]);
        }
    }

    if ($loff > 0)
    {
        my ($lcount, $off, $ccount, $srec, $comp);

        $fh->seek($loff + $boff, 0);
        $fh->read($dat, 4);
        ($off, $lcount) = TTF_Unpack('SS', $dat);
        $fh->read($dat, $lcount << 1);

        $fh->seek($off + $loff + $boff, 0);
        $self->{'LIG'}{'COVERAGE'} = Font::TTF::Coverage->new(1)->read($fh);

        foreach $r (TTF_Unpack('S*', $dat))
        {
            $fh->seek($r + $loff + $boff, 0);
            $fh->read($dat, 2);
            $ccount = TTF_Unpack('S', $dat);
            $fh->read($dat, $ccount << 1);

            $srec = [];
            foreach $s (TTF_Unpack('S*', $dat))
            {
                $comp = {};
                $fh->seek($s + $r + $loff + $boff, 0);
                $fh->read($dat, 4);
                ($comp->{'FMT'}, $comp->{'VAL'}) = TTF_Unpack('S*', $dat);
                if ($comp->{'FMT'} == 3)
                {
                    $fh->read($dat, 2);
                    $off = TTF_Unpack('S', $dat);
                    if (defined $self->{' CACHE'}{$off + $s + $r})
                    { $comp->{'DEVICE'} = $self->{' CACHE'}{$off + $s + $r}; }
                    else
                    {
                        $fh->seek($off + $s + $r + $loff + $boff, 0);
                        $comp->{'DEVICE'} = Font::TTF::Delta->new->read($fh);
                        $self->{' CACHE'}{$off + $s + $r} = $comp->{'DEVICE'};
                    }
                }
                push (@$srec, $comp);
            }
            push (@{$self->{'LIG'}{'LIGS'}}, $srec);
        }
    }

    $self;
}


=head2 $t->out($fh)

Writes out this table.

=cut

sub out
{
    my ($self, $fh) = @_;
    my ($goff, $aoff, $loff, $moff, @offs, $loc1, $coff, $loc);

    return $self->SUPER::out($fh) unless $self->{' read'};

    $loc = $fh->tell();
    if ($new_gdef)
    { $fh->print(TTF_Pack('fSSSS', $self->{'Version'}, 0, 0, 0, 0)); }
    else
    { $fh->print(TTF_Pack('fSSS', $self->{'Version'}, 0, 0, 0)); }

    if (defined $self->{'GLYPH'})
    {
        $goff = $fh->tell() - $loc;
        $self->{'GLYPH'}->out($fh);
    }

    if (defined $self->{'ATTACH'})
    {
        my ($r);
        
        $aoff = $fh->tell() - $loc;
        $fh->print(pack('n*', (0) x ($#{$self->{'ATTACH'}{'POINTS'}} + 3)));
        foreach $r (@{$self->{'ATTACH'}{'POINTS'}})
        {
            push (@offs, $fh->tell() - $loc - $aoff);
            $fh->print(pack('n*', $#{$r} + 1, @$r));
        }
        $coff = $fh->tell() - $loc - $aoff;
        $self->{'ATTACH'}{'COVERAGE'}->out($fh);
        $loc1 = $fh->tell();
        $fh->seek($aoff + $loc, 0);
        $fh->print(pack('n*', $coff, $#offs + 1, @offs));
        $fh->seek($loc1, 0);
    }

    if (defined $self->{'LIG'})
    {
        my (@reftables, $ltables, $i, $j, $out, $r, $s);

        $ltables = {};
        $loff = $fh->tell() - $loc;
        $out = pack('n*',
                        Font::TTF::Ttopen::ref_cache($self->{'LIG'}{'COVERAGE'}, $ltables, 0),
                        $#{$self->{'LIG'}{'LIGS'}} + 1,
                        (0) x ($#{$self->{'LIG'}{'LIGS'}} + 1));
        push (@reftables, [$ltables, 0]);
        $i = 0;
        foreach $r (@{$self->{'LIG'}{'LIGS'}})
        {
            $ltables = {};
            $loc1 = length($out);
            substr($out, ($i << 1) + 4, 2) = TTF_Pack('S', $loc1);
            $out .= pack('n*', $#{$r} + 1, (0) x ($#{$r} + 1));
            @offs = (); $j = 0;
            foreach $s (@$r)
            {
                substr($out, ($j << 1) + 2 + $loc1, 2) =
                        TTF_Pack('S', length($out) - $loc1);
                $out .= TTF_Pack('SS', $s->{'FMT'}, $s->{'VAL'});
                $out .= pack('n', Font::TTF::Ttopen::ref_cache($s->{'DEVICE'},
                        $ltables, length($out))) if ($s->{'FMT'} == 3);
                $j++;
            }
            push (@reftables, [$ltables, $loc1]);
            $i++;
        }
        Font::TTF::Ttopen::out_final($fh, $out, \@reftables);
    }

    if ($new_gdef && defined $self->{'MARKS'})
    {
        $moff = $fh->tell() - $loc;
        $self->{'MARKS'}->out($fh);
    }

    $loc1 = $fh->tell();
    $fh->seek($loc + 4, 0);
    if ($new_gdef)
    { $fh->print(TTF_Pack('S4', $goff, $aoff, $loff, $moff)); }
    else
    { $fh->print(TTF_Pack('S3', $goff, $aoff, $loff)); }
    $fh->seek($loc1, 0);
    $self;
}

1;

