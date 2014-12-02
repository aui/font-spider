package Font::TTF::Utils;

=head1 NAME

Font::TTF::Utils - Utility functions to save fingers

=head1 DESCRIPTION

Lots of useful functions to save my fingers, especially for trivial tables

=head1 FUNCTIONS

The following functions are exported

=cut

use strict;
use vars qw(@ISA @EXPORT $VERSION @EXPORT_OK);
require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(TTF_Init_Fields TTF_Read_Fields TTF_Out_Fields TTF_Pack
             TTF_Unpack TTF_word_utf8 TTF_utf8_word TTF_bininfo);
@EXPORT_OK = (@EXPORT, qw(XML_hexdump));
$VERSION = 0.0001;

=head2 ($val, $pos) = TTF_Init_Fields ($str, $pos)

Given a field description from the C<DATA> section, creates an absolute entry
in the fields associative array for the class

=cut

sub TTF_Init_Fields
{
    my ($str, $pos, $inval) = @_;
    my ($key, $val, $res, $len, $rel);

    $str =~ s/\r?\n$//o;
    if ($inval)
    { ($key, $val) = ($str, $inval); }
    else
    { ($key, $val) = split(',\s*', $str); }
    return (undef, undef, 0) unless (defined $key && $key ne "");
    if ($val =~ m/^(\+?)(\d*)(\D+)(\d*)/oi)
    {
        $rel = $1;
        if ($rel eq "+")
        { $pos += $2; }
        elsif ($2 ne "")
        { $pos = $2; }
        $val = $3;
        $len = $4;
    }
    $len = "" unless defined $len;
    $pos = 0 if !defined $pos || $pos eq "";
    $res = "$pos:$val:$len";
    if ($val eq "f" || $val eq 'v' || $val =~ m/^[l]/oi)
    { $pos += 4 * ($len ne "" ? $len : 1); }
    elsif ($val eq "F" || $val =~ m/^[s]/oi)
    { $pos += 2 * ($len ne "" ? $len : 1); }
    else
    { $pos += 1 * ($len ne "" ? $len : 1); }

    ($key, $res, $pos);
}


=head2 TTF_Read_Fields($obj, $dat, $fields)

Given a block of data large enough to account for all the fields in a table,
processes the data block to convert to the values in the objects instance
variables by name based on the list in the C<DATA> block which has been run
through C<TTF_Init_Fields>

=cut

sub TTF_Read_Fields
{
    my ($self, $dat, $fields) = @_;
    my ($pos, $type, $res, $f, $arrlen, $arr, $frac);

    foreach $f (keys %{$fields})
    {
        ($pos, $type, $arrlen) = split(':', $fields->{$f});
        $pos = 0 if $pos eq "";
        if ($arrlen ne "")
        { $self->{$f} = [TTF_Unpack("$type$arrlen", substr($dat, $pos))]; }
        else
        { $self->{$f} = TTF_Unpack("$type", substr($dat, $pos)); }
    }
    $self;
}


=head2 TTF_Unpack($fmt, $dat)

A TrueType types equivalent of Perls C<unpack> function. Thus $fmt consists of
type followed by an optional number of elements to read including *. The type
may be one of:

    c       BYTE
    C       CHAR
    f       FIXED
    F       F2DOT14
    l       LONG
    L       ULONG
    s       SHORT
    S       USHORT
    v       Version number (FIXED)

Note that C<FUNIT>, C<FWORD> and C<UFWORD> are not data types but units.

Returns array of scalar (first element) depending on context

=cut

sub TTF_Unpack
{
    my ($fmt, $dat) = @_;
    my ($res, $frac, $i, $arrlen, $type, @res);

    while ($fmt =~ s/^([cflsv])(\d+|\*)?//oi)
    {
        $type = $1;
        $arrlen = $2;
        $arrlen = 1 if !defined $arrlen || $arrlen eq "";
        $arrlen = -1 if $arrlen eq "*";

        for ($i = 0; ($arrlen == -1 && $dat ne "") || $i < $arrlen; $i++)
        {
            if ($type eq "f")
            {
                ($res, $frac) = unpack("nn", $dat);
                substr($dat, 0, 4) = "";
                $res -= 65536 if $res > 32767;
                $res += $frac / 65536.;
            }
            elsif ($type eq "v")
            {
                ($res, $frac) = unpack("nn", $dat);
                substr($dat, 0, 4) = "";
                $res -= 65536 if $res > 32767;
                $res = sprintf("%d.%X", $res, $frac);
            }
            elsif ($type eq "F")
            {
                $res = unpack("n", $dat);
                substr($dat, 0, 2) = "";
#                $res -= 65536 if $res >= 32768;
                $frac = $res & 0x3fff;
                $res >>= 14;
                $res -= 4 if $res > 1;
#                $frac -= 16384 if $frac > 8191;
                $res += $frac / 16384.;
            }
            elsif ($type =~ m/^[l]/oi)
            {
                $res = unpack("N", $dat);
                substr($dat, 0, 4) = "";
                $res -= (1 << 32) if ($type eq "l" && $res >= 1 << 31);
            }
            elsif ($type =~ m/^[s]/oi)
            {
                $res = unpack("n", $dat);
                substr($dat, 0, 2) = "";
                $res -= 65536 if ($type eq "s" && $res >= 32768);
            }
            elsif ($type eq "c")
            {
                $res = unpack("c", $dat);
                substr($dat, 0, 1) = "";
            }
            else
            {
                $res = unpack("C", $dat);
                substr($dat, 0, 1) = "";
            }
            push (@res, $res);
        }
    }
    return wantarray ? @res : $res[0];
}


=head2 $dat = TTF_Out_Fields($obj, $fields, $len)

Given the fields table from C<TTF_Init_Fields> writes out the instance variables from
the object to the filehandle in TTF binary form.

=cut

sub TTF_Out_Fields
{
    my ($obj, $fields, $len) = @_;
    my ($dat) = "\000" x $len;
    my ($f, $pos, $type, $res, $arr, $arrlen, $frac);
    
    foreach $f (keys %{$fields})
    {
        ($pos, $type, $arrlen) = split(':', $fields->{$f});
        if ($arrlen ne "")
        { $res = TTF_Pack("$type$arrlen", @{$obj->{$f}}); }
        else
        { $res = TTF_Pack("$type", $obj->{$f}); }
        substr($dat, $pos, length($res)) = $res;
    }
    $dat;
}


=head2 $dat = TTF_Pack($fmt, @data)

The TrueType equivalent to Perl's C<pack> function. See details of C<TTF_Unpack>
for how to work the $fmt string.

=cut

sub TTF_Pack
{
    my ($fmt, @obj) = @_;
    my ($type, $i, $arrlen, $dat, $res, $frac);

    $dat = '';
    while ($fmt =~ s/^([flscv])(\d+|\*)?//oi)
    {
        $type = $1;
        $arrlen = $2 || "";
        $arrlen = $#obj + 1 if $arrlen eq "*";
        $arrlen = 1 if $arrlen eq "";
    
        for ($i = 0; $i < $arrlen; $i++)
        {
            $res = shift(@obj) || 0;
            if ($type eq "f")
            {
                $frac = int(($res - int($res)) * 65536);
                $res = (int($res) << 16) + $frac;
                $dat .= pack("N", $res);
            }
            elsif ($type eq "v")
            {
                if ($res =~ s/\.(\d+)$//o)
                {
                    $frac = $1;
                    $frac .= "0" x (4 - length($frac));
                }
                else
                { $frac = 0; }
                $dat .= pack('nn', $res, eval("0x$frac"));
            }
            elsif ($type eq "F")
            {
                $frac = int(($res - int($res)) * 16384);
                $res = (int($res) << 14) + $frac;
                $dat .= pack("n", $res);
            }
            elsif ($type =~ m/^[l]/oi)
            {
                $res += 1 << 32 if ($type eq 'L' && $res < 0);
                $dat .= pack("N", $res);
            }
            elsif ($type =~ m/^[s]/oi)
            {
                $res += 1 << 16 if ($type eq 'S' && $res < 0);
                $dat .= pack("n", $res);
            }
            elsif ($type eq "c")
            { $dat .= pack("c", $res); }
            else
            { $dat .= pack("C", $res); }
        }
    }
    $dat;
}


=head2 ($num, $range, $select, $shift) = TTF_bininfo($num)

Calculates binary search information from a number of elements

=cut

sub TTF_bininfo
{
    my ($num, $block) = @_;
    my ($range, $select, $shift);

    $range = 1;
    for ($select = 0; $range <= $num; $select++)
    { $range *= 2; }
    $select--; $range /= 2;
    $range *= $block;

    $shift = $num * $block - $range;
    ($num, $range, $select, $shift);
}


=head2 TTF_word_utf8($str)

Returns the UTF8 form of the 16 bit string, assumed to be in big endian order,
including surrogate handling

=cut

sub TTF_word_utf8
{
    my ($str) = @_;
    my ($res, $i);
    my (@dat) = unpack("n*", $str);

    return pack("U*", @dat) if ($] >= 5.006);
    for ($i = 0; $i <= $#dat; $i++)
    {
        my ($dat) = $dat[$i];
        if ($dat < 0x80)        # Thanks to Gisle Aas for some of his old code
        { $res .= chr($dat); }
        elsif ($dat < 0x800)
        { $res .= chr(0xC0 | ($dat >> 6)) . chr(0x80 | ($dat & 0x3F)); }
        elsif ($dat >= 0xD800 && $dat < 0xDC00)
        {
            my ($dat1) = $dat[++$i];
            my ($top) = (($dat & 0x3C0) >> 6) + 1;
            $res .= chr(0xF0 | ($top >> 2))
                  . chr(0x80 | (($top & 1) << 4) | (($dat & 0x3C) >> 2))
                  . chr(0x80 | (($dat & 0x3) << 4) | (($dat1 & 0x3C0) >> 6))
                  . chr(0x80 | ($dat1 & 0x3F));
        } else
        { $res .= chr(0xE0 | ($dat >> 12)) . chr(0x80 | (($dat >> 6) & 0x3F))
                . chr(0x80 | ($dat & 0x3F)); }
    }
    $res;
}


=head2 TTF_utf8_word($str)

Returns the 16-bit form in big endian order of the UTF 8 string, including
surrogate handling to Unicode.

=cut

sub TTF_utf8_word
{
    my ($str) = @_;
    my ($res);

    return pack("n*", unpack("U*", $str)) if ($^V ge v5.6.0);
    $str = "$str";              # copy $str
    while (length($str))        # Thanks to Gisle Aas for some of his old code
    {
        $str =~ s/^[\x80-\xBF]+//o;
        if ($str =~ s/^([\x00-\x7F]+)//o)
        { $res .= pack("n*", unpack("C*", $1)); }
        elsif ($str =~ s/^([\xC0-\xDF])([\x80-\xBF])//o)
        { $res .= pack("n", ((ord($1) & 0x1F) << 6) | (ord($2) & 0x3F)); }
        elsif ($str =~ s/^([\0xE0-\xEF])([\x80-\xBF])([\x80-\xBF])//o)
        { $res .= pack("n", ((ord($1) & 0x0F) << 12)
                          | ((ord($2) & 0x3F) << 6)
                          | (ord($3) & 0x3F)); }
        elsif ($str =~ s/^([\xF0-\xF7])([\x80-\xBF])([\x80-\xBF])([\x80-\xBF])//o)
        {
            my ($b1, $b2, $b3, $b4) = (ord($1), ord($2), ord($3), ord($4));
            $res .= pack("n", ((($b1 & 0x07) << 8) | (($b2 & 0x3F) << 2)
                            | (($b3 & 0x30) >> 4)) + 0xD600);  # account for offset
            $res .= pack("n", ((($b3 & 0x0F) << 6) | ($b4 & 0x3F)) + 0xDC00);
        }
        elsif ($str =~ s/^[\xF8-\xFF][\x80-\xBF]*//o)
        { }
    }
    $res;
}


=head2 XML_hexdump($context, $dat)

Dumps out the given data as a sequence of <data> blocks each 16 bytes wide

=cut

sub XML_hexdump
{
    my ($context, $depth, $dat) = @_;
    my ($fh) = $context->{'fh'};
    my ($i, $len, $out);

    $len = length($dat);
    for ($i = 0; $i < $len; $i += 16)
    {
        $out = join(' ', map {sprintf("%02X", ord($_))} (split('', substr($dat, $i, 16))));
        $fh->printf("%s<data addr='%04X'>%s</data>\n", $depth, $i, $out);
    }
}


=head2 XML_outhints

Converts a binary string of hinting code into a textual representation

=cut

{
    my (@hints) = (
    ['SVTCA[0]'], ['SVTCA[1]'], ['SPVTCA[0]'], ['SPVTCA[1]'], ['SFVTCA[0]'], ['SFVTCA[1]'], ['SPVTL[0]'], ['SPVTL[1]'],
    ['SFVTL[0]'], ['SFVTL[1]'], ['SPVFS'], ['SFVFS'], ['GPV'], ['GFV'], ['SVFTPV'], ['ISECT'],
# 10
    ['SRP0'], ['SRP1'], ['SRP2'], ['SZP0'], ['SZP1'], ['SZP2'], ['SZPS'], ['SLOOP'],
    ['RTG'], ['RTHG'], ['SMD'], ['ELSE'], ['JMPR'], ['SCVTCI'], ['SSWCI'], ['SSW'],
# 20
    ['DUP'], ['POP'], ['CLEAR'], ['SWAP'], ['DEPTH'], ['CINDEX'], ['MINDEX'], ['ALIGNPTS'],
    [], ['UTP'], ['LOOPCALL'], ['CALL'], ['FDEF'], ['ENDF'], ['MDAP[0]'], ['MDAP[1]'],
# 30
    ['IUP[0]'], ['IUP[1]'], ['SHP[0]'], ['SHP[1]'], ['SHC[0]'], ['SHC[1]'], ['SHZ[0]'], ['SHZ[1]'],
    ['SHPIX'], ['IP'], ['MSIRP[0]'], ['MSIRP[1]'], ['ALIGNRP'], ['RTDG'], ['MIAP[0]'], ['MIAP[1]'],
# 40
    ['NPUSHB', -1, 1], ['NPUSHW', -1, 2], ['WS', 0, 0], ['RS', 0, 0], ['WCVTP', 0, 0], ['RCVT', 0, 0], ['GC[0]'], ['GC[1]'],
    ['SCFS'], ['MD[0]'], ['MD[1]'], ['MPPEM'], ['MPS'], ['FLIPON'], ['FLIPOFF'], ['DEBUG'],
# 50
    ['LT'], ['LTEQ'], ['GT'], ['GTEQ'], ['EQ'], ['NEQ'], ['ODD'], ['EVEN'],
    ['IF'], ['EIF'], ['AND'], ['OR'], ['NOT'], ['DELTAP1'], ['SDB'], ['SDS'],
# 60
    ['ADD'], ['SUB'], ['DIV'], ['MULT'], ['ABS'], ['NEG'], ['FLOOR'], ['CEILING'],
    ['ROUND[0]'], ['ROUND[1]'], ['ROUND[2]'], ['ROUND[3]'], ['NROUND[0]'], ['NROUND[1]'], ['NROUND[2]'], ['NROUND[3]'],
# 70
    ['WCVTF'], ['DELTAP2'], ['DELTAP3'], ['DELTAC1'], ['DELTAC2'], ['DELTAC3'], ['SROUND'], ['S45ROUND'],
    ['JROT'], ['JROF'], ['ROFF'], [], ['RUTG'], ['RDTG'], ['SANGW'], [],
# 80
    ['FLIPPT'], ['FLIPRGON'], ['FLIPRGOFF'], [], [], ['SCANCTRL'], ['SDPVTL[0]'], ['SDPVTL[1]'],
    ['GETINFO'], ['IDEF'], ['ROLL'], ['MAX'], ['MIN'], ['SCANTYPE'], ['INSTCTRL'], [],
# 90
    [], [], [], [], [], [], [], [], [], [], [], [], [], [], [], [],
# A0
    [], [], [], [], [], [], [], [], [], [], [], [], [], [], [], [],
# B0
    ['PUSHB1', 1, 1], ['PUSHB2', 2, 1], ['PUSHB3', 3, 1], ['PUSHB4', 4, 1], ['PUSHB5', 5, 1], ['PUSHB6', 6, 1], ['PUSHB7', 7, 1], ['PUSHB8', 8, 1],
    ['PUSHW1', 1, 2], ['PUSHW2', 2, 2], ['PUSHW3', 3, 2], ['PUSHW4', 4, 2], ['PUSHW5', 5, 2], ['PUSHW6', 6, 2], ['PUSHW7', 7, 2], ['PUSHW8', 8, 2],
# C0
    ['MDRP[0]'], ['MDRP[1]'], ['MDRP[2]'], ['MDRP[3]'], ['MDRP[4]'], ['MDRP[5]'], ['MDRP[6]'], ['MDRP[7]'],
    ['MDRP[8]'], ['MDRP[9]'], ['MDRP[A]'], ['MDRP[B]'], ['MDRP[C]'], ['MDRP[D]'], ['MDRP[E]'], ['MDRP[F]'],
# D0
    ['MDRP[10]'], ['MDRP[11]'], ['MDRP[12]'], ['MDRP[13]'], ['MDRP[14]'], ['MDRP[15]'], ['MDRP[16]'], ['MDRP[17]'],
    ['MDRP[18]'], ['MDRP[19]'], ['MDRP[1A]'], ['MDRP[1B]'], ['MDRP[1C]'], ['MDRP[1D]'], ['MDRP[1E]'], ['MDRP[1F]'],
# E0
    ['MIRP[0]'], ['MIRP[1]'], ['MIRP[2]'], ['MIRP[3]'], ['MIRP[4]'], ['MIRP[5]'], ['MIRP[6]'], ['MIRP[7]'],
    ['MIRP[8]'], ['MIRP[9]'], ['MIRP[A]'], ['MIRP[B]'], ['MIRP[C]'], ['MIRP[D]'], ['MIRP[E]'], ['MIRP[F]'],
# F0
    ['MIRP[10]'], ['MIRP[11]'], ['MIRP[12]'], ['MIRP[13]'], ['MIRP[14]'], ['MIRP[15]'], ['MIRP[16]'], ['MIRP[17]'],
    ['MIRP[18]'], ['MIRP[19]'], ['MIRP[1A]'], ['MIRP[1B]'], ['MIRP[1C]'], ['MIRP[1D]'], ['MIRP[1E]'], ['MIRP[1F]']);

    my ($i);
    my (%hints) = map { $_->[0] => $i++ if (defined $_->[0]); } @hints;

    sub XML_binhint
    {
        my ($dat) = @_;
        my ($len) = length($dat);
        my ($res, $i, $text, $size, $num);

        for ($i = 0; $i < $len; $i++)
        {
            ($text, $num, $size) = @{$hints[ord(substr($dat, $i, 1))]};
            $num = 0 unless (defined $num);
            $text = sprintf("UNK[%02X]", ord(substr($dat, $i, 1))) unless defined $text;
            $res .= $text;
            if ($num != 0)
            {
                if ($num < 0)
                {
                    $i++;
                    my ($nnum) = unpack($num == -1 ? 'C' : 'n', substr($dat, $i, -$num));
                    $i += -$num - 1;
                    $num = $nnum;
                }
                $res .= "\t" . join(' ', unpack($size == 1 ? 'C*' : 'n*', substr($dat, $i + 1, $num * $size)));
                $i += $num * $size;
            }
            $res .= "\n";
        }
        $res;
    }

    sub XML_hintbin
    {
        my ($dat) = @_;
        my ($l, $res, @words, $num);

        foreach $l (split(/\s*\n\s*/, $dat))
        {
            @words = split(/\s*/, $l);
            next unless (defined $hints{$words[0]});
            $num = $hints{$words[0]};
            $res .= pack('C', $num);
            if ($hints[$num][1] < 0)
            {
                $res .= pack($hints[$num][1] == -1 ? 'C' : 'n', $#words);
                $res .= pack($hints[$num][2] == 1 ? 'C*' : 'n*', @words[1 .. $#words]);
            }
            elsif ($hints[$num][1] > 0)
            {
                $res .= pack($hints[$num][2] == 1 ? 'C*' : 'n*', @words[1 .. $hints[$num][1]]);
            }
        }
        $res;
    }
}


=head2 make_circle($f, $cmap, [$dia, $sb, $opts])

Adds a dotted circle to a font. This function is very configurable. The
parameters passed in are:

=over 4

=item $f

Font to work with. This is required.

=item $cmap

A cmap table (not the 'val' sub-element of a cmap) to add the glyph too. Optional.

=item $dia

Optional diameter for the main circle. Defaults to 80% em

=item $sb

Side bearing. The left and right side-bearings are always the same. This value
defaults to 10% em.

=back

There are various options to control all sorts of interesting aspects of the circle

=over 4

=item numDots

Number of dots in the circle

=item numPoints

Number of curve points to use to create each dot

=item uid

Unicode reference to store this glyph under in the cmap. Defaults to 0x25CC

=item pname

Postscript name to give the glyph. Defaults to uni25CC.

=item -dRadius

Radius of each dot.

=back

=cut

sub make_circle
{
    my ($font, $cmap, $dia, $sb, %opts) = @_;
    my ($upem) = $font->{'head'}{'unitsPerEm'};
    my ($glyph) = Font::TTF::Glyph->new('PARENT' => $font, 'read' => 2);
    my ($PI) = 3.1415926535;
    my ($R, $r, $xorg, $yorg);
    my ($i, $j, $numg, $maxp);
    my ($numc) = $opts{'-numDots'} || 16;
    my ($nump) = ($opts{'-numPoints'} * 2) || 8;
    my ($uid) = $opts{'-uid'} || 0x25CC;
    my ($pname) = $opts{'-pname'} || 'uni25CC';

    $dia ||= $upem * .8;    # .95 to fit exactly
    $sb ||= $upem * .1;
    $R = $dia / 2;
    $r = $opts{'-dRadius'} || ($R * .1);
    ($xorg, $yorg) = ($R + $r, $R);

    $xorg += $sb;
    $font->{'post'}->read;
    $font->{'glyf'}->read;
    for ($i = 0; $i < $numc; $i++)
    {
        my ($pxorg, $pyorg) = ($xorg + $R * cos(2 * $PI * $i / $numc),
                                    $yorg + $R * sin(2 * $PI * $i / $numc));
        for ($j = 0; $j < $nump; $j++)
        {
            push (@{$glyph->{'x'}}, int ($pxorg + ($j & 1 ? 1/cos(2*$PI/$nump) : 1) * $r * cos(2 * $PI * $j / $nump)));
            push (@{$glyph->{'y'}}, int ($pyorg + ($j & 1 ? 1/cos(2*$PI/$nump) : 1) * $r * sin(2 * $PI * $j / $nump)));
            push (@{$glyph->{'flags'}}, $j & 1 ? 0 : 1);
        }
        push (@{$glyph->{'endPoints'}}, $#{$glyph->{'x'}});
    }
    $glyph->{'numberOfContours'} = $#{$glyph->{'endPoints'}} + 1;
    $glyph->{'numPoints'} = $#{$glyph->{'x'}} + 1;
    $glyph->update;
    $numg = $font->{'maxp'}{'numGlyphs'};
    $font->{'maxp'}{'numGlyphs'}++;

    $font->{'hmtx'}{'advance'}[$numg] = int($xorg + $R + $r + $sb + .5);
    $font->{'hmtx'}{'lsb'}[$numg] = int($xorg - $R - $r + .5);
    $font->{'loca'}{'glyphs'}[$numg] = $glyph;
    $cmap->{'val'}{$uid} = $numg if ($cmap);
    $font->{'post'}{'VAL'}[$numg] = $pname;
    delete $font->{'hdmx'};
    delete $font->{'VDMX'};
    delete $font->{'LTSH'};
    
    $font->tables_do(sub {$_[0]->dirty;});
    $font->update;
    return ($numg - 1);
}


1;

=head1 BUGS

No known bugs

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

