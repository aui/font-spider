package Font::TTF::Mort;

=head1 NAME

Font::TTF::Mort - Glyph Metamorphosis table in a font

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);
use Font::TTF::Utils;
use Font::TTF::AATutils;
use Font::TTF::Mort::Chain;

@ISA = qw(Font::TTF::Table);

=head2 $t->read

Reads the table into memory

=cut

sub read
{
    my ($self) = @_;
    my ($dat, $fh, $numChains);
    
    $self->SUPER::read or return $self;

    $fh = $self->{' INFILE'};

    $fh->read($dat, 8);
    ($self->{'version'}, $numChains) = TTF_Unpack("vL", $dat);
    
    my $chains = [];
    foreach (1 .. $numChains) {
        my $chain = new Font::TTF::Mort::Chain->new;
        $chain->read($fh);
        $chain->{' PARENT'} = $self;
        push @$chains, $chain;
    }

    $self->{'chains'} = $chains;

    $self;
}

=head2 $t->out($fh)

Writes the table to a file either from memory or by copying

=cut

sub out
{
    my ($self, $fh) = @_;
    
    return $self->SUPER::out($fh) unless $self->{' read'};

    my $chains = $self->{'chains'};
    $fh->print(TTF_Pack("vL", $self->{'version'}, scalar @$chains));

    foreach (@$chains) {
        $_->out($fh);
    }
}

=head2 $t->print($fh)

Prints a human-readable representation of the table

=cut

sub print
{
    my ($self, $fh) = @_;
    
    $self->read unless $self->{' read'};
    my $feat = $self->{' PARENT'}->{'feat'};
    $feat->read;
    my $post = $self->{' PARENT'}->{'post'};
    $post->read;
    
    $fh = 'STDOUT' unless defined $fh;

    $fh->printf("version %f\n", $self->{'version'});
    
    my $chains = $self->{'chains'};
    foreach (@$chains) {
        $_->print($fh);
    }
}

1;

=head1 BUGS

None known

=head1 AUTHOR

Jonathan Kew L<Jonathan_Kew@sil.org>. See L<Font::TTF::Font> for copyright and
licensing.

=cut

