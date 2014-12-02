package Font::TTF::Hmtx;

=head1 NAME

Font::TTF::Hmtx - Horizontal Metrics

=head1 DESCRIPTION

Contains the advance width and left side bearing for each glyph. Given the
compressability of the data onto disk, this table uses information from
other tables, and thus must do part of its output during the output of
other tables

=head1 INSTANCE VARIABLES

The horizontal metrics are kept in two arrays by glyph id. The variable names
do not start with a space

=over 4

=item advance

An array containing the advance width for each glyph

=item lsb

An array containing the left side bearing for each glyph

=back

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);
require Font::TTF::Table;

@ISA = qw(Font::TTF::Table);


=head2 $t->read

Reads the horizontal metrics from the TTF file into memory

=cut

sub read
{
    my ($self) = @_;
    my ($numh, $numg);

    $numh = $self->{' PARENT'}{'hhea'}->read->{'numberOfHMetrics'};
    $numg = $self->{' PARENT'}{'maxp'}{'numGlyphs'};
    $self->_read($numg, $numh, "advance", "lsb");
}

sub _read
{
    my ($self, $numg, $numh, $tAdv, $tLsb) = @_;
    my ($fh) = $self->{' INFILE'};
    my ($i, $dat);
    
    $self->SUPER::read or return $self;

    for ($i = 0; $i < $numh; $i++)
    {
        $fh->read($dat, 4);
        ($self->{$tAdv}[$i], $self->{$tLsb}[$i]) = unpack("nn", $dat);
        $self->{$tLsb}[$i] -= 65536 if ($self->{$tLsb}[$i] >= 32768);
    }
    
    $i--;
    while (++$i < $numg)
    {
        $fh->read($dat, 2);
        $self->{$tAdv}[$i] = $self->{$tAdv}[$numh - 1];
        $self->{$tLsb}[$i] = unpack("n", $dat);
        $self->{$tLsb}[$i] -= 65536 if ($self->{$tLsb}[$i] >= 32768);
    }
    $self;
}
    
=head2 $t->numMetrics

Calculates again the number of long metrics required to store the information
here. Returns undef if the table has not been read.

=cut

sub numMetrics
{
    my ($self) = @_;
    my ($numg) = $self->{' PARENT'}{'maxp'}{'numGlyphs'};
    my ($i);

    return undef unless $self->{' read'};

    for ($i = $numg - 2; $i >= 0; $i--)
    { last if ($self->{'advance'}[$i] != $self->{'advance'}[$i + 1]); }

    return $i + 2;
}


=head2 $t->out($fh)

Writes the metrics to a TTF file. Assumes that the C<hhea> has updated the
numHMetrics from here

=cut

sub out
{
    my ($self, $fh) = @_;
    my ($numg) = $self->{' PARENT'}{'maxp'}{'numGlyphs'};
    my ($numh) = $self->{' PARENT'}{'hhea'}->read->{'numberOfHMetrics'};
    $self->_out($fh, $numg, $numh, "advance", "lsb");
}

sub _out
{
    my ($self, $fh, $numg, $numh, $tAdv, $tLsb) = @_;
    my ($i, $lsb);

    return $self->SUPER::out($fh) unless ($self->{' read'});

    for ($i = 0; $i < $numg; $i++)
    {
        $lsb = $self->{$tLsb}[$i];
        $lsb += 65536 if $lsb < 0;
        if ($i >= $numh)
        { $fh->print(pack("n", $lsb)); }
        else
        { $fh->print(pack("n2", $self->{$tAdv}[$i], $lsb)); }
    }
    $self;
}


=head2 $t->update

Updates the lsb values from the xMin from the each glyph

=cut

sub update
{
    my ($self) = @_;
    my ($numg) = $self->{' PARENT'}{'maxp'}{'numGlyphs'};
    my ($i);

    return undef unless ($self->SUPER::update);
# lsb & xMin must always be the same, regardless of any flags!
#    return $self unless ($self->{' PARENT'}{'head'}{'flags'} & 2);        # lsb & xMin the same

    $self->{' PARENT'}{'loca'}->update;
    for ($i = 0; $i < $numg; $i++)
    {
        my ($g) = $self->{' PARENT'}{'loca'}{'glyphs'}[$i];
        if ($g)
        { $self->{'lsb'}[$i] = $g->read->update_bbox->{'xMin'}; }
        else
        { $self->{'lsb'}[$i] = 0; }
    }
    $self->{' PARENT'}{'head'}{'flags'} |= 2;
    $self;
}
    

=head2 $t->out_xml($context, $depth)

Outputs the table in XML

=cut

sub out_xml
{
    my ($self, $context, $depth) = @_;
    my ($fh) = $context->{'fh'};
    my ($numg) = $self->{' PARENT'}{'maxp'}{'numGlyphs'};
    my ($addr) = ($self =~ m/\((.+)\)$/o);
    my ($i);

    if ($context->{'addresses'}{$addr})
    {
        $fh->printf("%s<%s id_ref='%s'/>\n", $depth, $context->{'name'}, $addr);
        return $self;
    }
    else
    { $fh->printf("%s<%s id='%s'>\n", $depth, $context->{'name'}, $addr); }

    $self->read;

    for ($i = 0; $i < $numg; $i++)
    { $fh->print("$depth$context->{'indent'}<width adv='$self->{'advance'}[$i]' lsb='$self->{'lsb'}[$i]'/>\n"); }

    $fh->print("$depth</$context->{'name'}>\n");
    $self;
}

1;

=head1 BUGS

None known

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

