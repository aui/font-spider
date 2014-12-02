package Font::TTF::PCLT;

=head1 NAME

Font::TTF::PCLT - PCLT TrueType font table

=head1 DESCRIPTION

The PCLT table holds various pieces HP-PCL specific information. Information
here is generally not used by other software, except for the xHeight and
CapHeight which are stored here (if the table exists in a font).

=head1 INSTANCE VARIABLES

Only from table and the standard:

    version
    FontNumber
    Pitch
    xHeight
    Style
    TypeFamily
    CapHeight
    SymbolSet
    Typeface
    CharacterComplement
    FileName
    StrokeWeight
    WidthType
    SerifStyle

Notice that C<Typeface>, C<CharacterComplement> and C<FileName> return arrays
of unsigned characters of the appropriate length

=head1 METHODS

=cut

use strict;
use vars qw(@ISA %fields @field_info);

require Font::TTF::Table;
use Font::TTF::Utils;

@ISA = qw(Font::TTF::Table);
@field_info = (
    'version' => 'v',
    'FontNumber' => 'L',
    'Pitch' => 'S',
    'xHeight' => 'S',
    'Style' => 'S',
    'TypeFamily' => 'S',
    'CapHeight' => 'S',
    'SymbolSet' => 'S',
    'Typeface' => 'C16',
    'CharacterComplement' => 'C8',
    'FileName' => 'C6',
    'StrokeWeight' => 'C',
    'WidthType' => 'C',
    'SerifStyle' => 'c');

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


=head2 $t->read

Reads the table into memory thanks to some utility functions

=cut

sub read
{
    my ($self) = @_;
    my ($dat);

    $self->SUPER::read || return $self;

    init unless defined $fields{'xHeight'};
    $self->{' INFILE'}->read($dat, 54);

    TTF_Read_Fields($self, $dat, \%fields);
    $self;
}


=head2 $t->out($fh)

Writes the table to a file either from memory or by copying.

=cut

sub out
{
    my ($self, $fh) = @_;

    return $self->SUPER::out($fh) unless $self->{' read'};
    $fh->print(TTF_Out_Fields($self, \%fields, 54));
}

1;

=head1 BUGS

None known

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

