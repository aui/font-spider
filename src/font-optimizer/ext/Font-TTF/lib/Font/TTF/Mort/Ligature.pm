package Font::TTF::Mort::Ligature;

=head1 NAME

Font::TTF::Mort::Ligature - Ligature Mort subtable for AAT

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

    my $stateTableStart = $fh->tell();
    my ($classes, $states, $entries) = AAT_read_state_table($fh, 0);
    
    $fh->seek($stateTableStart, IO::File::SEEK_SET);
    $fh->read($dat, 14);
    my ($stateSize, $classTable, $stateArray, $entryTable,
        $ligActionTable, $componentTable, $ligatureTable) = unpack("nnnnnnn", $dat);
    my $limits = [$classTable, $stateArray, $entryTable, $ligActionTable, $componentTable, $ligatureTable, $self->{'length'} - 8];
    
    my %actions;
    my $actionLists;
    foreach (@$entries) {
        my $offset = $_->{'flags'} & 0x3fff;
        $_->{'flags'} &= ~0x3fff;
        if ($offset != 0) {
            if (not defined $actions{$offset}) {
                $fh->seek($stateTableStart + $offset, IO::File::SEEK_SET);
                my $actionList;
                while (1) {
                    $fh->read($dat, 4);
                    my $action = unpack("N", $dat);
                    my ($last, $store, $component) = (($action & 0x80000000) != 0, ($action & 0xC0000000) != 0, ($action & 0x3fffffff));
                    $component -= 0x40000000 if $component > 0x1fffffff;
                    $component -= $componentTable / 2;
                    push @$actionList, { 'store' => $store, 'component' => $component };
                    last if $last;
                }
                push @$actionLists, $actionList;
                $actions{$offset} = $#$actionLists;
            }
            $_->{'actions'} = $actions{$offset};
        }
    }
    
    $self->{'componentTable'} = $componentTable;
    my $components = [unpack("n*", AAT_read_subtable($fh, $stateTableStart, $componentTable, $limits))];
    foreach (@$components) {
        $_ = ($_ - $ligatureTable) . " +" if $_ >= $ligatureTable;
    }
    $self->{'components'} = $components;
    
    $self->{'ligatureTable'} = $ligatureTable;
    $self->{'ligatures'} = [unpack("n*", AAT_read_subtable($fh, $stateTableStart, $ligatureTable, $limits))];
    
    $self->{'classes'} = $classes;
    $self->{'states'} = $states;
    $self->{'actionLists'} = $actionLists;
        
    $self;
}

=head2 $t->pack_sub($fh)

=cut

sub pack_sub
{
    my ($self) = @_;
    my ($dat);
    
    $dat .= pack("nnnnnnn", (0) x 7);    # placeholders for stateSize, classTable, stateArray, entryTable, actionLists, components, ligatures

    my $classTable = length($dat);
    my $classes = $self->{'classes'};
    $dat .= AAT_pack_classes($classes);
    
    my $stateArray = length($dat);
    my $states = $self->{'states'};
    
    my ($dat1, $stateSize, $entries) = AAT_pack_states($classes, $stateArray, $states,
            sub {
                ( $_->{'flags'} & 0xc000, $_->{'actions'} )
            }
        );
    $dat .= $dat1;
    
    my $actionLists = $self->{'actionLists'};
    my %actionListOffset;
    my $actionListDataLength = 0;
    my @actionListEntries;
    foreach (0 .. $#$entries) {
        my ($nextState, $flags, $offset) = split(/,/, $entries->[$_]);
        if ($offset eq "") {
            $offset = undef;
        }
        else {
            if (defined $actionListOffset{$offset}) {
                $offset = $actionListOffset{$offset};
            }
            else {
                $actionListOffset{$offset} = $actionListDataLength;
                my $list = $actionLists->[$offset];
                $actionListDataLength += 4 * @$list;
                push @actionListEntries, $list;
                $offset = $actionListOffset{$offset};
            }
        }
        $entries->[$_] = [ $nextState, $flags, $offset ];
    }
    my $entryTable = length($dat);
    my $ligActionLists = ($entryTable + @$entries * 4 + 3) & ~3;
    foreach (@$entries) {
        $_->[2] += $ligActionLists if defined $_->[2];
        $dat .= pack("nn", $_->[0], $_->[1] + $_->[2]);
    }
    $dat .= pack("C*", (0) x ($ligActionLists - $entryTable - @$entries * 4));
    
    die "internal error" unless length($dat) == $ligActionLists;
    
    my $componentTable = length($dat) + $actionListDataLength;
    my $actionList;
    foreach $actionList (@actionListEntries) {
        foreach (0 .. $#$actionList) {
            my $action = $actionList->[$_];
            my $val = $action->{'component'} + $componentTable / 2;
            $val += 0x40000000 if $val < 0;
            $val &= 0x3fffffff;
            $val |= 0x40000000 if $action->{'store'};
            $val |= 0x80000000 if $_ == $#$actionList;
            $dat .= pack("N", $val);
        }
    }

    die "internal error" unless length($dat) == $componentTable;

    my $components = $self->{'components'};
    my $ligatureTable = $componentTable + @$components * 2;
    $dat .= pack("n*", map { (index($_, '+') >= 0 ? $ligatureTable : 0) + $_ } @$components);
    
    my $ligatures = $self->{'ligatures'};
    $dat .= pack("n*", @$ligatures);
    
    $dat1 = pack("nnnnnnn", $stateSize, $classTable, $stateArray, $entryTable, $ligActionLists, $componentTable, $ligatureTable);
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
            $fh->printf("\t(%s%d,%s)", $flags, $_->{'nextState'}, defined $_->{'actions'} ? $_->{'actions'} : "=");
        }
        $fh->print("\n");
    }

    $fh->print("\n");
    my $actionLists = $self->{'actionLists'};
    foreach (0 .. $#$actionLists) {
        $fh->printf("\t\tList %d:\t", $_);
        my $actionList = $actionLists->[$_];
        $fh->printf("%s\n", join(", ", map { ($_->{'component'} . ($_->{'store'} ? "*" : "") ) } @$actionList));
    }

    my $ligatureTable = $self->{'ligatureTable'};

    $fh->print("\n");
    my $components = $self->{'components'};
    foreach (0 .. $#$components) {
        $fh->printf("\t\tComponent %d: %s\n", $_, $components->[$_]);
    }
    
    $fh->print("\n");
    my $ligatures = $self->{'ligatures'};
    foreach (0 .. $#$ligatures) {
        $fh->printf("\t\tLigature %d: %d [%s]\n", $_, $ligatures->[$_], $post->{'VAL'}[$ligatures->[$_]]);
    }
}

1;

=head1 BUGS

None known

=head1 AUTHOR

Jonathan Kew L<Jonathan_Kew@sil.org>. See L<Font::TTF::Font> for copyright and
licensing.

=cut

