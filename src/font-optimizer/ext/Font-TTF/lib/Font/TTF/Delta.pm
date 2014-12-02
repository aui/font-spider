package Font::TTF::Delta;

=head1 NAME 

Font::TTF::Delta - Opentype Device tables

=head1 DESCRIPTION

Each device table corresponds to a set of deltas for a particular point over
a range of ppem values.

=item first

The first ppem value in the range

=item last

The last ppem value in the range

=item val

This is an array of deltas corresponding to each ppem in the range between
first and last inclusive.

=item fmt

This is the fmt used (log2 of number bits per value) when the device table was
read. It is recalculated on output.

=head1 METHODS

=cut

use strict;
use Font::TTF::Utils;

=head2 new

Creates a new device table

=cut

sub new
{
    my ($class) = @_;
    my ($self) = {};

    bless $self, $class;
}


=head2 read

Reads a device table from the given IO object at the current location

=cut

sub read
{
    my ($self, $fh) = @_;
    my ($dat, $fmt, $num, $i, $j, $mask);

    $fh->read($dat, 6);
    ($self->{'first'}, $self->{'last'}, $fmt) = TTF_Unpack("S3", $dat);
    $self->{'fmt'} = $fmt;

    $fmt = 1 << $fmt;
    $num = ((($self->{'last'} - $self->{'first'} + 1) * $fmt) + 15) >> 8;
    $fh->read($dat, $num);

    $mask = (0xffff << (16 - $fmt)) & 0xffff;
    $j = 0;
    for ($i = $self->{'first'}; $i <= $self->{'last'}; $i++)
    {
        if ($j == 0)
        {
            $num = TTF_Unpack("S", substr($dat, 0, 2));
            substr($dat, 0, 2) = '';
        }
        push (@{$self->{'val'}}, ($num & $mask) >> (16 - $fmt));
        $num <<= $fmt;
        $j += $fmt;
        $j = 0 if ($j >= 16);
    }
    $self;
}


=head2 out($fh, $style)

Outputs a device table to the given IO object at the current location, or just
returns the data to be output if $style != 0

=cut

sub out
{
    my ($self, $fh, $style) = @_;
    my ($dat, $fmt, $num, $mask, $j, $f, $out);

    foreach $f (@{$self->{'val'}})
    {
        my ($tfmt) = $f > 0 ? $f + 1 : -$f;
        $fmt = $tfmt if $tfmt > $fmt;
    }

    if ($fmt > 8)
    { $fmt = 3; }
    elsif ($fmt > 2)
    { $fmt = 2; }
    else
    { $fmt = 1; }

    $out = TTF_Pack("S3", $self->{'first'}, $self->{'last'}, $fmt);

    $fmt = 1 << $fmt;
    $mask = 0xffff >> (16 - $fmt);
    $j = 0; $dat = 0;
    foreach $f (@{$self->{'val'}})
    {
        $dat |= ($f & $mask) << (16 - $fmt - $j);
        $j += $fmt;
        if ($j >= 16)
        {
            $j = 0;
            $out .= TTF_Pack("S", $dat);
            $dat = 0;
        }
    }
    $out .= pack('n', $dat) if ($j > 0);
    $fh->print($out) unless $style;
    $out;
}

=head2 $d->signature()

Returns a content based identifying string for this delta for
compression purposes

=cut

sub signature
{
    my ($self) = @_;
    return join (",", $self->{'first'}, $self->{'last'}, @{$self->{'val'}});
}


=head2 $d->out_xml($context)

Outputs a delta in XML

=cut

sub out_xml
{
    my ($self, $context, $depth) = @_;
    my ($fh) = $context->{'fh'};

    $fh->printf("%s<delta first='%s' last='%s'>\n", $depth, $self->{'first'}, $self->{'last'});
    $fh->print("$depth$context->{'indent'}" . join (' ', @{$self->{'val'}}) . "\n") if defined ($self->{'val'});
    $fh->print("$depth</delta>\n");
}

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

1;

