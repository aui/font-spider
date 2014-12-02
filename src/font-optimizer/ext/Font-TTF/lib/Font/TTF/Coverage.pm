package Font::TTF::Coverage;

=head1 NAME

Font::TTF::Coverage - Opentype coverage and class definition objects

=head1 DESCRIPTION

Coverage tables and class definition objects are virtually identical concepts
in OpenType. Their difference comes purely in their storage. Therefore we can
say that a coverage table is a class definition in which the class definition
for each glyph is the corresponding index in the coverage table. The resulting
data structure is that a Coverage table has the following fields:

=item cover

A boolean to indicate whether this table is a coverage table (TRUE) or a
class definition (FALSE)

=item val

A hash of glyph ids against values (either coverage index or class value)

=item fmt

The storage format used is given here, but is recalculated when the table
is written out.

=item count

A count of the elements in a coverage table for use with add. Each subsequent
addition is added with the current count and increments the count.

=head1 METHODS

=cut

=head2 new($isCover [, vals])

Creates a new coverage table or class definition table, depending upon the
value of $isCover. if $isCover then vals may be a list of glyphs to include in order.
If no $isCover, then vals is a hash of glyphs against class values.

=cut

sub new
{
    my ($class) = shift;
    my ($isCover) = shift;
    my ($self) = {};

    $self->{'cover'} = $isCover;
    $self->{'count'} = 0;
    if ($isCover)
    {
        my ($v);
        foreach $v (@_)
        { $self->{'val'}{$v} = $self->{'count'}++; }
    }
    else
    {
        $self->{'val'} = {@_};
        foreach (values %{$self->{'val'}}) {$self->{'max'} = $_ if $_ > $self->{'max'}}
    }
    bless $self, $class;
}


=head2 read($fh)

Reads the coverage/class table from the given file handle

=cut

sub read
{
    my ($self, $fh) = @_;
    my ($dat, $fmt, $num, $i, $c);

    $fh->read($dat, 4);
    ($fmt, $num) = unpack("n2", $dat);
    $self->{'fmt'} = $fmt;

    if ($self->{'cover'})
    {
        if ($fmt == 1)
        {
            $fh->read($dat, $num << 1);
            map {$self->{'val'}{$_} = $i++} unpack("n*", $dat);
        } elsif ($fmt == 2)
        {
            $fh->read($dat, $num * 6);
            for ($i = 0; $i < $num; $i++)
            {
                ($first, $last, $c) = unpack("n3", substr($dat, $i * 6, 6));
                map {$self->{'val'}{$_} = $c++} ($first .. $last);
            }
        }
        $self->{'count'} = $num;
    } elsif ($fmt == 1)
    {
        $fh->read($dat, 2);
        $first = $num;
        ($num) = unpack("n", $dat);
        $fh->read($dat, $num << 1);
        map {$self->{'val'}{$first++} = $_; $self->{'max'} = $_ if ($_ > $self->{'max'})} unpack("n*", $dat);
    } elsif ($fmt == 2)
    {
        $fh->read($dat, $num * 6);
        for ($i = 0; $i < $num; $i++)
        {
            ($first, $last, $c) = unpack("n3", substr($dat, $i * 6, 6));
            map {$self->{'val'}{$_} = $c} ($first .. $last);
            $self->{'max'} = $c if ($c > $self->{'max'});
        }
    }
    $self;
}


=head2 out($fh, $state)

Writes the coverage/class table to the given file handle. If $state is 1 then
the output string is returned rather than being output to a filehandle.

=cut

sub out
{
    my ($self, $fh, $state) = @_;
    my ($g, $eff, $grp, $out);
    my ($shipout) = ($state ? sub {$out .= $_[0];} : sub {$fh->print($_[0]);});
    my (@gids) = sort {$a <=> $b} keys %{$self->{'val'}};

    $fmt = 1; $grp = 1; $eff = 0;
    for ($i = 1; $i <= $#gids; $i++)
    {
        if ($self->{'val'}{$gids[$i]} < $self->{'val'}{$gids[$i-1]} && $self->{'cover'})
        {
            $fmt = 2;
            last;
        } elsif ($gids[$i] == $gids[$i-1] + 1 && ($self->{'cover'} || $self->{'val'}{$gids[$i]} == $self->{'val'}{$gids[$i-1]}))
        { $eff++; }
        else
        {
            $grp++;
            $eff += $gids[$i] - $gids[$i-1] if (!$self->{'cover'});
        }
    }
#    if ($self->{'cover'})
    { $fmt = 2 if ($eff / $grp > 3); }
#    else
#    { $fmt = 2 if ($grp > 1); }
    
    if ($fmt == 1 && $self->{'cover'})
    {
        my ($last) = 0;
        &$shipout(pack('n2', 1, scalar @gids));
        &$shipout(pack('n*', @gids));
    } elsif ($fmt == 1)
    {
        my ($last) = $gids[0];
        &$shipout(pack("n3", 1, $last, $gids[-1] - $last + 1));
        foreach $g (@gids)
        {
            if ($g > $last + 1)
            { &$shipout(pack('n*', (0) x ($g - $last - 1))); }
            &$shipout(pack('n', $self->{'val'}{$g}));
            $last = $g;
        }
    } else
    {
        my ($start, $end, $ind, $numloc, $endloc, $num);
        &$shipout(pack("n2", 2, 0));
        $numloc = $fh->tell() - 2 unless $state;

        $start = 0; $end = 0; $num = 0;
        while ($end < $#gids)
        {
            if ($gids[$end + 1] == $gids[$end] + 1
                && $self->{'val'}{$gids[$end + 1]}
                        == $self->{'val'}{$gids[$end]}
                           + ($self->{'cover'} ? 1 : 0))
            {
                $end++;
                next;
            }

            &$shipout(pack("n3", $gids[$start], $gids[$end],
                    $self->{'val'}{$gids[$start]}));
            $start = $end + 1;
            $end++;
            $num++;
        }
        &$shipout(pack("n3", $gids[$start], $gids[$end],
                $self->{'val'}{$gids[$start]}));
        $num++;
        if ($state)
        { substr($out, 2, 2) = pack('n', $num); }
        else
        {
            $endloc = $fh->tell();
            $fh->seek($numloc, 0);
            $fh->print(pack("n", $num));
            $fh->seek($endloc, 0);
        }
    }
    return ($state ? $out : $self);
}


=head2 $c->add($glyphid[, $class])

Adds a glyph id to the coverage table incrementing the count so that each subsequent addition
has the next sequential number. Returns the index number of the glyphid added

=cut

sub add
{
    my ($self, $gid, $class) = @_;
    
    return $self->{'val'}{$gid} if (defined $self->{'val'}{$gid});
    if ($self->{'cover'})
    {
        $self->{'val'}{$gid} = $self->{'count'};
        return $self->{'count'}++;
    }
    else
    {
        $self->{'val'}{$gid} = $class || '0';
        $self->{'max'} = $class if ($class > $self->{'max'});
        return $class;
    }
}


=head2 $c->signature

Returns a vector of all the glyph ids covered by this coverage table or class

=cut

sub signature
{
    my ($self) = @_;
    my ($vec, $range, $size);

if (0)
{
    if ($self->{'cover'})
    { $range = 1; $size = 1; }
    else
    {
        $range = $self->{'max'};
        $size = 1;
        while ($range > 1)
        {
            $size = $size << 1;
            $range = $range >> 1;
        }
        $range = $self->{'max'} + 1;
    }
    foreach (keys %{$self->{'val'}})
    { vec($vec, $_, $size) = $self->{'val'}{$_} > $range ? $range : $self->{'val'}{$_}; }
    length($vec) . ":" . $vec;
}
    $vec = join(";", map{"$_,$self->{'val'}{$_}"} keys %{$self->{'val'}});
}

=head2 @map=$c->sort

Sorts the coverage table so that indexes are in ascending order of glyphid.
Returns a map such that $map[$new_index]=$old_index.

=cut

sub sort
{
    my ($self) = @_;
    my (@res, $i);

    foreach (sort {$a <=> $b} keys %{$self->{'val'}})
    {
        push(@res, $self->{'val'}{$_});
        $self->{'val'}{$_} = $i++;
    }
    @res;
}

=head2 $c->out_xml($context)

Outputs this coverage/class in XML

=cut

sub out_xml
{
    my ($self, $context, $depth) = @_;
    my ($fh) = $context->{'fh'};

    $fh->print("$depth<" . ($self->{'cover'} ? 'coverage' : 'class') . ">\n");
    foreach $gid (sort {$a <=> $b} keys %{$self->{'val'}})
    {
        $fh->printf("$depth$context->{'indent'}<gref glyph='%s' val='%s'/>\n", $gid, $self->{'val'}{$gid});
    }
    $fh->print("$depth</" . ($self->{'cover'} ? 'coverage' : 'class') . ">\n");
    $self;
}

sub release
{ }


=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

1;

