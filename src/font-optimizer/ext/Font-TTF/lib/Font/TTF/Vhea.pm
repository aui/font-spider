package Font::TTF::Vhea;

=head1 NAME

Font::TTF::Vhea - Vertical Header table

=head1 DESCRIPTION

This is a simple table with just standards specified instance variables

=head1 INSTANCE VARIABLES

    version
    Ascender
    Descender
    LineGap
    advanceHeightMax
    minTopSideBearing
    minBottomSideBearing
    yMaxExtent
    caretSlopeRise
    caretSlopeRun
    metricDataFormat
    numberOfVMetrics


=head1 METHODS

=cut

use strict;
use vars qw(@ISA %fields @field_info);

require Font::TTF::Table;
use Font::TTF::Utils;

@ISA = qw(Font::TTF::Table);
@field_info = (
    'version' => 'v',
    'Ascender' => 's',
    'Descender' => 's',
    'LineGap' => 's',
    'advanceHeightMax' => 'S',
    'minTopSideBearing' => 's',
    'minBottomSideBearing' => 's',
    'yMaxExtent' => 's',
    'caretSlopeRise' => 's',
    'caretSlopeRun' => 's',
    'metricDataFormat' => '+10s',
    'numberOfVMetrics' => 's');

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

Reads the table into memory as instance variables

=cut

sub read
{
    my ($self) = @_;
    my ($dat);

    $self->SUPER::read or return $self;
    init unless defined $fields{'Ascender'};
    $self->{' INFILE'}->read($dat, 36);

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

    $self->{'numberOfVMetrics'} = $self->{' PARENT'}{'vmtx'}->numMetrics || $self->{'numberOfVMetrics'};
    $fh->print(TTF_Out_Fields($self, \%fields, 36));
    $self;
}


=head2 $t->update

Updates various parameters in the hhea table from the hmtx table, assuming
the C<hmtx> table is dirty.

=cut

sub update
{
    my ($self) = @_;
    my ($vmtx) = $self->{' PARENT'}{'vmtx'};
    my ($glyphs);
    my ($num);
    my ($i, $maw, $mlsb, $mrsb, $mext, $aw, $lsb, $ext);

    return undef unless ($self->SUPER::update);
    return undef unless (defined $vmtx && defined $self->{' PARENT'}{'loca'});
    $vmtx->read->update;
    $self->{' PARENT'}{'loca'}->read->update;
    $glyphs = $self->{' PARENT'}{'loca'}{'glyphs'};
    $num = $self->{' PARENT'}{'maxp'}{'numGlyphs'};

    for ($i = 0; $i < $num; $i++)
    {
        $aw = $vmtx->{'advance'}[$i];
        $lsb = $vmtx->{'top'}[$i];
        if (defined $glyphs->[$i])
        { $ext = $lsb + $glyphs->[$i]->read->{'yMax'} - $glyphs->[$i]{'yMin'}; }
        else
        { $ext = $aw; }
        $maw = $aw if ($aw > $maw);
        $mlsb = $lsb if ($lsb < $mlsb or $i == 0);
        $mrsb = $aw - $ext if ($aw - $ext < $mrsb or $i == 0);
        $mext = $ext if ($ext > $mext);
    }
    $self->{'advanceHeightMax'} = $maw;
    $self->{'minTopSideBearing'} = $mlsb;
    $self->{'minBottomSideBearing'} = $mrsb;
    $self->{'yMaxExtent'} = $mext;
    $self->{'numberOfVMetrics'} = $vmtx->numMetrics;
    $self;
}


1;


=head1 BUGS

None known

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

