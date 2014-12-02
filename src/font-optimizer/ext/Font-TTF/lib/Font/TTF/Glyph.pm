package Font::TTF::Glyph;

=head1 NAME

Font::TTF::Glyph - Holds a single glyph's information

=head1 DESCRIPTION

This is a single glyph description as held in a TT font. On creation only its
header is read. Thus you can get the bounding box of each glyph without having
to read all the other information.

=head1 INSTANCE VARIABLES

In addition to the named variables in a glyph header (C<xMin> etc.), there are
also all capital instance variables for holding working information, mostly
from the location table.

The standard attributes each glyph has are:

 numberOfContours
 xMin
 yMin
 xMax
 yMax

There are also other, derived, instance variables for each glyph which are read
when the whole glyph is read (via C<read_dat>):

=over 4

=item instLen

Number of bytes in the hinting instructions (Warning this variable is deprecated,
use C<length($g->{'hints'})> instead).

=item hints

The string containing the hinting code for the glyph

=back

In addition there are other attribute like instance variables for simple glyphs:

=over 4

For each contour there is:

=over 4

=item endPoints

An array of endpoints for each contour in the glyph. There are
C<numberOfContours> contours in a glyph. The number of points in a glyph is
equal to the highest endpoint of a contour.

=back

There are also a number of arrays indexed by point number

=over 4

=item flags

The flags associated with reading this point. The flags for a point are
recalculated for a point when it is C<update>d. Thus the flags are not very
useful. The only important bit is bit 0 which indicates whether the point is
an 'on' curve point, or an 'off' curve point.

=item x

The absolute x co-ordinate of the point.

=item y

The absolute y co-ordinate of the point

=back

=back

For composite glyphs there are other variables

=over 4

=item metric

This holds the component number (not its glyph number) of the component from
which the metrics for this glyph should be taken.

=item comps

This is an array of hashes for each component. Each hash has a number of
elements:

=over 4

=item glyph

The glyph number of the glyph which comprises this component of the composite.
NOTE: In some badly generated fonts, C<glyph> may contain a numerical value
but that glyph might not actually exist in the font file.  This could
occur in any glyph, but is particularly likely for glyphs that have
no strokes, such as SPACE, U+00A0 NO-BREAK SPACE, or 
U+200B ZERO WIDTH SPACE.

=item args

An array of two arguments which may be an x, y co-ordinate or two attachment
points (one on the base glyph the other on the component). See flags for details.

=item flag

The flag for this component

=item scale

A 4 number array for component scaling. This allows stretching, rotating, etc.
Note that scaling applies to placement co-ordinates (rather than attachment points)
before locating rather than after.

=back

=item numPoints

This is a generated value which contains the number of components read in for this
compound glyph.

=back

The private instance variables are:

=over 4

=item INFILE (P)

The input file form which to read any information

=item LOC (P)

Location relative to the start of the glyf table in the read file

=item BASE (P)

The location of the glyf table in the read file

=item LEN (P)

This is the number of bytes required by the glyph. It should be kept up to date
by calling the C<update> method whenever any of the glyph content changes.

=item OUTLOC (P)

Location relative to the start of the glyf table. This variable is only active
whilst the output process is going on. It is used to inform the location table
where the glyph's location is, since the glyf table is output before the loca
table due to alphabetical ordering.

=item OUTLEN (P)

This indicates the length of the glyph data when it is output. This more
accurately reflects the internal memory form than the C<LEN> variable which
only reflects the read file length. The C<OUTLEN> variable is only set after
calling C<out> or C<out_dat>.

=back

=head2 Editing

If you want to edit a glyph in some way, then you should read_dat the glyph, then
make your changes and then update the glyph or set the $g->{' isdirty'} variable.
It is the application's duty to ensure that the following instance variables are
correct, from which update will calculate the rest, including the bounding box
information.

    numPoints
    numberOfContours
    endPoints
    x, y, flags         (only flags bit 0)
    instLen
    hints

For components, the numPoints, x, y, endPoints & flags are not required but
the following information is required for each component.

    flag                (bits 2, 10, 11, 12)
    glyph
    args
    scale
    metric              (glyph instance variable)
    

=head1 METHODS

=cut

use strict;
use vars qw(%fields @field_info);
use Font::TTF::Utils;
use Font::TTF::Table;

@field_info = (
    'numberOfContours' => 's', 
    'xMin' => 's', 
    'yMin' => 's',
    'xMax' => 's',
    'yMax' => 's');

sub init
{
    my ($k, $v, $c, $i);
    for ($i = 0; $i < $#field_info; $i += 2)
    {
        ($k, $v, $c) = TTF_Init_Fields($field_info[$i], $c, $field_info[$i + 1]);
        next unless defined $k && $k ne "";
        $fields{$k} = $v;
    }
}


=head1 Font::TTF::Glyph->new(%parms)

Creates a new glyph setting various instance variables

=cut

sub new
{
    my ($class, %parms) = @_;
    my ($self) = {};
    my ($p);

    bless $self, $class;
    foreach $p (keys %parms)
    { $self->{" $p"} = $parms{$p}; }
    init unless defined $fields{'xMin'};
    $self;
}


=head2 $g->read

Reads the header component of the glyph (bounding box, etc.) and also the
glyph content, but into a data field rather than breaking it down into
its constituent structures. Use read_dat for this.

=cut

sub read
{
    my ($self) = @_;
    my ($fh) = $self->{' INFILE'};
    my ($dat);

    return $self if $self->{' read'};
    $self->{' read'} = 1;
    $fh->seek($self->{' LOC'} + $self->{' BASE'}, 0);
    $fh->read($self->{' DAT'}, $self->{' LEN'});
    TTF_Read_Fields($self, $self->{' DAT'}, \%fields);
    $self;
}


=head2 $g->read_dat

Reads the contents of the glyph (components and curves, etc.) from the memory
store C<DAT> into structures within the object. Then, to indicate where the
master form of the data is, it deletes the C<DAT> instance variable.

=cut

sub read_dat
{
    my ($self) = @_;
    my ($dat, $num, $max, $i, $flag, $len, $val, $val1, $fp);

    return $self if (defined $self->{' read'} && $self->{' read'} > 1);
    $self->read unless $self->{' read'};
    $dat = $self->{' DAT'};
    $fp = 10;
    $num = $self->{'numberOfContours'};
    if ($num > 0)
    {
        $self->{'endPoints'} = [unpack("n*", substr($dat, $fp, $num << 1))];
        $fp += $num << 1;
        $max = 0;
        foreach (@{$self->{'endPoints'}})
        { $max = $_ if $_ > $max; }
#        print STDERR join(",", unpack('C*', $self->{" DAT"}));
#        printf STDERR ("(%d,%d in %d=%d @ %d)", scalar @{$self->{'endPoints'}}, $max, length($dat), $self->{' LEN'}, $fp);
        $max++ if (@{$self->{'endPoints'}});
        $self->{'numPoints'} = $max;
        $self->{'instLen'} = unpack("n", substr($dat, $fp));
        $self->{'hints'} = substr($dat, $fp + 2, $self->{'instLen'});
        $fp += 2 + $self->{'instLen'};
# read the flags array
        for ($i = 0; $i < $max; $i++)                   
        {
            $flag = unpack("C", substr($dat, $fp++));
            $self->{'flags'}[$i] = $flag;
            if ($flag & 8)
            {
                $len = unpack("C", substr($dat, $fp++));
                while ($len-- > 0)
                {
                    $i++;
                    $self->{'flags'}[$i] = $flag;
                }
            }
        }
#read the x array
        for ($i = 0; $i < $max; $i++)
        {
            $flag = $self->{'flags'}[$i];
            if ($flag & 2)
            {
                $val = unpack("C", substr($dat, $fp++));
                $val = -$val unless ($flag & 16);
            } elsif ($flag & 16)
            { $val = 0; }
            else
            {
                $val = TTF_Unpack("s", substr($dat, $fp));
                $fp += 2;
            }
            $self->{'x'}[$i] = $i == 0 ? $val : $self->{'x'}[$i - 1] + $val;
        }
#read the y array
        for ($i = 0; $i < $max; $i++)
        {
            $flag = $self->{'flags'}[$i];
            if ($flag & 4)
            {
                $val = unpack("C", substr($dat, $fp++));
                $val = -$val unless ($flag & 32);
            } elsif ($flag & 32)
            { $val = 0; }
            else
            {
                $val = TTF_Unpack("s", substr($dat, $fp));
                $fp += 2;
            }
            $self->{'y'}[$i] = $i == 0 ? $val : $self->{'y'}[$i - 1] + $val;
        }
    }
    
# compound glyph
    elsif ($num < 0)
    {
        $flag = 1 << 5;             # cheat to get the loop going
        for ($i = 0; $flag & 32; $i++)
        {
            ($flag, $self->{'comps'}[$i]{'glyph'}) = unpack("n2", substr($dat, $fp));
            $fp += 4;
            $self->{'comps'}[$i]{'flag'} = $flag;
            if ($flag & 1)              # ARGS1_AND_2_ARE_WORDS
            {
                $self->{'comps'}[$i]{'args'} = [TTF_Unpack("s2", substr($dat, $fp))];
                $fp += 4;
            } else
            {
                $self->{'comps'}[$i]{'args'} = [unpack("c2", substr($dat, $fp))];
                $fp += 2;
            }
            
            if ($flag & 8)
            {
                $val = TTF_Unpack("F", substr($dat, $fp));
                $fp += 2;
                $self->{'comps'}[$i]{'scale'} = [$val, 0, 0, $val];
            } elsif ($flag & 64)
            {
                ($val, $val1) = TTF_Unpack("F2", substr($dat, $fp));
                $fp += 4;
                $self->{'comps'}[$i]{'scale'} = [$val, 0, 0, $val1];
            } elsif ($flag & 128)
            {
                $self->{'comps'}[$i]{'scale'} = [TTF_Unpack("F4", substr($dat, $fp))];
                $fp += 8;
            }
            $self->{'metric'} = $i if ($flag & 512);
        }
        $self->{'numPoints'} = $i;
        if ($flag & 256)            # HAVE_INSTRUCTIONS
        {
            $self->{'instLen'} = unpack("n", substr($dat, $fp));
            $self->{'hints'} = substr($dat, $fp + 2, $self->{'instLen'});
            $fp += 2 + $self->{'instLen'};
        }
    }
    return undef if ($fp > length($dat));
    $self->{' read'} = 2;
    $self;
}


=head2 $g->out($fh)

Writes the glyph data to outfile

=cut

sub out
{
    my ($self, $fh) = @_;

    $self->read unless $self->{' read'};
    $self->update if $self->{' isDirty'};
    $fh->print($self->{' DAT'});
    $self->{' OUTLEN'} = length($self->{' DAT'});
    $self;
}


=head2 $g->out_xml($context, $depth)

Outputs an XML description of the glyph

=cut

sub out_xml
{
    my ($self, $context, $depth) = @_;
    my ($addr) = ($self =~ m/\((.+)\)$/o);
    my ($k, $ndepth);

    if ($context->{'addresses'}{$addr})
    {
        $context->{'fh'}->printf("%s<glyph gid='%s' id_ref='%s'/>\n", $depth, $context->{'gid'}, $addr);
        return $self;
    }
    else
    {
        $context->{'fh'}->printf("%s<glyph gid='%s' id='%s'>\n", $depth, $context->{'gid'}, $addr);
    }
    
    $ndepth = $depth . $context->{'indent'};
    $self->read_dat;
    foreach $k (sort grep {$_ !~ m/^\s/o} keys %{$self})
    {
        $self->XML_element($context, $ndepth, $k, $self->{$k});
    }
    $context->{'fh'}->print("$depth</glyph>\n");
    delete $context->{'done_points'};
    $self;
}
    

sub XML_element
{
    my ($self, $context, $depth, $key, $val) = @_;
    my ($fh) = $context->{'fh'};
    my ($dind) = $depth . $context->{'indent'};
    my ($i);
    
    if ($self->{'numberOfContours'} >= 0 && ($key eq 'x' || $key eq 'y' || $key eq 'flags'))
    {
        return $self if ($context->{'done_points'});
        $context->{'done_points'} = 1;

        $fh->print("$depth<points>\n");
        for ($i = 0; $i <= $#{$self->{'flags'}}; $i++)
        { $fh->printf("%s<point x='%s' y='%s' flags='0x%02X'/>\n", $dind,
                $self->{'x'}[$i], $self->{'y'}[$i], $self->{'flags'}[$i]); }
        $fh->print("$depth</points>\n");
    }
    elsif ($key eq 'hints')
    {
        my ($dat);
        $fh->print("$depth<hints>\n");
#        Font::TTF::Utils::XML_hexdump($context, $depth . $context->{'indent'}, $self->{'hints'});
        $dat = Font::TTF::Utils::XML_binhint($self->{'hints'}) || "";
        $dat =~ s/\n(?!$)/\n$depth$context->{'indent'}/mg;
        $fh->print("$depth$context->{'indent'}$dat");
        $fh->print("$depth</hints>\n");
    }
    else
    { return Font::TTF::Table::XML_element(@_); }

    $self;    
}


=head2 $g->update

Generates a C<$self->{'DAT'}> from the internal structures, if the data has
been read into structures in the first place. If you are building a glyph
from scratch you will need to set the instance variable C<' read'> to 2 (or
something > 1) for the update to work.

=cut

sub update
{
    my ($self) = @_;
    my ($dat, $loc, $len, $flag, $x, $y, $i, $comp, $num);

    return $self unless (defined $self->{' read'} && $self->{' read'} > 1);
    $self->update_bbox;
    $self->{' DAT'} = TTF_Out_Fields($self, \%fields, 10);
    $num = $self->{'numberOfContours'};
    if ($num > 0)
    {
        $self->{' DAT'} .= pack("n*", @{$self->{'endPoints'}});
        $len = $self->{'instLen'};
        $self->{' DAT'} .= pack("n", $len);
        $self->{' DAT'} .= pack("a" . $len, substr($self->{'hints'}, 0, $len)) if ($len > 0);
        for ($i = 0; $i < $self->{'numPoints'}; $i++)
        {
            $flag = $self->{'flags'}[$i] & 1;
            if ($i == 0)
            {
                $x = $self->{'x'}[$i];
                $y = $self->{'y'}[$i];
            } else
            {
                $x = $self->{'x'}[$i] - $self->{'x'}[$i - 1];
                $y = $self->{'y'}[$i] - $self->{'y'}[$i - 1];
            }
            $flag |= 16 if ($x == 0);
            $flag |= 32 if ($y == 0);
            if (($flag & 16) == 0 && $x < 256 && $x > -256)
            {
                $flag |= 2;
                $flag |= 16 if ($x >= 0);
            }
            if (($flag & 32) == 0 && $y < 256 && $y > -256)
            {
                $flag |= 4;
                $flag |= 32 if ($y >= 0);
            }
            $self->{' DAT'} .= pack("C", $flag);                    # sorry no repeats
            $self->{'flags'}[$i] = $flag;
        }
        for ($i = 0; $i < $self->{'numPoints'}; $i++)
        {
            $flag = $self->{'flags'}[$i];
            $x = $self->{'x'}[$i] - (($i == 0) ? 0 : $self->{'x'}[$i - 1]);
            if (($flag & 18) == 0)
            { $self->{' DAT'} .= TTF_Pack("s", $x); }
            elsif (($flag & 18) == 18)
            { $self->{' DAT'} .= pack("C", $x); }
            elsif (($flag & 18) == 2)
            { $self->{' DAT'} .= pack("C", -$x); }
        }
        for ($i = 0; $i < $self->{'numPoints'}; $i++)
        {
            $flag = $self->{'flags'}[$i];
            $y = $self->{'y'}[$i] - (($i == 0) ? 0 : $self->{'y'}[$i - 1]);
            if (($flag & 36) == 0)
            { $self->{' DAT'} .= TTF_Pack("s", $y); }
            elsif (($flag & 36) == 36)
            { $self->{' DAT'} .= pack("C", $y); }
            elsif (($flag & 36) == 4)
            { $self->{' DAT'} .= pack("C", -$y); }
        }
    }

    elsif ($num < 0)
    {
        for ($i = 0; $i <= $#{$self->{'comps'}}; $i++)
        {
            $comp = $self->{'comps'}[$i];
            $flag = $comp->{'flag'} & 7158;        # bits 2,10,11,12
            $flag |= 1 unless ($comp->{'args'}[0] > -129 && $comp->{'args'}[0] < 128
                    && $comp->{'args'}[1] > -129 && $comp->{'args'}[1] < 128);
            if (defined $comp->{'scale'})
            {
                if ($comp->{'scale'}[1] == 0 && $comp->{'scale'}[2] == 0)
                {
                    if ($comp->{'scale'}[0] == $comp->{'scale'}[3])
                    { $flag |= 8 unless ($comp->{'scale'}[0] == 0
                                    || $comp->{'scale'}[0] == 1); }
                    else
                    { $flag |= 64; }
                } else
                { $flag |= 128; }
            }
            
            $flag |= 512 if (defined $self->{'metric'} && $self->{'metric'} == $i);
            if ($i == $#{$self->{'comps'}})
            { $flag |= 256 if (defined $self->{'instLen'} && $self->{'instLen'} > 0); }
            else
            { $flag |= 32; }
            
            $self->{' DAT'} .= pack("n", $flag);
            $self->{' DAT'} .= pack("n", $comp->{'glyph'});
            $comp->{'flag'} = $flag;

            if ($flag & 1)
            { $self->{' DAT'} .= TTF_Pack("s2", @{$comp->{'args'}}); }
            else
            { $self->{' DAT'} .= pack("CC", @{$comp->{'args'}}); }

            if ($flag & 8)
            { $self->{' DAT'} .= TTF_Pack("F", $comp->{'scale'}[0]); }
            elsif ($flag & 64)
            { $self->{' DAT'} .= TTF_Pack("F2", $comp->{'scale'}[0], $comp->{'scale'}[3]); }
            elsif ($flag & 128)
            { $self->{' DAT'} .= TTF_Pack("F4", @{$comp->{'scale'}}); }
        }
        if (defined $self->{'instLen'} && $self->{'instLen'} > 0)
        {
            $len = $self->{'instLen'};
            $self->{' DAT'} .= pack("n", $len);
            $self->{' DAT'} .= pack("a" . $len, substr($self->{'hints'}, 0, $len));
        }
    }
    my ($olen) = length($self->{' DAT'});
    $self->{' DAT'} .= ("\000") x (4 - ($olen & 3)) if ($olen & 3);
    $self->{' OUTLEN'} = length($self->{' DAT'});
    $self->{' read'} = 2;           # changed from 1 to 2 so we don't read_dat() again
# we leave numPoints and instLen since maxp stats use this
    $self;
}


=head2 $g->update_bbox

Updates the bounding box for this glyph according to the points in the glyph

=cut

sub update_bbox
{
    my ($self) = @_;
    my ($num, $maxx, $minx, $maxy, $miny, $i, $comp, $x, $y, $compg);

    return $self unless $self->{' read'} > 1;       # only if read_dat done
    $miny = $minx = 65537; $maxx = $maxy = -65537;
    $num = $self->{'numberOfContours'};
    if ($num > 0)
    {
        for ($i = 0; $i < $self->{'numPoints'}; $i++)
        {
            ($x, $y) = ($self->{'x'}[$i], $self->{'y'}[$i]);

            $maxx = $x if ($x > $maxx);
            $minx = $x if ($x < $minx);
            $maxy = $y if ($y > $maxy);
            $miny = $y if ($y < $miny);
        }
    }

    elsif ($num < 0)
    {
        foreach $comp (@{$self->{'comps'}})
        {
            my ($gnx, $gny, $gxx, $gxy);
            my ($sxx, $sxy, $syx, $syy);
            
            my $otherg = $self->{' PARENT'}{'loca'}{'glyphs'}[$comp->{'glyph'}];
            # work around bad fonts: see documentation for 'comps' above
            next unless (defined $otherg);
            $compg = $otherg->read->update_bbox;
            ($gnx, $gny, $gxx, $gxy) = @{$compg}{'xMin', 'yMin', 'xMax', 'yMax'};
            if (defined $comp->{'scale'})
            {
                ($sxx, $sxy, $syx, $syy) = @{$comp->{'scale'}};
                ($gnx, $gny, $gxx, $gxy) = ($gnx*$sxx+$gny*$syx + $comp->{'args'}[0],
                                            $gnx*$sxy+$gny*$syy + $comp->{'args'}[1],
                                            $gxx*$sxx+$gxy*$syx + $comp->{'args'}[0],
                                            $gxx*$sxy+$gxy*$syy + $comp->{'args'}[1]);
            } elsif ($comp->{'args'}[0] || $comp->{'args'}[1])
            {
                $gnx += $comp->{'args'}[0];
                $gny += $comp->{'args'}[1];
                $gxx += $comp->{'args'}[0];
                $gxy += $comp->{'args'}[1];
            }
            ($gnx, $gxx) = ($gxx, $gnx) if $gnx > $gxx;
            ($gny, $gxy) = ($gxy, $gny) if $gny > $gxy;
            $maxx = $gxx if $gxx > $maxx;
            $minx = $gnx if $gnx < $minx;
            $maxy = $gxy if $gxy > $maxy;
            $miny = $gny if $gny < $miny;
        }
    }
    $self->{'xMax'} = $maxx;
    $self->{'xMin'} = $minx;
    $self->{'yMax'} = $maxy;
    $self->{'yMin'} = $miny;
    $self;
}

            
=head2 $g->maxInfo

Returns lots of information about a glyph so that the C<maxp> table can update
itself. Returns array containing contributions of this glyph to maxPoints, maxContours, 
maxCompositePoints, maxCompositeContours, maxSizeOfInstructions, maxComponentElements, 
and maxComponentDepth.

=cut

sub maxInfo
{
    my ($self) = @_;
    my (@res, $i, @n);

    $self->read_dat;            # make sure we've read some data
    $res[4] = length($self->{'hints'}) if defined $self->{'hints'};
    $res[6] = 1;
    if ($self->{'numberOfContours'} > 0)
    {
        $res[0] = $self->{'numPoints'};
        $res[1] = $self->{'numberOfContours'};
    } elsif ($self->{'numberOfContours'} < 0)
    {
        for ($i = 0; $i <= $#{$self->{'comps'}}; $i++)
        {
            my $otherg = 
                $self->{' PARENT'}{'loca'}{'glyphs'}
                    [$self->{'comps'}[$i]{'glyph'}];
            
            # work around bad fonts: see documentation for 'comps' above
            next unless (defined $otherg );
            
            @n = $otherg->maxInfo;

            $res[2] += $n[2] == 0 ? $n[0] : $n[2];
            $res[3] += $n[3] == 0 ? $n[1] : $n[3];
            $res[5]++;
            $res[6] = $n[6] + 1 if ($n[6] >= $res[6]);
        }
    }
    @res;
}

=head2 $g->empty

Empties the glyph of all information to the level of not having been read.
Useful for saving memory in apps with many glyphs being read

=cut

sub empty
{
    my ($self) = @_;
    my (%keep) = map {(" $_" => 1)} ('LOC', 'OUTLOC', 'PARENT', 'INFILE', 'BASE',
                                'OUTLEN', 'LEN');
    map {delete $self->{$_} unless $keep{$_}} keys %$self;
    
    $self;
}


=head2 $g->get_points

This method creates point information for a compound glyph. The information is
stored in the same place as if the glyph was not a compound, but since
numberOfContours is negative, the glyph is still marked as being a compound

=cut

sub get_points
{
    my ($self) = @_;
    my ($comp, $compg, $nump, $e, $i);

    $self->read_dat;
    return undef unless ($self->{'numberOfContours'} < 0);

    foreach $comp (@{$self->{'comps'}})
    {
        $compg = $self->{' PARENT'}{'loca'}{'glyphs'}[$comp->{'glyph'}];
        # work around bad fonts: see documentation for 'comps' above
        next unless (defined $compg );
        $compg->get_points;

        for ($i = 0; $i < $compg->{'numPoints'}; $i++)
        {
            my ($x, $y) = ($compg->{'x'}[$i], $compg->{'y'}[$i]);
            if (defined $comp->{'scale'})
            {
                ($x, $y) = ($x * $comp->{'scale'}[0] + $y * $comp->{'scale'}[2],
                            $x * $comp->{'scale'}[1] + $y * $comp->{'scale'}[3]);
            }
            if (defined $comp->{'args'})
            { ($x, $y) = ($x + $comp->{'args'}[0], $y + $comp->{'args'}[1]); }
            push (@{$self->{'x'}}, $x);
            push (@{$self->{'y'}}, $y);
            push (@{$self->{'flags'}}, $compg->{'flags'}[$i]);
        }
        foreach $e (@{$compg->{'endPoints'}})
        { push (@{$self->{'endPoints'}}, $e + $nump); }
        $nump += $compg->{'numPoints'};
    }
    $self->{'numPoints'} = $nump;
    $self;
}


=head2 $g->get_refs

Returns an array of all the glyph ids that are used to make up this glyph. That
is all the compounds and their references and so on. If this glyph is not a
compound, then returns an empty array.

Please note the warning about bad fonts that reference nonexistant glyphs
under INSTANCE VARIABLES above.  This function will not attempt to 
filter out nonexistant glyph numbers.

=cut

sub get_refs
{
    my ($self) = @_;
    my (@res, $g);

    $self->read_dat;
    return unless ($self->{'numberOfContours'} < 0);
    foreach $g (@{$self->{'comps'}})
    {
        push (@res, $g->{'glyph'});
        my $otherg = $self->{' PARENT'}{'loca'}{'glyphs'}[$g->{'glyph'}];
        # work around bad fonts: see documentation for 'comps' above
        next unless (defined $otherg);
        my @list = $otherg->get_refs;
        push(@res, @list);
    }
    return @res;
}

1;

=head1 BUGS

=over 4

=item *

The instance variables used here are somewhat clunky and inconsistent with
the other tables.

=item *

C<update> doesn't re-calculate the bounding box or C<numberOfContours>.

=back

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut
