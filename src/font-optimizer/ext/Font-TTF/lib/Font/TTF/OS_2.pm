package Font::TTF::OS_2;

=head1 NAME

Font::TTF::OS_2 - the OS/2 table in a TTF font

=head1 DESCRIPTION

The OS/2 table has two versions and forms, one an extension of the other. This
module supports both forms and the switching between them.

=head1 INSTANCE VARIABLES

No other variables than those in table and those in the standard:

    Version
    xAvgCharWidth
    usWeightClass
    usWidthClass
    fsType
    ySubscriptXSize
    ySubScriptYSize
    ySubscriptXOffset
    ySubscriptYOffset
    ySuperscriptXSize
    ySuperscriptYSize
    ySuperscriptXOffset
    ySuperscriptYOffset
    yStrikeoutSize
    yStrikeoutPosition
    sFamilyClass
    bFamilyType
    bSerifStyle
    bWeight
    bProportion
    bContrast
    bStrokeVariation
    bArmStyle
    bLetterform
    bMidline
    bXheight
    ulUnicodeRange1
    ulUnicodeRange2
    ulUnicodeRange3
    ulUnicodeRange4
    achVendID
    fsSelection
    usFirstCharIndex
    usLastCharIndex
    sTypoAscender
    sTypoDescender
    sTypoLineGap
    usWinAscent
    usWinDescent
    ulCodePageRange1
    ulCodePageRange2
    xHeight
    CapHeight
    defaultChar
    breakChar
    maxLookups

Notice that versions 0, 1, 2 & 3 of the table are supported. Notice also that the
Panose variable has been broken down into its elements.

=head1 METHODS

=cut

use strict;
use vars qw(@ISA @fields @lens @field_info @weights);
use Font::TTF::Table;

@ISA = qw(Font::TTF::Table);
@field_info = (
    'xAvgCharWidth' => 's',
    'usWeightClass' => 'S',
    'usWidthClass' => 'S',
    'fsType' => 's',
    'ySubscriptXSize' => 's',
    'ySubScriptYSize' => 's',
    'ySubscriptXOffset' => 's',
    'ySubscriptYOffset' => 's',
    'ySuperscriptXSize' => 's',
    'ySuperscriptYSize' => 's',
    'ySuperscriptXOffset' => 's',
    'ySuperscriptYOffset' => 's',
    'yStrikeoutSize' => 's',
    'yStrikeoutPosition' => 's',
    'sFamilyClass' => 's',
    'bFamilyType' => 'C',
    'bSerifStyle' => 'C',
    'bWeight' => 'C',
    'bProportion' => 'C',
    'bContrast' => 'C',
    'bStrokeVariation' => 'C',
    'bArmStyle' => 'C',
    'bLetterform' => 'C',
    'bMidline' => 'C',
    'bXheight' => 'C',
    'ulUnicodeRange1' => 'L',
    'ulUnicodeRange2' => 'L',
    'ulUnicodeRange3' => 'L',
    'ulUnicodeRange4' => 'L',
    'achVendID' => 'L',
    'fsSelection' => 'S',
    'usFirstCharIndex' => 'S',
    'usLastCharIndex' => 'S',
    'sTypoAscender' => 'S',
    'sTypoDescender' => 's',
    'sTypoLineGap' => 'S',
    'usWinAscent' => 'S',
    'usWinDescent' => 'S',
    '' => '',
    'ulCodePageRange1' => 'L',
    'ulCodePageRange2' => 'L',
    '' => '',
    'xHeight' => 's',
    'CapHeight' => 's',
    'defaultChar' => 'S',
    'breakChar' => 'S',
    'maxLookups' => 's',
    '' => '',            # i.e. v3 is basically same as v2
    );

@weights = qw(64 14 27 35 100 20 14 42 63 3 6 35 20 56 56 17 4 49 56 71 31 10 18 3 18 2 166);

use Font::TTF::Utils;

sub init
{
    my ($k, $v, $c, $n, $i, $t, $j);

    $n = 0;
    @lens = (76, 84, 94, 94);
    for ($j = 0; $j < $#field_info; $j += 2)
    {
        if ($field_info[$j] eq '')
        {
            $n++;
            next;
        }
        ($k, $v, $c) = TTF_Init_Fields($field_info[$j], $c, $field_info[$j+1]);
        next unless defined $k && $k ne "";
        for ($i = $n; $i < 4; $i++)
        { $fields[$i]{$k} = $v; }
    }
}


=head2 $t->read

Reads in the various values from disk (see details of OS/2 table)

=cut

sub read
{
    my ($self) = @_;
    my ($dat, $ver);

    $self->SUPER::read or return $self;

    init unless defined $fields[2]{'xAvgCharWidth'};
    $self->{' INFILE'}->read($dat, 2);
    $ver = unpack("n", $dat);
    $self->{'Version'} = $ver;
    if ($ver < 4)
    {
        $self->{' INFILE'}->read($dat, $lens[$ver]);
        TTF_Read_Fields($self, $dat, $fields[$ver]);
    }
    $self;
}


=head2 $t->out($fh)

Writes the table to a file either from memory or by copying.

=cut

sub out
{
    my ($self, $fh) = @_;
    my ($ver);

    return $self->SUPER::out($fh) unless $self->{' read'};

    $ver = $self->{'Version'};
    $fh->print(pack("n", $ver));
    $fh->print(TTF_Out_Fields($self, $fields[$ver], $lens[$ver]));
    $self;
}


=head2 $t->XML_element($context, $depth, $key, $value)

Tidies up the hex values to output them in hex

=cut

sub XML_element
{
    my ($self) = shift;
    my ($context, $depth, $key, $value) = @_;
    my ($fh) = $context->{'fh'};

    if ($key =~ m/^ul(?:Unicode|CodePage)Range\d$/o)
    { $fh->printf("%s<%s>%08X</%s>\n", $depth, $key, $value, $key); }
    elsif ($key eq 'achVendID')
    { $fh->printf("%s<%s name='%s'/>\n", $depth, $key, pack('N', $value)); }
    else
    { return $self->SUPER::XML_element(@_); }
    $self;
}


=head2 $t->XML_end($context, $tag, %attrs)

Now handle them on the way back in

=cut

sub XML_end
{
    my ($self) = shift;
    my ($context, $tag, %attrs) = @_;

    if ($tag =~ m/^ul(?:Unicode|CodePage)Range\d$/o)
    { return hex($context->{'text'}); }
    elsif ($tag eq 'achVendID')
    { return unpack('N', $attrs{'name'}); }
    else
    { return $self->SUPER::XML_end(@_); }
}

=head2 $t->update

Updates the OS/2 table by getting information from other sources:

Updates the C<firstChar> and C<lastChar> values based on the MS table in the
cmap.

Updates the sTypoAscender, sTypoDescender & sTypoLineGap to be the same values
as Ascender, Descender and Linegap from the hhea table (assuming it is dirty)
and also sets usWinAscent to be the sum of Ascender+Linegap and usWinDescent to
be the negative of Descender.

=cut

sub update
{
    my ($self) = @_;
    my ($map, @keys, $table, $i, $avg, $hmtx);

    return undef unless ($self->SUPER::update);

    $self->{' PARENT'}{'cmap'}->update;
    $map = $self->{' PARENT'}{'cmap'}->find_ms || return undef;
    $hmtx = $self->{' PARENT'}{'hmtx'}->read;

    @keys = sort {$a <=> $b} grep {$_ < 0x10000} keys %{$map->{'val'}};

    $self->{'usFirstCharIndex'} = $keys[0];
    $self->{'usLastCharIndex'} = $keys[-1];

    $table = $self->{' PARENT'}{'hhea'}->read;
    
    # try any way we can to get some real numbers passed around!
    if (($self->{'fsSelection'} & 128) != 0)
    {
        # assume the user knows what they are doing and has sensible values already
    }
    elsif ($table->{'Ascender'} != 0 || $table->{'Descender'} != 0)
    {
        $self->{'sTypoAscender'} = $table->{'Ascender'};
        $self->{'sTypoDescender'} = $table->{'Descender'};
        $self->{'sTypoLineGap'} = $table->{'LineGap'};
        $self->{'usWinAscent'} = $self->{'sTypoAscender'} + $self->{'sTypoLineGap'};
        $self->{'usWinDescent'} = -$self->{'sTypoDescender'};
    }
    elsif ($self->{'sTypoAscender'} != 0 || $self->{'sTypoDescender'} != 0)
    {
        $table->{'Ascender'} = $self->{'sTypoAscender'};
        $table->{'Descender'} = $self->{'sTypoDescender'};
        $table->{'LineGap'} = $self->{'sTypoLineGap'};
        $self->{'usWinAscent'} = $self->{'sTypoAscender'} + $self->{'sTypoLineGap'};
        $self->{'usWinDescent'} = -$self->{'sTypoDescender'};
    } 
    elsif ($self->{'usWinAscent'} != 0 || $self->{'usWinDescent'} != 0)
    {
        $self->{'sTypoAscender'} = $table->{'Ascender'} = $self->{'usWinAscent'};
        $self->{'sTypoDescender'} = $table->{'Descender'} = -$self->{'usWinDescent'};
        $self->{'sTypoLineGap'} = $table->{'LineGap'} = 0;
    }

    if ($self->{'Version'} < 3)
    {
        for ($i = 0; $i < 26; $i++)
        { $avg += $hmtx->{'advance'}[$map->{'val'}{$i + 0x0061}] * $weights[$i]; }
        $avg += $hmtx->{'advance'}[$map->{'val'}{0x0020}] * $weights[-1];
        $self->{'xAvgCharWidth'} = $avg / 1000;
    }
    elsif ($self->{'Version'} > 2)
    {
        $i = 0; $avg = 0;
        foreach (@{$hmtx->{'advance'}})
        {
            next unless ($_);
            $i++;
            $avg += $_;
        }
        $avg /= $i if ($i);
        $self->{'xAvgCharWidth'} = $avg;
    }

    foreach $i (keys %{$map->{'val'}})
    {
        if ($i >= 0x10000)
        {
            $self->{'ulUnicodeRange2'} |= 0x2000000;
            last;
        }
    }

    $self->{'Version'} = 1 if (defined $self->{'ulCodePageRange1'} && $self->{'Version'} < 1);
    $self->{'Version'} = 2 if (defined $self->{'maxLookups'} && $self->{'Version'} < 2);
    
    if ((exists $self->{' PARENT'}{'GPOS'} && $self->{' PARENT'}{'GPOS'}{' read'}) ||
        (exists $self->{' PARENT'}{'GSUB'} && $self->{' PARENT'}{'GSUB'}{' read'}))
    {
        # one or both of GPOS & GSUB exist and have been read or modified; so update usMaxContexts
        my ($lp, $ls);
        $lp = $self->{' PARENT'}{'GPOS'}->maxContext if exists $self->{' PARENT'}{'GPOS'};
        $ls = $self->{' PARENT'}{'GSUB'}->maxContext if exists $self->{' PARENT'}{'GSUB'};
        $self->{'maxLookups'} = $lp > $ls ? $lp : $ls;
    }
    
    $self;
}

1;

=head1 BUGS

None known

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut
