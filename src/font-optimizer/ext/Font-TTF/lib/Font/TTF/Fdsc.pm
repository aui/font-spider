package Font::TTF::Fdsc;

=head1 NAME

Font::TTF::Fdsc - Font Descriptors table in a font

=head1 DESCRIPTION

=head1 INSTANCE VARIABLES

=item version

=item descriptors

Hash keyed by descriptor tags

=head1 METHODS

=cut

use strict;
use vars qw(@ISA %fields);
use Font::TTF::Utils;

@ISA = qw(Font::TTF::Table);

=head2 $t->read

Reads the table into memory

=cut

sub read
{
    my ($self) = @_;
    my ($dat, $fh, $numDescs, $tag, $descs);

    $self->SUPER::read or return $self;

    $fh = $self->{' INFILE'};
    $fh->read($dat, 4);
    $self->{'version'} = TTF_Unpack("v", $dat);

    $fh->read($dat, 4);

    foreach (1 .. unpack("N", $dat)) {
        $fh->read($tag, 4);
        $fh->read($dat, 4);
        $descs->{$tag} = ($tag eq 'nalf') ? unpack("N", $dat) : TTF_Unpack("f", $dat);
    }

    $self->{'descriptors'} = $descs;

    $self;
}


=head2 $t->out($fh)

Writes the table to a file either from memory or by copying

=cut

sub out
{
    my ($self, $fh) = @_;
    my ($descs);

    return $self->SUPER::out($fh) unless $self->{' read'};
    
    $fh->print(TTF_Pack("v", $self->{'version'}));
    
    $descs = $self->{'descriptors'} or {};
    
    $fh->print(pack("N", scalar keys %$descs));    
    foreach (sort keys %$descs) {
        $fh->print($_);
        $fh->print(($_ eq 'nalf') ? pack("N", $descs->{$_}) : TTF_Pack("f", $descs->{$_}));
    }

    $self;
}

=head2 $t->print($fh)

Prints a human-readable representation of the table

=cut

sub print
{
    my ($self, $fh) = @_;
    my ($descs, $k);

    $self->read;

    $fh = 'STDOUT' unless defined $fh;

    $descs = $self->{'descriptors'};
    foreach $k (sort keys %$descs) {
        if ($k eq 'nalf') {
            $fh->printf("Descriptor '%s' = %d\n", $k, $descs->{$k});
        }
        else {
            $fh->printf("Descriptor '%s' = %f\n", $k, $descs->{$k});
        }
    }
    
    $self;
}

1;


=head1 BUGS

None known

=head1 AUTHOR

Jonathan Kew L<Jonathan_Kew@sil.org>. See L<Font::TTF::Font> for copyright and
licensing.

=cut

