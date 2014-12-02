package Font::TTF::Kern::StateTable;

=head1 NAME

Font::TTF::Kern::StateTable - State Table Kern subtable for AAT

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);
use Font::TTF::Utils;
use Font::TTF::AATutils;
use Font::TTF::Kern::Subtable;
use IO::File;

@ISA = qw(Font::TTF::Kern::Subtable);

sub new
{
    my ($class) = @_;
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
    my ($dat);
    
    my $stTableStart = $fh->tell();

    my ($classes, $states, $entries) = AAT_read_state_table($fh, 0);

    foreach (@$entries) {
        my $flags = $_->{'flags'};
        delete $_->{'flags'};
        $_->{'push'} = 1        if $flags & 0x8000;
        $_->{'noAdvance'} = 1    if $flags & 0x4000;
        $flags &= ~0xC000;
        if ($flags != 0) {
            my $kernList = [];
            $fh->seek($stTableStart + $flags, IO::File::SEEK_SET);
            while (1) {
                $fh->read($dat, 2);
                my $k = TTF_Unpack("s", $dat);
                push @$kernList, ($k & ~1);
                last if ($k & 1) != 0;
            }
            $_->{'kernList'} = $kernList;
        }
    }

    $self->{'classes'} = $classes;
    $self->{'states'} = $states;
    $self->{'entries'} = $entries;

    $fh->seek($stTableStart - 8 + $self->{'length'}, IO::File::SEEK_SET);
    
    $self;
}

=head2 $t->out_sub($fh)

Writes the table to a file

=cut

sub out_sub
{
}

=head2 $t->print($fh)

Prints a human-readable representation of the table

=cut

sub print
{
}

sub dumpXML
{
    my ($self, $fh) = @_;
    
    $fh->printf("<classes>\n");
    $self->dumpClasses($self->{'classes'}, $fh);
    $fh->printf("</classes>\n");

    $fh->printf("<states>\n");
    my $states = $self->{'states'};
    foreach (0 .. $#$states) {
        $fh->printf("<state index=\"%s\">\n", $_);
        my $members = $states->[$_];
        foreach (0 .. $#$members) {
            my $m = $members->[$_];
            $fh->printf("<m index=\"%s\" nextState=\"%s\"", $_, $m->{'nextState'});
            $fh->printf(" push=\"1\"")        if $m->{'push'};
            $fh->printf(" noAdvance=\"1\"")    if $m->{'noAdvance'};
            if (exists $m->{'kernList'}) {
                $fh->printf(">");
                foreach (@{$m->{'kernList'}}) {
                    $fh->printf("<kern v=\"%s\"/>", $_);
                }
                $fh->printf("</m>\n");
            }
            else {
                $fh->printf("/>\n");
            }
        }
        $fh->printf("</state>\n");
    }
    $fh->printf("</states>\n");
}

sub type
{
    return 'kernStateTable';
}

1;

=head1 BUGS

None known

=head1 AUTHOR

Jonathan Kew L<Jonathan_Kew@sil.org>. See L<Font::TTF::Font> for copyright and
licensing.

=cut

