package Font::TTF::GSUB;

=head1 NAME

Font::TTF::GSUB - Module support for the GSUB table in conjunction with TTOpen

=head1 DESCRIPTION

Handles the GSUB subtables in relation to Ttopen tables. Due to the variety of
different lookup types, the data structures are not all that straightforward,
although I have tried to make life easy for myself when using this!

=head1 INSTANCE VARIABLES

The structure of a GSUB table is the same as that given in L<Font::TTF::Ttopen>.
Here we give some of the semantics specific to GSUB lookups.

=over 4

=item ACTION_TYPE

This is a string taking one of 4 values indicating the nature of the information
in the ACTION array of the rule:

=over 8

=item g

The action contains a string of glyphs to replace the match string by

=item l

The action array contains a list of lookups and offsets to run, in order, on
the matched string

=item a

The action array is an unordered set of optional replacements for the matched
glyph. The application should make the selection somehow.

=item o

The action array is empty (in fact there is no rule array for this type of
rule) and the ADJUST value should be added to the glyph id to find the replacement
glyph id value

=back

=item MATCH_TYPE

This indicates which type of information the various MATCH arrays (MATCH, PRE,
POST) hold in the rule:

=over 8

=item g

The array holds a string of glyph ids which should match exactly

=item c

The array holds a sequence of class definitions which each glyph should
correspondingly match to

=item o

The array holds offsets to coverage tables

=back

=back

=head1 CORRESPONDANCE TO LAYOUT TYPES

The following table gives the values for ACTION_TYPE and MATCH_TYPE for each
of the 11 different lookup types found in the GSUB table definition I have:

                1.1 1.2 2   3   4   5.1 5.2 5.3 6.1 6.2 6.3
  ACTION_TYPE    o   g  g   a   g    l   l   l   l   l   l
  MATCH_TYPE                    g    g   c   o   g   c   o

Hopefully, the rest of the uses of the variables should make sense from this
table.

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);
use Font::TTF::Utils;
use Font::TTF::Ttopen;

@ISA = qw(Font::TTF::Ttopen);

=head2 $t->read_sub($fh, $lookup, $index)

Asked by the superclass to read in from the given file the indexth subtable from
lookup number lookup. The file is positioned ready for the read.

=cut

sub read_sub
{
    my ($self, $fh, $main_lookup, $sindex) = @_;
    my ($type) = $main_lookup->{'TYPE'};
    my ($loc) = $fh->tell();
    my ($lookup) = $main_lookup->{'SUB'}[$sindex];
    my ($dat, $s, @subst, $t, $fmt, $cover, $count, $mcount, $scount, $i, $gid);
    my (@srec);

    if ($type == 6)
    {
        $fh->read($dat, 4);
        ($fmt, $cover) = TTF_Unpack('S2', $dat);
        if ($fmt < 3)
        {
            $fh->read($dat, 2);
            $count = TTF_Unpack('S', $dat);
        }
    } else
    {
        $fh->read($dat, 6);
        ($fmt, $cover, $count) = TTF_Unpack("S3", $dat);
    }
    unless ($fmt == 3 && ($type == 5 || $type == 6))
    { $lookup->{'COVERAGE'} = $self->read_cover($cover, $loc, $lookup, $fh, 1); }

    $lookup->{'FORMAT'} = $fmt;
    if ($type == 1 && $fmt == 1)
    {
        $count -= 65536 if ($count > 32767);
        $lookup->{'ADJUST'} = $count;
        $lookup->{'ACTION_TYPE'} = 'o';
    } elsif ($type == 1 && $fmt == 2)
    {
        $fh->read($dat, $count << 1);
        @subst = TTF_Unpack('S*', $dat);
        foreach $s (@subst)
        { push(@{$lookup->{'RULES'}}, [{'ACTION' => [$s]}]); }
        $lookup->{'ACTION_TYPE'} = 'g';
    } elsif ($type == 2 || $type == 3)
    {
        $fh->read($dat, $count << 1);       # number of offsets
        foreach $s (TTF_Unpack('S*', $dat))
        {
            $fh->seek($loc + $s, 0);
            $fh->read($dat, 2);
            $t = TTF_Unpack('S', $dat);
            $fh->read($dat, $t << 1);
            push(@{$lookup->{'RULES'}}, [{'ACTION' => [TTF_Unpack('S*', $dat)]}]);
        }
        $lookup->{'ACTION_TYPE'} = ($type == 2 ? 'g' : 'a');
    } elsif ($type == 4)
    {
        $fh->read($dat, $count << 1);
        foreach $s (TTF_Unpack('S*', $dat))
        {
            @subst = ();
            $fh->seek($loc + $s, 0);
            $fh->read($dat, 2);
            $t = TTF_Unpack('S', $dat);
            $fh->read($dat, $t << 1);
            foreach $t (TTF_Unpack('S*', $dat))
            {
                $fh->seek($loc + $s + $t, 0);
                $fh->read($dat, 4);
                ($gid, $mcount) = TTF_Unpack('S2', $dat);
                $fh->read($dat, ($mcount - 1) << 1);
                push(@subst, {'ACTION' => [$gid], 'MATCH' => [TTF_Unpack('S*', $dat)]});
            }
            push(@{$lookup->{'RULES'}}, [@subst]);
        }
        $lookup->{'ACTION_TYPE'} = 'g';
        $lookup->{'MATCH_TYPE'} = 'g';
    } elsif ($type == 5 || $type == 6)
    { $self->read_context($lookup, $fh, $type, $fmt, $cover, $count, $loc); }
    $lookup;
}


=head2 $t->extension

Returns the table type number for the extension table

=cut

sub extension
{ return 7; }


=head2 $t->out_sub($fh, $lookup, $index)

Passed the filehandle to output to, suitably positioned, the lookup and subtable
index, this function outputs the subtable to $fh at that point.

=cut

sub out_sub
{
    my ($self, $fh, $main_lookup, $index, $ctables, $base) = @_;
    my ($type) = $main_lookup->{'TYPE'};
    my ($lookup) = $main_lookup->{'SUB'}[$index];
    my ($fmt) = $lookup->{'FORMAT'};
    my ($out, $r, $t, $i, $j, $offc, $offd, $numd);
    my ($num) = $#{$lookup->{'RULES'}} + 1;

    if ($type == 1)
    {
        $out = pack("nn", $fmt, Font::TTF::Ttopen::ref_cache($lookup->{'COVERAGE'}, $ctables, 2 + $base));
        if ($fmt == 1)
        { $out .= pack("n", $lookup->{'ADJUST'}); }
        else
        {
            $out .= pack("n", $num);
            foreach $r (@{$lookup->{'RULES'}})
            { $out .= pack("n", $r->[0]{'ACTION'}[0]); }
        }
    } elsif ($type == 2 || $type == 3)
    {
        $out = pack("nnn", $fmt, Font::TTF::Ttopen::ref_cache($lookup->{'COVERAGE'}, $ctables, 2 + $base),
                            $num);
        $out .= pack('n*', (0) x $num);
        $offc = length($out);
        for ($i = 0; $i < $num; $i++)
        {
            $out .= pack("n*", $#{$lookup->{'RULES'}[$i][0]{'ACTION'}} + 1,
                                    @{$lookup->{'RULES'}[$i][0]{'ACTION'}});
            substr($out, ($i << 1) + 6, 2) = pack('n', $offc);
            $offc = length($out);
        }
    } elsif ($type == 4 || $type == 5 || $type == 6)
    { $out = $self->out_context($lookup, $fh, $type, $fmt, $ctables, $out, $num, $base); }
#    Font::TTF::Ttopen::out_final($fh, $out, [[$ctables, 0]]);
    $out;
}

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

1;

