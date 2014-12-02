package Font::TTF::Mort::Insertion;

=head1 NAME

Font::TTF::Mort::Insertion - Insertion Mort subtable for AAT

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);
use Font::TTF::Utils;
use Font::TTF::AATutils;
use IO::File;

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
    
    my $subtableStart = $fh->tell();

    my $stateTableStart = $fh->tell();
    my ($classes, $states, $entries) = AAT_read_state_table($fh, 2);
    
    my %insertListHash;
    my $insertLists;
    foreach (@$entries) {
        my $flags = $_->{'flags'};
        my @insertCount = (($flags & 0x03e0) >> 5, ($flags & 0x001f));
        my $actions = $_->{'actions'};
        foreach (0 .. 1) {
            if ($insertCount[$_] > 0) {
                $fh->seek($stateTableStart + $actions->[$_], IO::File::SEEK_SET);
                $fh->read($dat, $insertCount[$_] * 2);
                if (not defined $insertListHash{$dat}) {
                    push @$insertLists, [unpack("n*", $dat)];
                    $insertListHash{$dat} = $#$insertLists;
                }
                $actions->[$_] = $insertListHash{$dat};
            }
            else {
                $actions->[$_] = undef;
            }
        }
    }

    $self->{'classes'} = $classes;
    $self->{'states'} = $states;
    $self->{'insertLists'} = $insertLists;
            
    $self;
}

=head2 $t->pack_sub()

=cut

sub pack_sub
{
    my ($self) = @_;
    
    my ($dat) = pack("nnnn", (0) x 4);
    
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
    my $offset = ($entryTable + 8 * @$entries);
    my @insListOffsets;
    my $insertLists = $self->{'insertLists'};
    foreach (@$insertLists) {
        push @insListOffsets, $offset;
        $offset += 2 * scalar @$_;
    }
    foreach (@$entries) {
        my ($nextState, $flags, @lists) = split /,/;
        $flags &= ~0x03ff;
        $flags |= (scalar @{$insertLists->[$lists[0]]}) << 5 if $lists[0] ne '';
        $flags |= (scalar @{$insertLists->[$lists[1]]}) if $lists[1] ne '';
        $dat .= pack("nnnn", $nextState, $flags,
                    map { $_ eq '' ? 0 : $insListOffsets[$_] } @lists);
    }
    
    foreach (@$insertLists) {
        $dat .= pack("n*", @$_);
    }

    $dat1 = pack("nnnn", $stateSize, $classTable, $stateArray, $entryTable);
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
    my $insertLists = $self->{'insertLists'};
    foreach (0 .. $#$insertLists) {
        my $insertList = $insertLists->[$_];
        $fh->printf("\t\tList %d: %s\n", $_, join(", ", map { $_ . " [" . $post->{'VAL'}[$_] . "]" } @$insertList));
    }
}

1;

=head1 BUGS

None known

=head1 AUTHOR

Jonathan Kew L<Jonathan_Kew@sil.org>. See L<Font::TTF::Font> for copyright and
licensing.

=cut

