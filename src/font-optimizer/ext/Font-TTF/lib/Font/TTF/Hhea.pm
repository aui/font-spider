package Font::TTF::Hhea;

=head1 NAME

Font::TTF::Hhea - Horizontal Header table

=head1 DESCRIPTION

This is a simplte table with just standards specified instance variables

=head1 INSTANCE VARIABLES

    version
    Ascender
    Descender
    LineGap
    advanceWidthMax
    minLeftSideBearing
    minRightSideBearing
    xMaxExtent
    caretSlopeRise
    caretSlopeRun
    metricDataFormat
    numberOfHMetrics


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
    'advanceWidthMax' => 'S',
    'minLeftSideBearing' => 's',
    'minRightSideBearing' => 's',
    'xMaxExtent' => 's',
    'caretSlopeRise' => 's',
    'caretSlopeRun' => 's',
    'metricDataFormat' => '+10s',
    'numberOfHMetrics' => 'S');

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

    $self->{'numberOfHMetrics'} = $self->{' PARENT'}{'hmtx'}->numMetrics || $self->{'numberOfHMetrics'};
    $fh->print(TTF_Out_Fields($self, \%fields, 36));
    $self;
}


=head2 $t->update

Updates various parameters in the hhea table from the hmtx table.

=cut

sub update
{
    my ($self) = @_;
    my ($hmtx) = $self->{' PARENT'}{'hmtx'};
    my ($glyphs);
    my ($num, $res);
    my ($i, $maw, $mlsb, $mrsb, $mext, $aw, $lsb, $ext);

    return undef unless ($self->SUPER::update);
    return undef unless (defined $hmtx && defined $self->{' PARENT'}{'loca'});

    $hmtx->read->update;
    $self->{' PARENT'}{'loca'}->read->update;
    $glyphs = $self->{' PARENT'}{'loca'}{'glyphs'};
    $num = $self->{' PARENT'}{'maxp'}{'numGlyphs'};

    for ($i = 0; $i < $num; $i++)
    {
        $aw = $hmtx->{'advance'}[$i];
        $lsb = $hmtx->{'lsb'}[$i];
        if (defined $glyphs->[$i])
        { $ext = $lsb + $glyphs->[$i]->read->{'xMax'} - $glyphs->[$i]{'xMin'}; }
        else
        { $ext = $aw; }
        $maw = $aw if ($aw > $maw);
        $mlsb = $lsb if ($lsb < $mlsb or $i == 0);
        $mrsb = $aw - $ext if ($aw - $ext < $mrsb or $i == 0);
        $mext = $ext if ($ext > $mext);
    }
    $self->{'advanceWidthMax'} = $maw;
    $self->{'minLeftSideBearing'} = $mlsb;
    $self->{'minRightSideBearing'} = $mrsb;
    $self->{'xMaxExtent'} = $mext;
    $self->{'numberOfHMetrics'} = $hmtx->numMetrics;
    $self;
}


1;


=head1 BUGS

None known

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

