package Font::TTF::GPOS;

=head1 NAME

Font::TTF::GPOS - Support for Opentype GPOS tables in conjunction with TTOpen

=head1 DESCRIPTION

The GPOS table is one of the most complicated tables in the TTF spec and the
corresponding data structure abstraction is also not trivial. While much of the
structure of a GPOS is shared with a GSUB table via the L<Font::TTF::Ttopen>

=head1 INSTANCE VARIABLES

Here we describe the additions and lookup specific information for GPOS tables.
Unfortunately there is no one abstraction which seems to work comfortable for
all GPOS tables, so we will also examine how the variables are used for different
lookup types.

The following are the values allowed in the ACTION_TYPE and MATCH_TYPE variables:

=over 4

=item ACTION_TYPE

This can take any of the following values

=over 8

=item a

The ACTION is an array of anchor tables

=item o

Offset. There is no RULE array. The ADJUST variable contains a value record (see
later in this description)

=item v

The ACTION is a value record.

=item p

Pair adjustment. The ACTION contains an array of two value records for the matched
two glyphs.

=item e

Exit and Entry records. The ACTION contains an array of two anchors corresponding
to the exit and entry anchors for the glyph.

=item l

Indicates a lookup based contextual rule as per the GSUB table.

=back

=item MATCH_TYPE

This can take any of the following values

=over 8

=item g

A glyph array

=item c

An array of class values

=item o

An array of coverage tables

=back

=back

The following variables are added for Attachment Positioning Subtables:

=over 4

=item MATCH

This contains an array of glyphs to match against for all RULES. It is much like
having the same MATCH string in all RULES. In the cases it is used so far, it only
ever contains one element.

=item MARKS

This contains a Mark array consisting of each element being a subarray of two
elements:

=over 8

=item CLASS

The class that this mark uses on its base

=item ANCHOR

The anchor with which to attach this mark glyph

=back

The base table for mark to base, ligature or mark attachment positioning is
structured with the ACTION containing an array of anchors corresponding to each
attachment class. For ligatures, there is more than one RULE in the RULE array
corresponding to each glyph in the coverage table.

=back

Other variables which are provided for informational purposes are:

=over 4

=item VFMT

Value format for the adjustment of the glyph matched by the coverage table.

=item VFMT2

Value format used in pair adjustment for the second glyph in the pair

=back

=head2 Value Records

There is a subtype used in GPOS tables called a value record. It is used to adjust
the position of a glyph from its default position. The value record is variable
length with a bitfield at the beginning to indicate which of the following
entries are included. The bitfield is not stored since it is recalculated at
write time.

=over 4

=item XPlacement

Horizontal adjustment for placement (not affecting other unattached glyphs)

=item YPlacement

Vertical adjustment for placement (not affecting other unattached glyphs)

=item XAdvance

Adjust the advance width glyph (used only in horizontal writing systems)

=item YAdvance

Adjust the vertical advance (used only in vertical writing systems)

=item XPlaDevice

Device table for device specific adjustment of horizontal placement

=item YPlaDevice

Device table for device specific adjustment of vertical placement

=item XAdvDevice

Device table for device specific adjustment of horizontal advance

=item YAdDevice

Device table for device specific adjustment of vertical advance

=item XIdPlacement

Horizontal placement metric id (for Multiple Master fonts - but that's all I know!)

=item YIdPlacement

Vertical placement metric id

=item XIdAdvance

Horizontal advance metric id

=item YIdAdvance

Vertical advance metric id

=back

=head1 CORRESPONDANCE TO LAYOUT TYPES

Here is what is stored in the ACTION_TYPE and MATCH_TYPE for each of the known
GPOS subtable types:

                1.1 1.2 2.1 2.2 3   4   5   6   7.1 7.2 7.3 8.1 8.2 8.3
  ACTION_TYPE    o   v   p   p  e   a   a   a    l   l   l   l   l   l
  MATCH_TYPE             g   c                   g   c   o   g   c   o


=head1 METHODS

=cut

use strict;
use Font::TTF::Ttopen;
use Font::TTF::Delta;
use Font::TTF::Anchor;
use Font::TTF::Utils;
use vars qw(@ISA);

@ISA = qw(Font::TTF::Ttopen);


=head2 read_sub

Reads the subtable into the data structures

=cut

sub read_sub
{
    my ($self, $fh, $main_lookup, $sindex) = @_;
    my ($type) = $main_lookup->{'TYPE'};
    my ($loc) = $fh->tell();
    my ($lookup) = $main_lookup->{'SUB'}[$sindex];
    my ($dat, $mcount, $scount, $i, $j, $count, $fmt, $fmt2, $cover, $srec, $subst);
    my ($c1, $c2, $s, $moff, $boff);


    if ($type == 8)
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
    unless ($fmt == 3 && ($type == 7 || $type == 8))
    { $lookup->{'COVERAGE'} = $self->read_cover($cover, $loc, $lookup, $fh, 1); }

    $lookup->{'FORMAT'} = $fmt;
    if ($type == 1 && $fmt == 1)
    {
        $lookup->{'VFMT'} = $count;
        $lookup->{'ADJUST'} = $self->read_value($count, $loc, $lookup, $fh);
        $lookup->{'ACTION_TYPE'} = 'o';
    } elsif ($type == 1 && $fmt == 2)
    {
        $lookup->{'VFMT'} = $count;
        $fh->read($dat, 2);
        $mcount = unpack('n', $dat);
        for ($i = 0; $i < $mcount; $i++)
        { push (@{$lookup->{'RULES'}}, [{'ACTION' =>
                                    [$self->read_value($count, $loc, $lookup, $fh)]}]); }
        $lookup->{'ACTION_TYPE'} = 'v';
    } elsif ($type == 2 && $fmt == 1)
    {
        $lookup->{'VFMT'} = $count;
        $fh->read($dat, 4);
        ($fmt2, $mcount) = unpack('n2', $dat);
        $lookup->{'VFMT2'} = $fmt2;
        $fh->read($dat, $mcount << 1);
        foreach $s (unpack('n*', $dat))
        {
            $fh->seek($loc + $s, 0);
            $fh->read($dat, 2);
            $scount = TTF_Unpack('S', $dat);
            $subst = [];
            for ($i = 0; $i < $scount; $i++)
            {
                $srec = {};
                $fh->read($dat, 2);
                $srec->{'MATCH'} = [TTF_Unpack('S', $dat)];
                $srec->{'ACTION'} = [$self->read_value($count, $loc, $lookup, $fh),
                                     $self->read_value($fmt2, $loc, $lookup, $fh)];
                push (@$subst, $srec);
            }
            push (@{$lookup->{'RULES'}}, $subst);
        }
        $lookup->{'ACTION_TYPE'} = 'p';
        $lookup->{'MATCH_TYPE'} = 'g';
    } elsif ($type == 2 && $fmt == 2)
    {
        $fh->read($dat, 10);
        ($lookup->{'VFMT2'}, $c1, $c2, $mcount, $scount) = TTF_Unpack('S*', $dat);
        $lookup->{'CLASS'} = $self->read_cover($c1, $loc, $lookup, $fh, 0);
        $lookup->{'MATCH'} = [$self->read_cover($c2, $loc, $lookup, $fh, 0)];
        $lookup->{'VFMT'} = $count;
        for ($i = 0; $i < $mcount; $i++)
        {
            $subst = [];
            for ($j = 0; $j < $scount; $j++)
            {
                $srec = {};
                $srec->{'ACTION'} = [$self->read_value($lookup->{'VFMT'}, $loc, $lookup, $fh),
                                     $self->read_value($lookup->{'VFMT2'}, $loc, $lookup, $fh)];
                push (@$subst, $srec);
            }
            push (@{$lookup->{'RULES'}}, $subst);
        }
        $lookup->{'ACTION_TYPE'} = 'p';
        $lookup->{'MATCH_TYPE'} = 'c';
    } elsif ($type == 3 && $fmt == 1)
    {
        $fh->read($dat, $count << 2);
        for ($i = 0; $i < $count; $i++)
        { push (@{$lookup->{'RULES'}}, [{'ACTION' =>
                [$self->read_anchor(TTF_Unpack('S', substr($dat, $i << 2, 2)),
                        $loc, $lookup, $fh),
                 $self->read_anchor(TTF_Unpack('S', substr($dat, ($i << 2) + 2, 2)),
                        $loc, $lookup, $fh)]}]); }
        $lookup->{'ACTION_TYPE'} = 'e';
    } elsif ($type == 4 || $type == 5 || $type == 6)
    {
        my (@offs, $mloc, $thisloc, $ncomp, $k);

        $lookup->{'MATCH'} = [$lookup->{'COVERAGE'}];
        $lookup->{'COVERAGE'} = $self->read_cover($count, $loc, $lookup, $fh, 1);
        $fh->read($dat, 6);
        ($mcount, $moff, $boff) = TTF_Unpack('S*', $dat);
        $fh->seek($loc + $moff, 0);
        $fh->read($dat, 2);
        $count = TTF_Unpack('S', $dat);
        for ($i = 0; $i < $count; $i++)
        {
            $fh->read($dat, 4);
            push (@{$lookup->{'MARKS'}}, [TTF_Unpack('S', $dat),
                    $self->read_anchor(TTF_Unpack('S', substr($dat, 2, 2)) + $moff,
                            $loc, $lookup, $fh)]);
        }
        $fh->seek($loc + $boff, 0);
        $fh->read($dat, 2);
        $count = TTF_Unpack('S', $dat);
        $mloc = $fh->tell() - 2;
        $thisloc = $mloc;
        if ($type == 5)
        {
            $fh->read($dat, $count << 1);
            @offs = TTF_Unpack('S*', $dat);
        }
        for ($i = 0; $i < $count; $i++)
        {
            if ($type == 5)
            {
                $thisloc = $mloc + $offs[$i];
                $fh->seek($thisloc, 0);
                $fh->read($dat, 2);
                $ncomp = TTF_Unpack('S', $dat);
            } else
            { $ncomp = 1; }
            for ($j = 0; $j < $ncomp; $j++)
            {
                $subst = [];
                $fh->read($dat, $mcount << 1);
                for ($k = 0; $k < $mcount; $k++)
                { push (@$subst, $self->read_anchor(TTF_Unpack('S', substr($dat, $k << 1, 2)) + $thisloc - $loc,
                        $loc, $lookup, $fh)); }

                push (@{$lookup->{'RULES'}[$i]}, {'ACTION' => $subst});
            }
        }
        $lookup->{'ACTION_TYPE'} = 'a';
    } elsif ($type == 7 || $type == 8)
    { $self->read_context($lookup, $fh, $type - 2, $fmt, $cover, $count, $loc); }        
    $lookup;
}


=head2 $t->extension

Returns the table type number for the extension table

=cut

sub extension
{ return 9; }


=head2 $t->out_sub

Outputs the subtable to the given filehandle

=cut

sub out_sub
{
    my ($self, $fh, $main_lookup, $index, $ctables, $base) = @_;
    my ($type) = $main_lookup->{'TYPE'};
    my ($lookup) = $main_lookup->{'SUB'}[$index];
    my ($fmt) = $lookup->{'FORMAT'};
    my ($out, $r, $s, $t, $i, $j, $vfmt, $vfmt2, $loc1);
    my ($num) = $#{$lookup->{'RULES'}} + 1;
    my ($mtables) = {};
    my (@reftables);
    
    if ($type == 1 && $fmt == 1)
    {
        $out = pack('n2', $fmt, Font::TTF::Ttopen::ref_cache($lookup->{'COVERAGE'}, $ctables, 2 + $base));
        $vfmt = $self->fmt_value($lookup->{'ADJUST'});
        $out .= pack('n', $vfmt) . $self->out_value($lookup->{'ADJUST'}, $vfmt, $ctables, 6 + $base);
    } elsif ($type == 1 && $fmt == 2)
    {
        $vfmt = 0;
        foreach $r (@{$lookup->{'RULES'}})
        { $vfmt |= $self->fmt_value($r->[0]{'ACTION'}[0]); }
        $out = pack('n4', $fmt, Font::TTF::Ttopen::ref_cache($lookup->{'COVERAGE'}, $ctables, 2 + $base),
                            $vfmt, $#{$lookup->{'RULES'}} + 1);
        foreach $r (@{$lookup->{'RULES'}})
        { $out .= $self->out_value($r->[0]{'ACTION'}[0], $vfmt, $ctables, length($out) + $base); }
    } elsif ($type == 2 && $fmt < 3)
    {
        $vfmt = 0;
        $vfmt2 = 0;
        foreach $r (@{$lookup->{'RULES'}})
        {
            foreach $t (@$r)
            {
                $vfmt |= $self->fmt_value($t->{'ACTION'}[0]);
                $vfmt2 |= $self->fmt_value($t->{'ACTION'}[1]);
            }
        }
        if ($fmt == 1)
        {
            # start PairPosFormat1 subtable
            $out = pack('n5', 
                        $fmt, 
                        Font::TTF::Ttopen::ref_cache($lookup->{'COVERAGE'}, $ctables, 2 + $base),
                        $vfmt, 
                        $vfmt2, 
                        $#{$lookup->{'RULES'}} + 1); # PairSetCount
            my $off = 0;
            $off += length($out);
            $off += 2 * ($#{$lookup->{'RULES'}} + 1); # there will be PairSetCount offsets here
            my $pairsets = '';
            my (%cache);
            foreach $r (@{$lookup->{'RULES'}}) # foreach PairSet table
            {
                # write offset to this PairSet at end of PairPosFormat1 table
                if (defined $cache{"$r"})
                { $out .= pack('n', $cache{"$r"}); }
                else
                {
                    $out .= pack('n', $off);
                    $cache{"$r"} = $off;

                    # generate PairSet itself (using $off as eventual offset within PairPos subtable)
                    my $pairset = pack('n', $#{$r} + 1); # PairValueCount
                    foreach $t (@$r) # foreach PairValueRecord
                    {
                        $pairset .= pack('n', $t->{'MATCH'}[0]); # SecondGlyph - MATCH has only one entry
                        $pairset .= 
                            $self->out_value($t->{'ACTION'}[0], $vfmt,  $ctables, $off + length($pairset) + $base);
                        $pairset .= 
                            $self->out_value($t->{'ACTION'}[1], $vfmt2, $ctables, $off + length($pairset) + $base);
                    }
                    $off += length($pairset);
                    $pairsets .= $pairset;
                }
            }
            $out .= $pairsets;
            die "internal error: PairPos size not as calculated" if (length($out) != $off);
        } else
        {
            $out = pack('n8', $fmt, Font::TTF::Ttopen::ref_cache($lookup->{'COVERAGE'}, $ctables, 2 + $base),
                            $vfmt, $vfmt2,
                            Font::TTF::Ttopen::ref_cache($lookup->{'CLASS'}, $ctables, 8 + $base),
                            Font::TTF::Ttopen::ref_cache($lookup->{'MATCH'}[0], $ctables, 10 + $base),
                            $lookup->{'CLASS'}{'max'} + 1, $lookup->{'MATCH'}[0]{'max'} + 1);

            for ($i = 0; $i <= $lookup->{'CLASS'}{'max'}; $i++)
            {
                for ($j = 0; $j <= $lookup->{'MATCH'}[0]{'max'}; $j++)
                {
                    $out .= $self->out_value($lookup->{'RULES'}[$i][$j]{'ACTION'}[0], $vfmt, $ctables, length($out) + $base);
                    $out .= $self->out_value($lookup->{'RULES'}[$i][$j]{'ACTION'}[1], $vfmt2, $ctables, length($out) + $base);
                }
            }
        }
    } elsif ($type == 3 && $fmt == 1)
    {
        $out = pack('n3', $fmt, Font::TTF::Ttopen::ref_cache($lookup->{'COVERAGE'}, $ctables, 2 + $base),
                            $#{$lookup->{'RULES'}} + 1);
        foreach $r (@{$lookup->{'RULES'}})
        {
            $out .= pack('n2', Font::TTF::Ttopen::ref_cache($r->[0]{'ACTION'}[0], $ctables, length($out) + $base),
                            Font::TTF::Ttopen::ref_cache($r->[0]{'ACTION'}[1], $ctables, length($out) + 2 + $base));
        }
    } elsif ($type == 4 || $type == 5 || $type == 6)
    {
        my ($loc_off, $loc_t, $ltables);
        
        $out = pack('n7', $fmt, Font::TTF::Ttopen::ref_cache($lookup->{'MATCH'}[0], $ctables, 2 + $base),
                            Font::TTF::Ttopen::ref_cache($lookup->{'COVERAGE'}, $ctables, 4 + $base),
                            $#{$lookup->{'RULES'}[0][0]{'ACTION'}} + 1, 12, ($#{$lookup->{'MARKS'}} + 4) << 2,
                            $#{$lookup->{'MARKS'}} + 1);
        foreach $r (@{$lookup->{'MARKS'}})
        { $out .= pack('n2', $r->[0], Font::TTF::Ttopen::ref_cache($r->[1], $mtables, length($out) + 2)); }
        push (@reftables, [$mtables, 12]);

        $loc_t = length($out);
        substr($out, 10, 2) = pack('n', $loc_t);
        $out .= pack('n', $#{$lookup->{'RULES'}} + 1);
        if ($type == 5)
        {
            $loc1 = length($out);
            $out .= pack('n*', (0) x ($#{$lookup->{'RULES'}} + 1));
        }
        $ltables = {};
        for ($i = 0; $i <= $#{$lookup->{'RULES'}}; $i++)
        {
            if ($type == 5)
            {
                $ltables = {};
                $loc_t = length($out);
                substr($out, $loc1 + ($i << 1), 2) = TTF_Pack('S', $loc_t - $loc1 + 2);
            }

            $r = $lookup->{'RULES'}[$i];
            $out .= pack('n', $#{$r} + 1) if ($type == 5);
            foreach $t (@$r)
            {
                foreach $s (@{$t->{'ACTION'}})
                { $out .= pack('n', Font::TTF::Ttopen::ref_cache($s, $ltables, length($out))); }
            }
            push (@reftables, [$ltables, $loc_t]) if ($type == 5);
        }
        push (@reftables, [$ltables, $loc_t]) unless ($type == 5);
        $out = Font::TTF::Ttopen::out_final($fh, $out, \@reftables, 1);
    } elsif ($type == 7 || $type == 8)
    { $out = $self->out_context($lookup, $fh, $type - 2, $fmt, $ctables, $out, $num, $base); }
#    push (@reftables, [$ctables, 0]);
    $out;
}
            

=head2 $t->read_value($format, $base, $lookup, $fh)

Reads a value record from the current location in the file, according to the
format given.

=cut

sub read_value
{
    my ($self, $fmt, $base, $lookup, $fh) = @_;
    my ($flag) = 1;
    my ($res) = {};
    my ($s, $i, $dat);

    $s = 0;
    for ($i = 0; $i < 12; $i++)
    {
        $s++ if ($flag & $fmt);
        $flag <<= 1;
    }

    $fh->read($dat, $s << 1);
    $flag = 1; $i = 0;
    foreach $s (qw(XPlacement YPlacement XAdvance YAdvance))
    {
        $res->{$s} = TTF_Unpack('s', substr($dat, $i++ << 1, 2)) if ($fmt & $flag);
        $flag <<= 1;
    }

    foreach $s (qw(XPlaDevice YPlaDevice XAdvDevice YAdvDevice))
    {
        if ($fmt & $flag)
        { $res->{$s} = $self->read_delta(TTF_Unpack('S', substr($i++ << 1, 2)),
                            $base, $lookup, $fh); }
        $flag <<= 1;
    }

    foreach $s (qw(XIdPlacement YIdPlacement XIdAdvance YIdAdvance))
    {
        $res->{$s} = TTF_Unpack('S', substr($dat, $i++ << 1, 2)) if ($fmt & $flag);
        $flag <<= 1;
    }
    $res;
}


=head2 $t->read_delta($offset, $base, $lookup, $fh)

Reads a delta (device table) at the given offset if it hasn't already been read.
Store the offset and item in the lookup cache ($lookup->{' CACHE'})

=cut

sub read_delta
{
    my ($self, $offset, $base, $lookup, $fh) = @_;
    my ($loc) = $fh->tell();
    my ($res, $str);

    return undef unless $offset;
    $str = sprintf("%X", $base + $offset);
    return $lookup->{' CACHE'}{$str} if defined $lookup->{' CACHE'}{$str};
    $fh->seek($base + $offset, 0);
    $res = Font::TTF::Delta->new->read($fh);
    $fh->seek($loc, 0);
    $lookup->{' CACHE'}{$str} = $res;
    return $res;
}


=head2 $t->read_anchor($offset, $base, $lookup, $fh)

Reads an Anchor table at the given offset if it hasn't already been read.

=cut

sub read_anchor
{
    my ($self, $offset, $base, $lookup, $fh) = @_;
    my ($loc) = $fh->tell();
    my ($res, $str);

    return undef unless $offset;
    $str = sprintf("%X", $base + $offset);
    return $lookup->{' CACHE'}{$str} if defined $lookup->{' CACHE'}{$str};
    $fh->seek($base + $offset, 0);
    $res = Font::TTF::Anchor->new->read($fh);
    $fh->seek($loc, 0);
    $lookup->{' CACHE'}{$str} = $res;
    return $res;
}


=head2 $t->fmt_value

Returns the value format for a given value record

=cut

sub fmt_value
{
    my ($self, $value) = @_;
    my ($fmt) = 0;
    my ($n);

    foreach $n (reverse qw(XPlacement YPlacement XAdvance YAdvance XPlaDevice YPlaDevice
                  XAdvDevice YAdvDevice XIdPlacement YIdPlacement XIdAdvance
                  YIdAdvance))
    {
        $fmt <<= 1;
        $fmt |= 1 if (defined $value->{$n} && (ref $value->{$n} || $value->{$n}));
    }
    $fmt;
}


=head2 $t->out_value

Returns the output string for the outputting of the value for a given format. Also
updates the offset cache for any device tables referenced.

=cut

sub out_value
{
    my ($self, $value, $fmt, $tables, $offset) = @_;
    my ($n, $flag, $out);

    $flag = 1;
    foreach $n (qw(XPlacement YPlacement XAdvance YAdvance))
    {
        $out .= pack('n', $value->{$n}) if ($flag & $fmt);
        $flag <<= 1;
    }
    foreach $n (qw(XPlaDevice YPlaDevice XAdvDevice YAdvDevice))
    {
        if ($flag & $fmt)
        {
            $out .= pack('n', Font::TTF::Ttopen::ref_cache(
                        $value->{$n}, $tables, $offset + length($out)));
        }
        $flag <<= 1;
    }
    foreach $n (qw(XIdPlacement YIdPlacement XIdAdvance YIdAdvance))
    {
        $out .= pack('n', $value->{$n}) if ($flag & $fmt);
        $flag <<= 1;
    }
    $out;
}


=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

1;

