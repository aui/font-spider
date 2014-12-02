package Font::TTF::Head;

=head1 NAME

Font::TTF::Head - The head table for a TTF Font

=head1 DESCRIPTION

This is a very basic table with just instance variables as described in the
TTF documentation, using the same names. One of the most commonly used is
C<unitsPerEm>.

=head1 INSTANCE VARIABLES

The C<head> table has no internal instance variables beyond those common to all
tables and those specified in the standard:

    version
    fontRevision
    checkSumAdjustment
    magicNumber
    flags
    unitsPerEm
    created
    modified
    xMin
    yMin
    xMax
    yMax
    macStyle
    lowestRecPPEM
    fontDirectionHint
    indexToLocFormat
    glyphDataFormat

The two dates are held as an array of two unsigned longs (32-bits)

=head1 METHODS

=cut

use strict;
use vars qw(@ISA %fields @field_info);

require Font::TTF::Table;
use Font::TTF::Utils;

@ISA = qw(Font::TTF::Table);
@field_info = (
    'version' => 'v',
    'fontRevision' => 'f',
    'checkSumAdjustment' => 'L',
    'magicNumber' => 'L',
    'flags' => 'S',
    'unitsPerEm' => 'S',
    'created' => 'L2',
    'modified' => 'L2',
    'xMin' => 's',
    'yMin' => 's',
    'xMax' => 's',
    'yMax' => 's',
    'macStyle' => 'S',
    'lowestRecPPEM' => 'S',
    'fontDirectionHint' => 's',
    'indexToLocFormat' => 's',
    'glyphDataFormat' => 's');

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

    init unless defined $fields{'Ascender'};
    $self->{' INFILE'}->read($dat, 54);

    TTF_Read_Fields($self, $dat, \%fields);
    $self;
}


=head2 $t->out($fh)

Writes the table to a file either from memory or by copying. If in memory
(which is usually) the checkSumAdjustment field is set to 0 as per the default
if the file checksum is not to be considered.

=cut

sub out
{
    my ($self, $fh) = @_;

    return $self->SUPER::out($fh) unless $self->{' read'};      # this is never true
#    $self->{'checkSumAdjustment'} = 0 unless $self->{' PARENT'}{' wantsig'};
    $fh->print(TTF_Out_Fields($self, \%fields, 54));
    $self;
}


=head2 $t->XML_element($context, $depth, $key, $value)

Handles date process for the XML exporter

=cut

sub XML_element
{
    my ($self) = shift;
    my ($context, $depth, $key, $value) = @_;
    my ($fh) = $context->{'fh'};
    my ($output, @time);
    my (@month) = qw(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC);

    return $self->SUPER::XML_element(@_) unless ($key eq 'created' || $key eq 'modified');

    @time = gmtime($self->getdate($key eq 'created'));
    $output = sprintf("%d/%s/%d %d:%d:%d", $time[3], $month[$time[4]], $time[5] + 1900,
            $time[2], $time[1], $time[0]);
    $fh->print("$depth<$key>$output</$key>\n");
    $self;
}
    

=head2 $t->update

Updates the head table based on the glyph data and the hmtx table

=cut

sub update
{
    my ($self) = @_;
    my ($num, $i, $loc, $hmtx);
    my ($xMin, $yMin, $xMax, $yMax, $lsbx);

    return undef unless ($self->SUPER::update);

    $num = $self->{' PARENT'}{'maxp'}{'numGlyphs'};
    return undef unless (defined $self->{' PARENT'}{'hmtx'} && defined $self->{' PARENT'}{'loca'});
    $hmtx = $self->{' PARENT'}{'hmtx'}->read;
    
    $self->{' PARENT'}{'loca'}->update;
    $hmtx->update;              # if we updated, then the flags will be set anyway.
    $lsbx = 1;
    for ($i = 0; $i < $num; $i++)
    {
        $loc = $self->{' PARENT'}{'loca'}{'glyphs'}[$i];
        next unless defined $loc;
        $loc->read->update_bbox;
        $xMin = $loc->{'xMin'} if ($loc->{'xMin'} < $xMin || $i == 0);
        $yMin = $loc->{'yMin'} if ($loc->{'yMin'} < $yMin || $i == 0);
        $xMax = $loc->{'xMax'} if ($loc->{'xMax'} > $xMax);
        $yMax = $loc->{'yMax'} if ($loc->{'yMax'} > $yMax);
        $lsbx &= ($loc->{'xMin'} == $hmtx->{'lsb'}[$i]);
    }
    $self->{'xMin'} = $xMin;
    $self->{'yMin'} = $yMin;
    $self->{'xMax'} = $xMax;
    $self->{'yMax'} = $yMax;
    if ($lsbx)
    { $self->{'flags'} |= 2; }
    else
    { $self->{'flags'} &= ~2; }
    $self;
}


=head2 $t->getdate($is_create)

Converts font modification time (or creation time if $is_create is set) to a 32-bit integer as returned
from time(). Returns undef if the value is out of range, either before the epoch or after the maximum
storable time.

=cut

sub getdate
{
    my ($self, $is_create) = @_;
    my ($arr) = $self->{$is_create ? 'created' : 'modified'};

    $arr->[1] -= 2082844800;        # seconds between 1/Jan/1904 and 1/Jan/1970 (midnight)
    if ($arr->[1] < 0)
    {
        $arr->[1] += 0xFFFFFFF; $arr->[1]++;
        $arr->[0]--;
    }
    return undef if $arr->[0] != 0;
    return $arr->[1];
}


=head2 $t->setdate($time, $is_create)

Sets the time information for modification (or creation time if $is_create is set) according to the 32-bit
time information.

=cut

sub setdate
{
    my ($self, $time, $is_create) = @_;
    my (@arr);

    $arr[1] = $time;
    if ($arr[1] >= 0x83DA4F80)
    {
        $arr[1] -= 0xFFFFFFFF;
        $arr[1]--;
        $arr[0]++;
    }
    $arr[1] += 2082844800;
    $self->{$is_create ? 'created' : 'modified'} = \@arr;
    $self;
}
    

1;


=head1 BUGS

None known

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

