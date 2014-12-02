package Font::TTF::Mort::Noncontextual;

=head1 NAME

Font::TTF::Mort::Noncontextual - Noncontextual Mort subtable for AAT

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);
use Font::TTF::Utils;
use Font::TTF::AATutils;

@ISA = qw(Font::TTF::Mort::Subtable);

sub new
{
    my ($class, $direction, $orientation, $subFeatureFlags) = @_;
    my ($self) = {
                    'direction'            => $direction,
                    'orientation'        => $orientation,
                    'subFeatureFlags'    => $subFeatureFlags
                };

    $class = ref($class) || $class;
    bless $self, $class;
}

=head2 $t->read

Reads the table into memory

=cut

sub read
{
    my ($self, $fh) = @_;
    my ($dat);
    
    my ($format, $lookup) = AAT_read_lookup($fh, 2, $self->{'length'} - 8, undef);
    $self->{'format'} = $format;
    $self->{'lookup'} = $lookup;

    $self;
}

=head2 $t->pack_sub($fh)

=cut

sub pack_sub
{
    my ($self) = @_;
    
    return AAT_pack_lookup($self->{'format'}, $self->{'lookup'}, 2, undef);
}

=head2 $t->print($fh)

Prints a human-readable representation of the table

=cut

sub print
{
    my ($self, $fh) = @_;
    
    my $post = $self->post();
    
    $fh = 'STDOUT' unless defined $fh;

    my $lookup = $self->{'lookup'};
    $fh->printf("\t\tLookup format %d\n", $self->{'format'});
    if (defined $lookup) {
        foreach (sort { $a <=> $b } keys %$lookup) {
            $fh->printf("\t\t\t%d [%s] -> %d [%s])\n", $_, $post->{'VAL'}[$_], $lookup->{$_}, $post->{'VAL'}[$lookup->{$_}]);
        }
    }
}

1;

=head1 BUGS

None known

=head1 AUTHOR

Jonathan Kew L<Jonathan_Kew@sil.org>. See L<Font::TTF::Font> for copyright and
licensing.

=cut

