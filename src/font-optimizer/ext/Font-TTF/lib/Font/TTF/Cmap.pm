package Font::TTF::Cmap;

=head1 NAME

Font::TTF::Cmap - Character map table

=head1 DESCRIPTION

Looks after the character map. For ease of use, the actual cmap is held in
a hash against codepoint. Thus for a given table:

    $gid = $font->{'cmap'}{'Tables'}[0]{'val'}{$code};

Note that C<$code> should be a true value (0x1234) rather than a string representation.

=head1 INSTANCE VARIABLES

The instance variables listed here are not preceeded by a space due to their
emulating structural information in the font.

=over 4

=item Num

Number of subtables in this table

=item Tables

An array of subtables ([0..Num-1])

=back

Each subtables also has its own instance variables which are, again, not
preceeded by a space.

=over 4

=item Platform

The platform number for this subtable

=item Encoding

The encoding number for this subtable

=item Format

Gives the stored format of this subtable

=item Ver

Gives the version (or language) information for this subtable

=item val

A hash keyed by the codepoint value (not a string) storing the glyph id

=back

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);
use Font::TTF::Table;
use Font::TTF::Utils;

@ISA = qw(Font::TTF::Table);


=head2 $t->read

Reads the cmap into memory. Format 4 subtables read the whole subtable and
fill in the segmented array accordingly.

=cut

sub read
{
    my ($self) = @_;
    my ($dat, $i, $j, $k, $id, @ids, $s);
    my ($start, $end, $range, $delta, $form, $len, $num, $ver, $sg);
    my ($fh) = $self->{' INFILE'};

    $self->SUPER::read or return $self;
    $fh->read($dat, 4);
    $self->{'Num'} = unpack("x2n", $dat);
    $self->{'Tables'} = [];
    for ($i = 0; $i < $self->{'Num'}; $i++)
    {
        $s = {};
        $fh->read($dat, 8);
        ($s->{'Platform'}, $s->{'Encoding'}, $s->{'LOC'}) = (unpack("nnN", $dat));
        $s->{'LOC'} += $self->{' OFFSET'};
        push(@{$self->{'Tables'}}, $s);
    }
    for ($i = 0; $i < $self->{'Num'}; $i++)
    {
        $s = $self->{'Tables'}[$i];
        $fh->seek($s->{'LOC'}, 0);
        $fh->read($dat, 2);
        $form = unpack("n", $dat);

        $s->{'Format'} = $form;
        if ($form == 0)
        {
            my $j = 0;

            $fh->read($dat, 4);
            ($len, $s->{'Ver'}) = unpack('n2', $dat);
            $fh->read($dat, 256);
            $s->{'val'} = {map {$j++; ($_ ? ($j - 1, $_) : ())} unpack("C*", $dat)};
        } elsif ($form == 6)
        {
            my ($start, $ecount);
            
            $fh->read($dat, 8);
            ($len, $s->{'Ver'}, $start, $ecount) = unpack('n4', $dat);
            $fh->read($dat, $ecount << 1);
            $s->{'val'} = {map {$start++; ($_ ? ($start - 1, $_) : ())} unpack("n*", $dat)};
        } elsif ($form == 2)        # Contributed by Huw Rogers
        {
            $fh->read($dat, 4);
            ($len, $s->{'Ver'}) = unpack('n2', $dat);
            $fh->read($dat, 512);
            my ($j, $k, $l, $m, $n, @subHeaderKeys, @subHeaders, $subHeader);
            $n = 1;
            for ($j = 0; $j < 256; $j++) {
                my $k = unpack('@'.($j<<1).'n', $dat)>>3;
                $n = $k + 1 if $k >= $n;
                $subHeaders[$subHeaderKeys[$j] = $k] ||= [ ];
            }
            $fh->read($dat, $n<<3); # read subHeaders[]
            for ($k = 0; $k < $n; $k++) {
                $subHeader = $subHeaders[$k];
                $l = $k<<3;
                @$subHeader = unpack('@'.$l.'n4', $dat);
                $subHeader->[2] = unpack('s', pack('S', $subHeader->[2]))
                    if $subHeader->[2] & 0x8000; # idDelta
                $subHeader->[3] =
                    ($subHeader->[3] - (($n - $k)<<3) + 6)>>1; # idRangeOffset
            }
            $fh->read($dat, $len - ($n<<3) - 518); # glyphIndexArray[]
            for ($j = 0; $j < 256; $j++) {
                $k = $subHeaderKeys[$j];
                $subHeader = $subHeaders[$k];
                unless ($k) {
                    $l = $j - $subHeader->[0];
                    if ($l >= 0 && $l < $subHeader->[1]) {
                        $m = unpack('@'.(($l + $subHeader->[3])<<1).'n', $dat);
                        $m += $subHeader->[2] if $m;
                        $s->{'val'}{$j} = $m;
                    }
                } else {
                    for ($l = 0; $l < $subHeader->[1]; $l++) {
                        $m = unpack('@'.(($l + $subHeader->[3])<<1).'n', $dat);
                        $m += $subHeader->[2] if $m;
                        $s->{'val'}{($j<<8) + $l + $subHeader->[0]} = $m;
                    }
                }
            }
        } elsif ($form == 4)
        {
            $fh->read($dat, 12);
            ($len, $s->{'Ver'}, $num) = unpack('n3', $dat);
            $num >>= 1;
            $fh->read($dat, $len - 14);
            for ($j = 0; $j < $num; $j++)
            {
                $end = unpack("n", substr($dat, $j << 1, 2));
                $start = unpack("n", substr($dat, ($j << 1) + ($num << 1) + 2, 2));
                $delta = unpack("n", substr($dat, ($j << 1) + ($num << 2) + 2, 2));
                $delta -= 65536 if $delta > 32767;
                $range = unpack("n", substr($dat, ($j << 1) + $num * 6 + 2, 2));
                for ($k = $start; $k <= $end; $k++)
                {
                    if ($range == 0 || $range == 65535)         # support the buggy FOG with its range=65535 for final segment
                    { $id = $k + $delta; }
                    else
                    { $id = unpack("n", substr($dat, ($j << 1) + $num * 6 +
                                        2 + ($k - $start) * 2 + $range, 2)) + $delta; }
                            $id -= 65536 if $id >= 65536;
                    $s->{'val'}{$k} = $id if ($id);
                }
            }
        } elsif ($form == 8 || $form == 12)
        {
            $fh->read($dat, 10);
            ($len, $s->{'Ver'}) = unpack('x2N2', $dat);
            if ($form == 8)
            {
                $fh->read($dat, 8196);
                $num = unpack("N", substr($dat, 8192, 4)); # don't need the map
            } else
            {
                $fh->read($dat, 4);
                $num = unpack("N", $dat);
            }
            $fh->read($dat, 12 * $num);
            for ($j = 0; $j < $num; $j++)
            {
                ($start, $end, $sg) = unpack("N3", substr($dat, $j * 12, 12));
                for ($k = $start; $k <= $end; $k++)
                { $s->{'val'}{$k} = $sg++; }
            }
        } elsif ($form == 10)
        {
            $fh->read($dat, 18);
            ($len, $s->{'Ver'}, $start, $num) = unpack('x2N4', $dat);
            $fh->read($dat, $num << 1);
            for ($j = 0; $j < $num; $j++)
            { $s->{'val'}{$start + $j} = unpack("n", substr($dat, $j << 1, 2)); }
        }
    }
    $self;
}


=head2 $t->ms_lookup($uni)

Finds a Unicode table, giving preference to the MS one, and looks up the given
Unicode codepoint in it to find the glyph id.

=cut

sub ms_lookup
{
    my ($self, $uni) = @_;

    $self->find_ms || return undef unless (defined $self->{' mstable'});
    return $self->{' mstable'}{'val'}{$uni};
}


=head2 $t->find_ms

Finds the a Unicode table, giving preference to the Microsoft one, and sets the C<mstable> instance variable
to it if found. Returns the table it finds.

=cut
sub find_ms
{
    my ($self) = @_;
    my ($i, $s, $alt, $found);

    return $self->{' mstable'} if defined $self->{' mstable'};
    $self->read;
    for ($i = 0; $i < $self->{'Num'}; $i++)
    {
        $s = $self->{'Tables'}[$i];
        if ($s->{'Platform'} == 3)
        {
            $self->{' mstable'} = $s;
            last if ($s->{'Encoding'} == 10);
            $found = 1 if ($s->{'Encoding'} == 1);
        } elsif ($s->{'Platform'} == 0 || ($s->{'Platform'} == 2 && $s->{'Encoding'} == 1))
        { $alt = $s; }
    }
    $self->{' mstable'} = $alt if ($alt && !$found);
    $self->{' mstable'};
}


=head2 $t->ms_enc

Returns the encoding of the microsoft table (0 => symbol, etc.). Returns undef if there is
no Microsoft cmap.

=cut

sub ms_enc
{
    my ($self) = @_;
    my ($s);
    
    return $self->{' mstable'}{'Encoding'} 
        if (defined $self->{' mstable'} && $self->{' mstable'}{'Platform'} == 3);
    
    foreach $s (@{$self->{'Tables'}})
    {
        return $s->{'Encoding'} if ($s->{'Platform'} == 3);
    }
    return undef;
}


=head2 $t->out($fh)

Writes out a cmap table to a filehandle. If it has not been read, then
just copies from input file to output

=cut

sub out
{
    my ($self, $fh) = @_;
    my ($loc, $s, $i, $base_loc, $j, @keys);

    return $self->SUPER::out($fh) unless $self->{' read'};


    $self->{'Tables'} = [sort {$a->{'Platform'} <=> $b->{'Platform'}
                                || $a->{'Encoding'} <=> $b->{'Encoding'}
                                || $a->{'Ver'} <=> $b->{'Ver'}} @{$self->{'Tables'}}];
    $self->{'Num'} = scalar @{$self->{'Tables'}};

    $base_loc = $fh->tell();
    $fh->print(pack("n2", 0, $self->{'Num'}));

    for ($i = 0; $i < $self->{'Num'}; $i++)
    { $fh->print(pack("nnN", $self->{'Tables'}[$i]{'Platform'}, $self->{'Tables'}[$i]{'Encoding'}, 0)); }

    for ($i = 0; $i < $self->{'Num'}; $i++)
    {
        $s = $self->{'Tables'}[$i];
        if ($s->{'Format'} < 8)
        { @keys = sort {$a <=> $b} grep { $_ <= 0xFFFF} keys %{$s->{'val'}}; }
        else
        { @keys = sort {$a <=> $b} keys %{$s->{'val'}}; }
        $s->{' outloc'} = $fh->tell();
        if ($s->{'Format'} < 8)
        { $fh->print(pack("n3", $s->{'Format'}, 0, $s->{'Ver'})); }       # come back for length
        else
        { $fh->print(pack("n2N2", $s->{'Format'}, 0, 0, $s->{'Ver'})); }
            
        if ($s->{'Format'} == 0)
        {
            $fh->print(pack("C256", @{$s->{'val'}}{0 .. 255}));
        } elsif ($s->{'Format'} == 6)
        {
            $fh->print(pack("n2", $keys[0], $keys[-1] - $keys[0] + 1));
            $fh->print(pack("n*", @{$s->{'val'}}{$keys[0] .. $keys[-1]}));
        } elsif ($s->{'Format'} == 2)       # Contributed by Huw Rogers
        {
            my ($g, $k, $h, $l, $m, $n);
            my (@subHeaderKeys, @subHeaders, $subHeader, @glyphIndexArray);
            $n = 0;
            @subHeaderKeys = (-1) x 256;
            for $j (@keys) {
                next unless defined($g = $s->{'val'}{$j});
                $h = int($j>>8);
                $l = ($j & 0xff);
                if (($k = $subHeaderKeys[$h]) < 0) {
                    $subHeader = [ $l, 1, 0, 0, [ $g ] ];
                    $subHeaders[$k = $n++] = $subHeader;
                    $subHeaderKeys[$h] = $k;
                } else {
                    $subHeader = $subHeaders[$k];
                    $m = ($l - $subHeader->[0] + 1) - $subHeader->[1];
                    $subHeader->[1] += $m;
                    push @{$subHeader->[4]}, (0) x ($m - 1), $g - $subHeader->[2];
                }
            }
            @subHeaderKeys = map { $_ < 0 ? 0 : $_ } @subHeaderKeys;
            $subHeader = $subHeaders[0];
            $subHeader->[3] = 0;
            push @glyphIndexArray, @{$subHeader->[4]};
            splice(@$subHeader, 4);
            {
                my @subHeaders_ = sort {@{$a->[4]} <=> @{$b->[4]}} @subHeaders[1..$#subHeaders];
                my ($f, $d, $r, $subHeader_);
                for ($k = 0; $k < @subHeaders_; $k++) {
                    $subHeader = $subHeaders_[$k];
                    $f = $r = shift @{$subHeader->[4]};
                    $subHeader->[5] = join(':',
                        map {
                            $d = $_ - $r;
                            $r = $_;
                            $d < 0 ?
                                sprintf('-%04x', -$d) :
                                sprintf('+%04x', $d)
                        } @{$subHeader->[4]});
                    unshift @{$subHeader->[4]}, $f;
                }
                for ($k = 0; $k < @subHeaders_; $k++) {
                    $subHeader = $subHeaders_[$k];
                    next unless $subHeader->[4];
                    $subHeader->[3] = @glyphIndexArray;
                    push @glyphIndexArray, @{$subHeader->[4]};
                    for ($l = $k + 1; $l < @subHeaders_; $l++) {
                        $subHeader_ = $subHeaders_[$l];
                        next unless $subHeader_->[4];
                        $d = $subHeader_->[5];
                        if ($subHeader->[5] =~ /\Q$d\E/) {
                            my $o = length($`)/6;               #`
                            $subHeader_->[2] +=
                                $subHeader_->[4]->[$o] - $subHeader->[4]->[0];
                            $subHeader_->[3] = $subHeader->[3] + $o;
                            splice(@$subHeader_, 4);
                        }
                    }
                    splice(@$subHeader, 4);
                }
            }
            $fh->print(pack('n*', map { $_<<3 } @subHeaderKeys));
            for ($j = 0; $j < 256; $j++) {
                $k = $subHeaderKeys[$j];
                $subHeader = $subHeaders[$k];
            }
            for ($k = 0; $k < $n; $k++) {
                $subHeader = $subHeaders[$k];
                $fh->print(pack('n4',
                    $subHeader->[0],
                    $subHeader->[1],
                    $subHeader->[2] < 0 ?
                        unpack('S', pack('s', $subHeader->[2])) :
                        $subHeader->[2],
                    ($subHeader->[3]<<1) + (($n - $k)<<3) - 6
                ));
            }
            $fh->print(pack('n*', @glyphIndexArray));
        } elsif ($s->{'Format'} == 4)
        {
            my ($num, $sRange, $eSel, $eShift, @starts, @ends, $doff);
            my (@deltas, $delta, @range, $flat, $k, $segs, $count, $newseg, $v);

            push(@keys, 0xFFFF) unless ($keys[-1] == 0xFFFF);
            $newseg = 1; $num = 0;
            for ($j = 0; $j <= $#keys && $keys[$j] <= 0xFFFF; $j++)
            {
                $v = $s->{'val'}{$keys[$j]} || 0;
                if ($newseg)
                {
                    $delta = $v;
                    $doff = $j;
                    $flat = 1;
                    push(@starts, $keys[$j]);
                    $newseg = 0;
                }
                $delta = 0 if ($delta + $j - $doff != $v);
                $flat = 0 if ($v == 0);
                if ($j == $#keys || $keys[$j] + 1 != $keys[$j+1])
                {
                    push (@ends, $keys[$j]);
                    push (@deltas, $delta ? $delta - $keys[$doff] : 0);
                    push (@range, $flat);
                    $num++;
                    $newseg = 1;
                }
            }

            ($num, $sRange, $eSel, $eShift) = Font::TTF::Utils::TTF_bininfo($num, 2);
            $fh->print(pack("n4", $num * 2, $sRange, $eSel, $eShift));
            $fh->print(pack("n*", @ends));
            $fh->print(pack("n", 0));
            $fh->print(pack("n*", @starts));
            $fh->print(pack("n*", @deltas));

            $count = 0;
            for ($j = 0; $j < $num; $j++)
            {
                $delta = $deltas[$j];
                if ($delta != 0 && $range[$j] == 1)
                { $range[$j] = 0; }
                else
                {
                    $range[$j] = ($count + $num - $j) << 1;
                    $count += $ends[$j] - $starts[$j] + 1;
                }
            }

            $fh->print(pack("n*", @range));

            for ($j = 0; $j < $num; $j++)
            {
                next if ($range[$j] == 0);
                $fh->print(pack("n*", map {$_ || 0} @{$s->{'val'}}{$starts[$j] .. $ends[$j]}));
            }
        } elsif ($s->{'Format'} == 8 || $s->{'Format'} == 12)
        {
            my (@jobs, $start, $current, $curr_glyf, $map);
            
            $current = 0; $curr_glyf = 0;
            $map = "\000" x 8192;
            foreach $j (@keys)
            {
                if ($j > 0xFFFF)
                {
                    if (defined $s->{'val'}{$j >> 16})
                    { $s->{'Format'} = 12; }
                    vec($map, $j >> 16, 1) = 1;
                }
                if ($j != $current + 1 || $s->{'val'}{$j} != $curr_glyf + 1)
                {
                    push (@jobs, [$start, $current, $curr_glyf - ($current - $start)]) if (defined $start);
                    $start = $j; $current = $j; $curr_glyf = $s->{'val'}{$j};
                }
                $current = $j;
                $curr_glyf = $s->{'val'}{$j};
            }
            push (@jobs, [$start, $current, $curr_glyf - ($current - $start)]) if (defined $start);
            $fh->print($map) if ($s->{'Format'} == 8);
            $fh->print(pack('N', $#jobs + 1));
            foreach $j (@jobs)
            { $fh->print(pack('N3', @{$j})); }
        } elsif ($s->{'Format'} == 10)
        {
            $fh->print(pack('N2', $keys[0], $keys[-1] - $keys[0] + 1));
            $fh->print(pack('n*', $s->{'val'}{$keys[0] .. $keys[-1]}));
        }

        $loc = $fh->tell();
        if ($s->{'Format'} < 8)
        {
            $fh->seek($s->{' outloc'} + 2, 0);
            $fh->print(pack("n", $loc - $s->{' outloc'}));
        } else
        {
            $fh->seek($s->{' outloc'} + 4, 0);
            $fh->print(pack("N", $loc - $s->{' outloc'}));
        }
        $fh->seek($base_loc + 8 + ($i << 3), 0);
        $fh->print(pack("N", $s->{' outloc'} - $base_loc));
        $fh->seek($loc, 0);
    }
    $self;
}


=head2 $t->XML_element($context, $depth, $name, $val)

Outputs the elements of the cmap in XML. We only need to process val here

=cut

sub XML_element
{
    my ($self, $context, $depth, $k, $val) = @_;
    my ($fh) = $context->{'fh'};
    my ($i);

    return $self if ($k eq 'LOC');
    return $self->SUPER::XML_element($context, $depth, $k, $val) unless ($k eq 'val');

    $fh->print("$depth<mappings>\n");
    foreach $i (sort {$a <=> $b} keys %{$val})
    { $fh->printf("%s<map code='%04X' glyph='%s'/>\n", $depth . $context->{'indent'}, $i, $val->{$i}); }
    $fh->print("$depth</mappings>\n");
    $self;
}

=head2 @map = $t->reverse(%opt)

Returns a reverse map of the Unicode cmap. I.e. given a glyph gives the Unicode value for it. Options are:

=over 4

=item tnum

Table number to use rather than the default Unicode table

=item array

Returns each element of reverse as an array since a glyph may be mapped by more
than one Unicode value. The arrays are unsorted. Otherwise store any one unicode value for a glyph.

=back

=cut

sub reverse
{
    my ($self, %opt) = @_;
    my ($table) = defined $opt{'tnum'} ? $self->{'Tables'}[$opt{'tnum'}] : $self->find_ms;
    my (@res, $code, $gid);

    while (($code, $gid) = each(%{$table->{'val'}}))
    {
        if ($opt{'array'})
        { push (@{$res[$gid]}, $code); }
        else
        { $res[$gid] = $code unless (defined $res[$gid] && $res[$gid] > 0 && $res[$gid] < $code); }
    }
    @res;
}


=head2 is_unicode($index)

Returns whether the table of a given index is known to be a unicode table
(as specified in the specifications)

=cut

sub is_unicode
{
    my ($self, $index) = @_;
    my ($pid, $eid) = ($self->{'Tables'}[$index]{'Platform'}, $self->{'Tables'}[$index]{'Encoding'});

    return ($pid == 3 || $pid == 0 || ($pid == 2 && $eid == 1));
}

1;

=head1 BUGS

=over 4

=item *

No support for format 2 tables (MBCS)

=back

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

