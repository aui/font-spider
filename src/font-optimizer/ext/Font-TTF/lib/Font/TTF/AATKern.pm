package Font::TTF::AATKern;

=head1 NAME

Font::TTF::AATKern - AAT Kern table

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);
use Font::TTF::Utils;
use Font::TTF::AATutils;
use Font::TTF::Kern::Subtable;

@ISA = qw(Font::TTF::Table);

=head2 $t->read

Reads the table into memory

=cut

sub read
{
    my ($self) = @_;
    
    $self->SUPER::read or return $self;

    my ($dat, $fh, $numSubtables);
    $fh = $self->{' INFILE'};

    $fh->read($dat, 8);
    ($self->{'version'}, $numSubtables) = TTF_Unpack("vL", $dat);
    
    my $subtables = [];
    foreach (1 .. $numSubtables) {
        my $subtableStart = $fh->tell();
        
        $fh->read($dat, 8);
        my ($length, $coverage, $tupleIndex) = TTF_Unpack("LSS", $dat);
        my $type = $coverage & 0x00ff;

        my $subtable = Font::TTF::Kern::Subtable->create($type, $coverage, $length);
        $subtable->read($fh);

        $subtable->{'tupleIndex'} = $tupleIndex if $subtable->{'variation'};
        $subtable->{' PARENT'} = $self;
        push @$subtables, $subtable;
    }

    $self->{'subtables'} = $subtables;

    $self;
}

=head2 $t->out($fh)

Writes the table to a file either from memory or by copying

=cut

sub out
{
    my ($self, $fh) = @_;
    
    return $self->SUPER::out($fh) unless $self->{' read'};

    my $subtables = $self->{'subtables'};
    $fh->print(TTF_Pack("vL", $self->{'version'}, scalar @$subtables));

    foreach (@$subtables) {
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
    
    $fh = 'STDOUT' unless defined $fh;

    $fh->printf("version %f\n", $self->{'version'});
    
    my $subtables = $self->{'subtables'};
    foreach (@$subtables) {
        $_->print($fh);
    }
}

sub dumpXML
{
    my ($self, $fh) = @_;
    $self->read unless $self->{' read'};

    my $post = $self->{' PARENT'}->{'post'};
    $post->read;
    
    $fh = 'STDOUT' unless defined $fh;
    $fh->printf("<kern version=\"%f\">\n", $self->{'version'});
    
    my $subtables = $self->{'subtables'};
    foreach (@$subtables) {
        $fh->printf("<%s", $_->type);
        $fh->printf(" vertical=\"1\"") if $_->{'vertical'};
        $fh->printf(" crossStream=\"1\"") if $_->{'crossStream'};
        $fh->printf(" variation=\"1\"") if $_->{'variation'};
        $fh->printf(" tupleIndex=\"%s\"", $_->{'tupleIndex'}) if exists $_->{'tupleIndex'};
        $fh->printf(">\n");

        $_->dumpXML($fh);

        $fh->printf("</%s>\n", $_->type);
    }

    $fh->printf("</kern>\n");
}

1;

=head1 BUGS

None known

=head1 AUTHOR

Jonathan Kew L<Jonathan_Kew@sil.org>. See L<Font::TTF::Font> for copyright and
licensing.

=cut

