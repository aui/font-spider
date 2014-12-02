package Font::TTF::Mort::Contextual;

=head1 NAME

Font::TTF::Mort::Contextual - Contextual Mort subtable for AAT

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);
use Font::TTF::Utils;
use Font::TTF::AATutils;
use Font::TTF::Mort::Subtable;
use IO::File;

@ISA = qw(Font::TTF::AAT::Mort::Subtable);

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
    
    my $stateTableStart = $fh->tell();
    my ($classes, $states, $entries) = AAT_read_state_table($fh, 2);

    $fh->seek($stateTableStart, IO::File::SEEK_SET);
    $fh->read($dat, 10);
    my ($stateSize, $classTable, $stateArray, $entryTable, $mappingTables) = unpack("nnnnn", $dat);
    my $limits = [$classTable, $stateArray, $entryTable, $mappingTables, $self->{'length'} - 8];

    foreach (@$entries) {
        my $actions = $_->{'actions'};
        foreach (@$actions) {
            $_ = $_ ? $_ - ($mappingTables / 2) : undef;
        }
    }
    
    $self->{'classes'} = $classes;
    $self->{'states'} = $states;
    $self->{'mappings'} = [unpack("n*", AAT_read_subtable($fh, $stateTableStart, $mappingTables, $limits))];
            
    $self;
}

=head2 $t->pack_sub()

=cut

sub pack_sub
{
    my ($self) = @_;
    
    my ($dat) = pack("nnnnn", (0) x 5);    # placeholders for stateSize, classTable, stateArray, entryTable, mappingTables
    
    my $classTable = length($dat);
    my $classes = $self->{'classes'};
    $dat .= AAT_pack_classes($classes);
    
    my $stateArray = length($dat);
    my $states = $self->{'states'};
    my ($dat1, $stateSize, $entries) = AAT_pack_states($classes, $stateArray, $states, 
            sub {
                my $actions = $_->{'actions'};
                ( $_->{'flags'}, @$actions )
            }
        );
    $dat .= $dat1;
    
    my $entryTable = length($dat);
    my $offset = ($entryTable + 8 * @$entries) / 2;
    foreach (@$entries) {
        my ($nextState, $flags, @parts) = split /,/;
        $dat .= pack("nnnn", $nextState, $flags, map { $_ eq "" ? 0 : $_ + $offset } @parts);
    }

    my $mappingTables = length($dat);
    my $mappings = $self->{'mappings'};
    $dat .= pack("n*", @$mappings);
    
    $dat1 = pack("nnnnn", $stateSize, $classTable, $stateArray, $entryTable, $mappingTables);
    substr($dat, 0, length($dat1)) = $dat1;
    
    return $dat;
}

=head2 $t->print($fh)

Prints a human-readable representation of the table

=cut

sub print
{
    my ($self, $fh) = @_;
    
    my $post = $self->post();
    
    $fh = 'STDOUT' unless defined $fh;

    $self->print_classes($fh);
    
    $fh->print("\n");
    my $states = $self->{'states'};
    foreach (0 .. $#$states) {
        $fh->printf("\t\tState %d:", $_);
        my $state = $states->[$_];
        foreach (@$state) {
            my $flags;
            $flags .= "!" if ($_->{'flags'} & 0x4000);
            $flags .= "*" if ($_->{'flags'} & 0x8000);
            my $actions = $_->{'actions'};
            $fh->printf("\t(%s%d,%s,%s)", $flags, $_->{'nextState'}, map { defined $_ ? $_ : "=" } @$actions);
        }
        $fh->print("\n");
    }

    $fh->print("\n");
    my $mappings = $self->{'mappings'};
    foreach (0 .. $#$mappings) {
        $fh->printf("\t\tMapping %d: %d [%s]\n", $_, $mappings->[$_], $post->{'VAL'}[$mappings->[$_]]);
    }
}

1;

=head1 BUGS

None known

=head1 AUTHOR

Jonathan Kew L<Jonathan_Kew@sil.org>. See L<Font::TTF::Font> for copyright and
licensing.

=cut

