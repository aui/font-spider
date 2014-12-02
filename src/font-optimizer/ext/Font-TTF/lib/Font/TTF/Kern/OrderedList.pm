package Font::TTF::Kern::OrderedList;

=head1 NAME

Font::TTF::Kern::OrderedList - Ordered List Kern subtable for AAT

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);
use Font::TTF::Utils;
use Font::TTF::AATutils;

@ISA = qw(Font::TTF::Kern::Subtable);

sub new
{
    my ($class, @options) = @_;
    my ($self) = {};
    
    $class = ref($class) || $class;
    bless $self, $class;
}

=head2 $t->read

Reads the table into memory

=cut

sub read
{
    my ($self, $fh) = @_;
 
    my $dat;
    $fh->read($dat, 8);
    my ($nPairs, $searchRange, $entrySelector, $rangeShift) = unpack("nnnn", $dat);

    my $pairs = [];
    foreach (1 .. $nPairs) {
        $fh->read($dat, 6);
        my ($left, $right, $kern) = TTF_Unpack("SSs", $dat);
        push @$pairs, { 'left' => $left, 'right' => $right, 'kern' => $kern } if $kern != 0;
    }
    
    $self->{'kernPairs'} = $pairs;
    
    $self;
}

=head2 $t->out_sub($fh)

Writes the table to a file

=cut

sub out_sub
{
    my ($self, $fh) = @_;
    
    my $pairs = $self->{'kernPairs'};
    $fh->print(pack("nnnn", TTF_bininfo(scalar @$pairs, 6)));
    
    foreach (sort { $a->{'left'} <=> $b->{'left'} or $a->{'right'} <=> $b->{'right'} } @$pairs) {
        $fh->print(TTF_Pack("SSs", $_->{'left'}, $_->{'right'}, $_->{'kern'}));
    }
}

=head2 $t->print($fh)

Prints a human-readable representation of the table

=cut

sub dumpXML
{
    my ($self, $fh) = @_;
    
    my $postVal = $self->post()->{'VAL'};
    
    $fh = 'STDOUT' unless defined $fh;
    foreach (@{$self->{'kernPairs'}}) {
        $fh->printf("<pair l=\"%s\" r=\"%s\" v=\"%s\"/>\n", $postVal->[$_->{'left'}], $postVal->[$_->{'right'}], $_->{'kern'});
    }
}


sub type
{
    return 'kernOrderedList';
}


1;

=head1 BUGS

None known

=head1 AUTHOR

Jonathan Kew L<Jonathan_Kew@sil.org>. See L<Font::TTF::Font> for copyright and
licensing.

=cut

