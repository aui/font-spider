package Font::TTF::Post;

=head1 NAME

Font::TTF::Post - Holds the Postscript names for each glyph

=head1 DESCRIPTION

Holds the postscript names for glyphs. Note that they are not held as an
array, but as indexes into two lists. The first list is the standard Postscript
name list defined by the TrueType standard. The second comes from the font
directly.

Looking up a glyph from a Postscript name or a name from a glyph number is
achieved through methods rather than variable lookup.

This class handles PostScript table types of 1, 2, 2.5 & 3, but not version 4.
Support for version 2.5 is as per Apple spec rather than MS.

The way to look up Postscript names or glyphs is:

    $pname = $f->{'post'}{'VAL'}[$gnum];
    $gnum = $f->{'post'}{'STRINGS'}{$pname};

=head1 INSTANCE VARIABLES

Due to different systems having different limitations, there are various class
variables available to control what post table types can be written.

=over 4

=item $Font::TTF::Post::no25

If set tells Font::TTF::Post::out to use table type 2 instead of 2.5 in case apps
can't handle version 2.5.

=item VAL

Contains an array indexed by glyph number of Postscript names. This is used when
writing out a font.

=item STRINGS

An associative array of Postscript names mapping to the highest glyph with that
name. These may not be in sync with VAL.

=back

In addition there are the standard introductory variables defined in the
standard:

    FormatType
    italicAngle
    underlinePosition
    underlineThickness
    isFixedPitch
    minMemType42
    maxMemType42
    minMemType1
    maxMemType1

=head1 METHODS

=cut

use strict;
use vars qw(@ISA @base_set %base_set %fields $VERSION $no25 @field_info @base_set);
require Font::TTF::Table;
use Font::TTF::Utils;

$no25 = 1;                  # officially deprecated format 2.5 tables in MS spec 1.3

@ISA = qw(Font::TTF::Table);
@field_info = (
    'FormatType' => 'f',
    'italicAngle' => 'f',
    'underlinePosition' => 's',
    'underlineThickness' => 's',
    'isFixedPitch' => 'L',
    'minMemType42' => 'L',
    'maxMemType42' => 'L',
    'minMemType1' => 'L',
    'maxMemType1' => 'L');
@base_set = qw(.notdef .null nonmarkingreturn space exclam quotedbl numbersign dollar percent ampersand quotesingle
    parenleft parenright asterisk plus comma hyphen period slash zero one two three four five six
    seven eight nine colon semicolon less equal greater question at A B C D E F G H I J K L M N O P Q
    R S T U V W X Y Z bracketleft backslash bracketright asciicircum underscore grave a b c d e f g h
    i j k l m n o p q r s t u v w x y z braceleft bar braceright asciitilde Adieresis Aring Ccedilla
    Eacute Ntilde Odieresis Udieresis aacute agrave acircumflex adieresis atilde aring ccedilla eacute
    egrave ecircumflex edieresis iacute igrave icircumflex idieresis ntilde oacute ograve ocircumflex
    odieresis otilde uacute ugrave ucircumflex udieresis dagger degree cent sterling section bullet
    paragraph germandbls registered copyright trademark acute dieresis notequal AE Oslash infinity
    plusminus lessequal greaterequal yen mu partialdiff summation product pi integral ordfeminine
    ordmasculine Omega ae oslash questiondown exclamdown logicalnot radical florin approxequal
    Delta guillemotleft guillemotright ellipsis nonbreakingspace Agrave Atilde Otilde OE oe endash emdash
    quotedblleft quotedblright quoteleft quoteright divide lozenge ydieresis Ydieresis fraction currency
    guilsinglleft guilsinglright fi fl daggerdbl periodcentered quotesinglbase quotedblbase perthousand
    Acircumflex Ecircumflex Aacute Edieresis Egrave Iacute Icircumflex Idieresis Igrave Oacute Ocircumflex
    apple Ograve Uacute Ucircumflex Ugrave dotlessi circumflex tilde macron breve dotaccent
    ring cedilla hungarumlaut ogonek caron Lslash lslash Scaron scaron Zcaron zcaron brokenbar Eth eth
    Yacute yacute Thorn thorn minus multiply onesuperior twosuperior threesuperior onehalf onequarter
    threequarters franc Gbreve gbreve Idotaccent Scedilla scedilla Cacute cacute Ccaron ccaron dcroat);

$VERSION = 0.01;        # MJPH   5-AUG-1998     Re-organise data structures

sub init
{
    my ($k, $v, $c, $i);
    for ($i = 0; $i < $#field_info; $i += 2)
    {
        ($k, $v, $c) = TTF_Init_Fields($field_info[$i], $c, $field_info[$i + 1]);
        next unless defined $k && $k ne "";
        $fields{$k} = $v;
    }
    $i = 0;
    %base_set = map {$_ => $i++} @base_set;
}


=head2 $t->read

Reads the Postscript table into memory from disk

=cut

sub read
{
    my ($self) = @_;
    my ($dat, $dat1, $i, $off, $c, $maxoff, $form, $angle, $numGlyphs);
    my ($fh) = $self->{' INFILE'};

    $numGlyphs = $self->{' PARENT'}{'maxp'}{'numGlyphs'};
    $self->SUPER::read or return $self;
    init unless ($fields{'FormatType'});
    $fh->read($dat, 32);
    TTF_Read_Fields($self, $dat, \%fields);

    if (int($self->{'FormatType'} + .5) == 1)
    {
        for ($i = 0; $i < 258; $i++)
        {
            $self->{'VAL'}[$i] = $base_set[$i];
            $self->{'STRINGS'}{$base_set[$i]} = $i unless (defined $self->{'STRINGS'}{$base_set[$i]});
        }
    } elsif (int($self->{'FormatType'} * 2 + .1) == 5)
    {
        $fh->read($dat, 2);
        $numGlyphs = unpack("n", $dat);
        $fh->read($dat, $numGlyphs);
        for ($i = 0; $i < $numGlyphs; $i++)
        {
            $off = unpack("c", substr($dat, $i, 1));
            $self->{'VAL'}[$i] = $base_set[$i + $off];
            $self->{'STRINGS'}{$base_set[$i + $off]} = $i unless (defined $self->{'STRINGS'}{$base_set[$i + $off]});
        }
    } elsif (int($self->{'FormatType'} + .5) == 2)
    {
        my (@strings);
        
        $fh->read($dat, ($numGlyphs + 1) << 1);
        for ($i = 0; $i < $numGlyphs; $i++)
        {
            $off = unpack("n", substr($dat, ($i + 1) << 1, 2));
            $maxoff = $off if (!defined $maxoff || $off > $maxoff);
        }
        for ($i = 0; $i < $maxoff - 257; $i++)
        {
            $fh->read($dat1, 1);
            $off = unpack("C", $dat1);
            $fh->read($dat1, $off);
            $strings[$i] = $dat1;
        }
        for ($i = 0; $i < $numGlyphs; $i++)
        {
            $off = unpack("n", substr($dat, ($i + 1) << 1, 2));
            if ($off > 257)
            {
                $self->{'VAL'}[$i] = $strings[$off - 258];
                $self->{'STRINGS'}{$strings[$off - 258]} = $i;
            }
            else
            {
                $self->{'VAL'}[$i] = $base_set[$off];
                $self->{'STRINGS'}{$base_set[$off]} = $i unless (defined $self->{'STRINGS'}{$base_set[$off]});
            }
        }
    }
    $self;
}


=head2 $t->out($fh)

Writes out a new Postscript name table from memory or copies from disk

=cut

sub out
{
    my ($self, $fh) = @_;
    my ($i, $num);

    return $self->SUPER::out($fh) unless $self->{' read'};

    $num = $self->{' PARENT'}{'maxp'}{'numGlyphs'};

    init unless ($fields{'FormatType'});

    for ($i = $#{$self->{'VAL'}}; !defined $self->{'VAL'}[$i] && $i > 0; $i--)
    { pop(@{$self->{'VAL'}}); }
    if ($#{$self->{'VAL'}} < 0)
    { $self->{'FormatType'} = 3; }
    else
    {
        $self->{'FormatType'} = 1;
        for ($i = 0; $i < $num; $i++)
        {
            if (!defined $base_set{$self->{'VAL'}[$i]})
            {
                $self->{'FormatType'} = 2;
                last;
            }
            elsif ($base_set{$self->{'VAL'}[$i]} != $i)
            { $self->{'FormatType'} = ($no25 ? 2 : 2.5); }
        }
    }

    $fh->print(TTF_Out_Fields($self, \%fields, 32));

    return $self if (int($self->{'FormatType'} + .4) == 3);

    if (int($self->{'FormatType'} + .5) == 2)
    {
        my (@ind);
        my ($count) = 0;
        
        $fh->print(pack("n", $num));
        for ($i = 0; $i < $num; $i++)
        {
            if (defined $base_set{$self->{'VAL'}[$i]})
            { $fh->print(pack("n", $base_set{$self->{'VAL'}[$i]})); }
            else
            {
                $fh->print(pack("n", $count + 258));
                $ind[$count++] = $i;
            }
        }
        for ($i = 0; $i < $count; $i++)
        {
            $fh->print(pack("C", length($self->{'VAL'}[$ind[$i]])));
            $fh->print($self->{'VAL'}[$ind[$i]]);
        }
    } elsif (int($self->{'FormatType'} * 2 + .5) == 5)
    {
        $fh->print(pack("n", $num));
        for ($i = 0; $i < $num; $i++)
        { $fh->print(pack("c", defined $base_set{$self->{'VAL'}[$i]} ?
                    $base_set{$self->{'VAL'}[$i]} - $i : -$i)); }
    }
        
    $self;
}


=head2 $t->XML_element($context, $depth, $key, $val)

Outputs the names as one block of XML

=cut

sub XML_element
{
    my ($self) = shift;
    my ($context, $depth, $key, $val) = @_;
    my ($fh) = $context->{'fh'};
    my ($i);

    return $self->SUPER::XML_element(@_) unless ($key eq 'STRINGS' || $key eq 'VAL');
    return unless ($key eq 'VAL');

    $fh->print("$depth<names>\n");
    for ($i = 0; $i <= $#{$self->{'VAL'}}; $i++)
    { $fh->print("$depth$context->{'indent'}<name post='$self->{'VAL'}[$i]' gid='$i'/>\n"); }
    $fh->print("$depth</names>\n");
    $self;
}

1;

=head1 BUGS

=over 4

=item *

No support for type 4 tables

=back

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

