package Font::TTF::Hdmx;

=head1 NAME

Font::TTF::Hdmx - Horizontal device metrics

=head1 DESCRIPTION

The table consists of an hash of device metric tables indexed by the ppem for
that subtable. Each subtable consists of an array of advance widths in pixels
for each glyph at that ppem (horizontally).

=head1 INSTANCE VARIABLES

Individual metrics are accessed using the following referencing:

    $f->{'hdmx'}{$ppem}[$glyph_num]

In addition there is one instance variable:

=over 4

=item Num

Number of device tables.

=back

=head2 METHODS

=cut

use strict;
use vars qw(@ISA);

@ISA = qw(Font::TTF::Table);


=head2 $t->read

Reads the table into data structures

=cut

sub read
{
    my ($self) = @_;
    my ($fh) = $self->{' INFILE'};
    my ($numg, $ppem, $i, $numt, $dat, $len);

    $numg = $self->{' PARENT'}{'maxp'}{'numGlyphs'};
    $self->SUPER::read or return $self;

    $fh->read($dat, 8);
    ($self->{'Version'}, $numt, $len) = unpack("nnN", $dat);
    $self->{'Num'} = $numt;

    for ($i = 0; $i < $numt; $i++)
    {
        $fh->read($dat, $len);
        $ppem = unpack("C", $dat);
        $self->{$ppem} = [unpack("C$numg", substr($dat, 2))];
    }
    $self;
}


=head2 $t->out($fh)

Outputs the device metrics for this font

=cut

sub out
{
    my ($self, $fh) = @_;
    my ($numg, $i, $pad, $len, $numt, @ppem, $max);

    return $self->SUPER::out($fh) unless ($self->{' read'});

    $numg = $self->{' PARENT'}{'maxp'}{'numGlyphs'};
    @ppem = grep(/^\d+$/, sort {$a <=> $b} keys %$self);
    $pad = "\000" x (3 - ($numg + 1) % 4);
    $len = $numg + 2 + length($pad);
    $fh->print(pack("nnN", 0, $#ppem + 1, $len));
    for $i (@ppem)
    {
        $max = 0;
        foreach (@{$self->{$i}}[0..($numg - 1)])
        { $max = $_ if $_ > $max; }
        $fh->print(pack("C*", $i, $max, @{$self->{$i}}[0..($numg - 1)]) . $pad);
    }
    $self;
}


=head2 $t->tables_do(&func)

For each subtable it calls &sub($ref, $ppem)

=cut

sub tables_do
{
    my ($self, $func) = @_;
    my ($i);

    foreach $i (grep(/^\d+$/, %$self))
    { &$func($self->{$i}, $i); }
    $self;
}


=head2 $t->XML_element($context, $depth, $key, $value)

Outputs device metrics a little more tidily

=cut

sub XML_element
{
    my ($self) = shift;
    my ($context, $depth, $key, $value) = @_;
    my ($fh) = $context->{'fh'};
    my ($i);

    return $self->SUPER::XML_element(@_) if (ref($value) ne 'ARRAY');
    $fh->print("$depth<metrics ppem='$key'>\n");
    for ($i = 0; $i <= $#{$value}; $i += 25)
    {
        $fh->print("$depth$context->{'indent'}". join(' ', @{$value}[$i .. $i + 24]) . "\n");
    }
    $fh->print("$depth</metrics>\n");
    $self;
}

1;

=head1 BUGS

None known

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

