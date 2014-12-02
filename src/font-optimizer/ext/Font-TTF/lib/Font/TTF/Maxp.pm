package Font::TTF::Maxp;

=head1 NAME

Font::TTF::Maxp - Maximum Profile table in a font

=head1 DESCRIPTION

A collection of useful instance variables following the TTF standard. Probably
the most used being C<numGlyphs>. Note that this particular value is
foundational and should be kept up to date by the application, it is not updated
by C<update>.

Handles table versions 0.5, 1.0

=head1 INSTANCE VARIABLES

No others beyond those specified in the standard:

    numGlyphs
    maxPoints
    maxContours
    maxCompositePoints
    maxCompositeContours
    maxZones
    maxTwilightPoints
    maxStorage
    maxFunctionDefs
    maxInstructionDefs
    maxStackElements
    maxSizeOfInstructions
    maxComponentElements
    maxComponentDepth


=head1 METHODS

=cut

use strict;
use vars qw(@ISA %fields @field_info);
use Font::TTF::Utils;

@ISA = qw(Font::TTF::Table);
@field_info = (
    'numGlyphs' => 'S',
    'maxPoints' => 'S',
    'maxContours' => 'S',
    'maxCompositePoints' => 'S',
    'maxCompositeContours' => 'S',
    'maxZones' => 'S',
    'maxTwilightPoints' => 'S',
    'maxStorage' => 'S',
    'maxFunctionDefs' => 'S',
    'maxInstructionDefs' => 'S',
    'maxStackElements' => 'S',
    'maxSizeOfInstructions' => 'S',
    'maxComponentElements' => 'S',
    'maxComponentDepth' => 'S');

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

Reads the table into memory

=cut

sub read
{
    my ($self) = @_;
    my ($dat);

    $self->SUPER::read or return $self;

    init unless defined $fields{'numGlyphs'};    # any key would do
    $self->{' INFILE'}->read($dat, 4);
    $self->{'version'} = TTF_Unpack("v", $dat);

    if ($self->{'version'} == 0.5)
    {
        $self->{' INFILE'}->read($dat, 2);
        $self->{'numGlyphs'} = unpack("n", $dat);
    } else
    {
        $self->{' INFILE'}->read($dat, 28);
        TTF_Read_Fields($self, $dat, \%fields);
    }
    $self;
}


=head2 $t->out($fh)

Writes the table to a file either from memory or by copying.

=cut

sub out
{
    my ($self, $fh) = @_;

    return $self->SUPER::out($fh) unless $self->{' read'};
    $fh->print(TTF_Pack("v", $self->{'version'}));
    
    if ($self->{'version'} == 0.5)
    { $fh->print(pack("n", $self->{'numGlyphs'})); }
    else
    { $fh->print(TTF_Out_Fields($self, \%fields, 28)); }
    $self;
}


=head2 $t->update

Calculates all the maximum values for a font based on the glyphs in the font.
Only those fields which require hinting code interpretation are ignored and
left as they were read.

=cut

sub update
{
    my ($self) = @_;
    my ($i, $num, @n, @m, $j);
    my (@name) = qw(maxPoints maxContours maxCompositePoints maxCompositeContours
                    maxSizeOfInstructions maxComponentElements maxComponentDepth);

    return undef unless ($self->SUPER::update);
    return undef if ($self->{'version'} == 0.5);        # only got numGlyphs
    return undef unless (defined $self->{' PARENT'}{'loca'});
    $self->{' PARENT'}{'loca'}->update;
    $num = $self->{'numGlyphs'};

    for ($i = 0; $i < $num; $i++)
    {
        my ($g) = $self->{' PARENT'}{'loca'}{'glyphs'}[$i] || next;

        @n = $g->maxInfo;

        for ($j = 0; $j <= $#n; $j++)
        { $m[$j] = $n[$j] if $n[$j] > $m[$j]; }
    }

    foreach ('prep', 'fpgm')
    { $m[4] = length($self->{' PARENT'}{$_}{' dat'})
            if (defined $self->{' PARENT'}{$_} 
                && length($self->{' PARENT'}{$_}{' dat'}) > $m[4]);
    }

    for ($j = 0; $j <= $#name; $j++)
    { $self->{$name[$j]} = $m[$j]; }
    $self;
}
1;


=head1 BUGS

None known

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut
