package Font::TTF::OldMort;

=head1 NAME

Font::TTF::OldMort - Glyph Metamorphosis table in a font

=head1 DESCRIPTION

=head1 INSTANCE VARIABLES

=item version

table version number (Fixed: currently 1.0)

=item chains

list of metamorphosis chains, each of which has its own fields:

=over

=item defaultFlags

chain's default subfeature flags (UInt32)

=item featureEntries

list of feature entries, each of which has fields:

=over

=item type

=item setting

=item enable

=item disable

=back

=item subtables

list of metamorphosis subtables, each of which has fields:

=over

=item type

subtable type (0: rearrangement; 1: contextual substitution; 2: ligature;
4: non-contextual substitution; 5: insertion)

=item direction

processing direction ('LR' or 'RL')

=item orientation

applies to text in which orientation ('VH', 'V', or 'H')

=item subFeatureFlags

the subfeature flags controlling whether the table is used (UInt32)

=back

Further fields depend on the type of subtable:

=over

Rearrangement table:

=over

=item classes

array of lists of glyphs

=item states

array of arrays of hashes{'nextState', 'flags'}

=back

Contextual substitution table:

=over

=item classes

array of lists of glyphs

=item states

array of array of hashes{'nextState', 'flags', 'actions'}, where C<actions>
is an array of two elements which are offsets to be added to [marked, current]
glyph to get index into C<mappings> (or C<undef> if no mapping to be applied)

=item mappings

list of glyph codes mapped to through the state table mappings

=back

Ligature table:

Non-contextual substitution table:

Insertion table:

=back

=back

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);
use Font::TTF::Utils;
use Font::TTF::AATutils;
use IO::File;

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
    ($self->{'version'}, $numChains) = TTF_Unpack("fL", $dat);
    
    my $chains = [];
    foreach (1 .. $numChains) {
        my $chainStart = $fh->tell();
        $fh->read($dat, 12);
        my ($defaultFlags, $chainLength, $nFeatureEntries, $nSubtables) = TTF_Unpack("LLSS", $dat);
        my $featureEntries = [];
        foreach (1 .. $nFeatureEntries) {
            $fh->read($dat, 12);
            my ($featureType, $featureSetting, $enableFlags, $disableFlags) = TTF_Unpack("SSLL", $dat);
            push @$featureEntries,    {
                                        'type'        => $featureType,
                                        'setting'    => $featureSetting,
                                        'enable'    => $enableFlags,
                                        'disable'    => $disableFlags
                                    };
        }
        my $subtables = [];
        foreach (1 .. $nSubtables) {
            my $subtableStart = $fh->tell();
            $fh->read($dat, 8);
            my ($length, $coverage, $subFeatureFlags) = TTF_Unpack("SSL", $dat);
            my $type = $coverage & 0x0007;

            my $subtable =    {
                                'type'                => $type,
                                'direction'            => (($coverage & 0x4000) ? 'RL' : 'LR'),
                                'orientation'        => (($coverage & 0x2000) ? 'VH' : ($coverage & 0x8000) ? 'V' : 'H'),
                                'subFeatureFlags'    => $subFeatureFlags
                            };

            if ($type == 0) {    # rearrangement
                my ($classes, $states) = AAT_read_state_table($fh, 0);
                $subtable->{'classes'} = $classes;
                $subtable->{'states'} = $states;
            }

            elsif ($type == 1) {    # contextual
                my $stateTableStart = $fh->tell();
                my ($classes, $states, $entries) = AAT_read_state_table($fh, 2);

                $fh->seek($stateTableStart, IO::File::SEEK_SET);
                $fh->read($dat, 10);
                my ($stateSize, $classTable, $stateArray, $entryTable, $mappingTables) = unpack("nnnnn", $dat);
                my $limits = [$classTable, $stateArray, $entryTable, $mappingTables, $length - 8];

                foreach (@$entries) {
                    my $actions = $_->{'actions'};
                    foreach (@$actions) {
                        $_ = $_ ? $_ - ($mappingTables / 2) : undef;
                    }
                }
                
                $subtable->{'classes'} = $classes;
                $subtable->{'states'} = $states;
                $subtable->{'mappings'} = [unpack("n*", AAT_read_subtable($fh, $stateTableStart, $mappingTables, $limits))];
            }

            elsif ($type == 2) {    # ligature
                my $stateTableStart = $fh->tell();
                my ($classes, $states, $entries) = AAT_read_state_table($fh, 0);
                
                $fh->seek($stateTableStart, IO::File::SEEK_SET);
                $fh->read($dat, 14);
                my ($stateSize, $classTable, $stateArray, $entryTable,
                    $ligActionTable, $componentTable, $ligatureTable) = unpack("nnnnnnn", $dat);
                my $limits = [$classTable, $stateArray, $entryTable, $ligActionTable, $componentTable, $ligatureTable, $length - 8];
                
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
                
                $subtable->{'componentTable'} = $componentTable;
                my $components = [unpack("n*", AAT_read_subtable($fh, $stateTableStart, $componentTable, $limits))];
                foreach (@$components) {
                    $_ = ($_ - $ligatureTable) . " +" if $_ >= $ligatureTable;
                }
                $subtable->{'components'} = $components;
                
                $subtable->{'ligatureTable'} = $ligatureTable;
                $subtable->{'ligatures'} = [unpack("n*", AAT_read_subtable($fh, $stateTableStart, $ligatureTable, $limits))];
                
                $subtable->{'classes'} = $classes;
                $subtable->{'states'} = $states;
                $subtable->{'actionLists'} = $actionLists;
            }

            elsif ($type == 4) {    # non-contextual
                my ($format, $lookup) = AAT_read_lookup($fh, 2, $length - 8, undef);
                $subtable->{'format'} = $format;
                $subtable->{'lookup'} = $lookup;
            }

            elsif ($type == 5) {    # insertion
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

                $subtable->{'classes'} = $classes;
                $subtable->{'states'} = $states;
                $subtable->{'insertLists'} = $insertLists;
            }

            else {
                die "unknown subtable type";
            }
            
            push @$subtables, $subtable;
            $fh->seek($subtableStart + $length, IO::File::SEEK_SET);
        }
        
        push @$chains,    {
                            'defaultFlags'        => $defaultFlags,
                            'featureEntries'    => $featureEntries,
                            'subtables'            => $subtables
                        };
        $fh->seek($chainStart + $chainLength, IO::File::SEEK_SET);
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
    $fh->print(TTF_Pack("fL", $self->{'version'}, scalar @$chains));

    foreach (@$chains) {
        my $chainStart = $fh->tell();
        my ($featureEntries, $subtables) = ($_->{'featureEntries'}, $_->{'subtables'});
        $fh->print(TTF_Pack("LLSS", $_->{'defaultFlags'}, 0, scalar @$featureEntries, scalar @$subtables)); # placeholder for length
        
        foreach (@$featureEntries) {
            $fh->print(TTF_Pack("SSLL", $_->{'type'}, $_->{'setting'}, $_->{'enable'}, $_->{'disable'}));
        }
        
        foreach (@$subtables) {
            my $subtableStart = $fh->tell();
            my $type = $_->{'type'};
            my $coverage = $type;
            $coverage += 0x4000 if $_->{'direction'} eq 'RL';
            $coverage += 0x2000 if $_->{'orientation'} eq 'VH';
            $coverage += 0x8000 if $_->{'orientation'} eq 'V';
            
            $fh->print(TTF_Pack("SSL", 0, $coverage, $_->{'subFeatureFlags'}));    # placeholder for length
            
            if ($type == 0) {    # rearrangement
                AAT_write_state_table($fh, $_->{'classes'}, $_->{'states'}, 0);
            }
            
            elsif ($type == 1) {    # contextual
                my $stHeader = $fh->tell();
                $fh->print(pack("nnnnn", (0) x 5));    # placeholders for stateSize, classTable, stateArray, entryTable, mappingTables
                
                my $classTable = $fh->tell() - $stHeader;
                my $classes = $_->{'classes'};
                AAT_write_classes($fh, $classes);
                
                my $stateArray = $fh->tell() - $stHeader;
                my $states = $_->{'states'};
                my ($stateSize, $entries) = AAT_write_states($fh, $classes, $stateArray, $states, 
                        sub {
                            my $actions = $_->{'actions'};
                            ( $_->{'flags'}, @$actions )
                        }
                    );

                my $entryTable = $fh->tell() - $stHeader;
                my $offset = ($entryTable + 8 * @$entries) / 2;
                foreach (@$entries) {
                    my ($nextState, $flags, @parts) = split /,/;
                    $fh->print(pack("nnnn", $nextState, $flags, map { $_ eq "" ? 0 : $_ + $offset } @parts));
                }

                my $mappingTables = $fh->tell() - $stHeader;
                my $mappings = $_->{'mappings'};
                $fh->print(pack("n*", @$mappings));
                
                my $loc = $fh->tell();
                $fh->seek($stHeader, IO::File::SEEK_SET);
                $fh->print(pack("nnnnn", $stateSize, $classTable, $stateArray, $entryTable, $mappingTables));
                $fh->seek($loc, IO::File::SEEK_SET);
            }
            
            elsif ($type == 2) {    # ligature
                my $stHeader = $fh->tell();
                $fh->print(pack("nnnnnnn", (0) x 7));    # placeholders for stateSize, classTable, stateArray, entryTable, actionLists, components, ligatures
            
                my $classTable = $fh->tell() - $stHeader;
                my $classes = $_->{'classes'};
                AAT_write_classes($fh, $classes);
                
                my $stateArray = $fh->tell() - $stHeader;
                my $states = $_->{'states'};
                
                my ($stateSize, $entries) = AAT_write_states($fh, $classes, $stateArray, $states,
                        sub {
                            ( $_->{'flags'} & 0xc000, $_->{'actions'} )
                        }
                    );
                
                my $actionLists = $_->{'actionLists'};
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
                my $entryTable = $fh->tell() - $stHeader;
                my $ligActionLists = ($entryTable + @$entries * 4 + 3) & ~3;
                foreach (@$entries) {
                    $_->[2] += $ligActionLists if defined $_->[2];
                    $fh->print(pack("nn", $_->[0], $_->[1] + $_->[2]));
                }
                $fh->print(pack("C*", (0) x ($ligActionLists - $entryTable - @$entries * 4)));
                
                die "internal error" if $fh->tell() != $ligActionLists + $stHeader;
                
                my $componentTable = $fh->tell() - $stHeader + $actionListDataLength;
                my $actionList;
                foreach $actionList (@actionListEntries) {
                    foreach (0 .. $#$actionList) {
                        my $action = $actionList->[$_];
                        my $val = $action->{'component'} + $componentTable / 2;
                        $val += 0x40000000 if $val < 0;
                        $val &= 0x3fffffff;
                        $val |= 0x40000000 if $action->{'store'};
                        $val |= 0x80000000 if $_ == $#$actionList;
                        $fh->print(pack("N", $val));
                    }
                }

                die "internal error" if $fh->tell() != $componentTable + $stHeader;

                my $components = $_->{'components'};
                my $ligatureTable = $componentTable + @$components * 2;
                $fh->print(pack("n*", map { (index($_, '+') >= 0 ? $ligatureTable : 0) + $_ } @$components));
                
                my $ligatures = $_->{'ligatures'};
                $fh->print(pack("n*", @$ligatures));
                
                my $loc = $fh->tell();
                $fh->seek($stHeader, IO::File::SEEK_SET);
                $fh->print(pack("nnnnnnn", $stateSize, $classTable, $stateArray, $entryTable, $ligActionLists, $componentTable, $ligatureTable));
                $fh->seek($loc, IO::File::SEEK_SET);
            }
            
            elsif ($type == 4) {    # non-contextual
                AAT_write_lookup($fh, $_->{'format'}, $_->{'lookup'}, 2, undef);
            }
            
            elsif ($type == 5) {    # insertion
            }
            
            else {
                die "unknown subtable type";
            }
            
            my $length = $fh->tell() - $subtableStart;
            my $padBytes = (4 - ($length & 3)) & 3;
            $fh->print(pack("C*", (0) x $padBytes));
            $length += $padBytes;
            $fh->seek($subtableStart, IO::File::SEEK_SET);
            $fh->print(pack("n", $length));
            $fh->seek($subtableStart + $length, IO::File::SEEK_SET);
        }
        
        my $chainLength = $fh->tell() - $chainStart;
        $fh->seek($chainStart + 4, IO::File::SEEK_SET);
        $fh->print(pack("N", $chainLength));
        $fh->seek($chainStart + $chainLength, IO::File::SEEK_SET);
    }
}

=head2 $t->print($fh)

Prints a human-readable representation of the table

=cut

sub print
{
    my ($self, $fh) = @_;
    
    $self->read;
    my $feat = $self->{' PARENT'}->{'feat'};
    $feat->read;
    my $post = $self->{' PARENT'}->{'post'};
    $post->read;
    
    $fh = 'STDOUT' unless defined $fh;

    $fh->printf("version %f\n", $self->{'version'});
    
    my $chains = $self->{'chains'};
    foreach (@$chains) {
        my $defaultFlags = $_->{'defaultFlags'};
        $fh->printf("chain: defaultFlags = %08x\n", $defaultFlags);
        
        my $featureEntries = $_->{'featureEntries'};
        foreach (@$featureEntries) {
            $fh->printf("\tfeature %d, setting %d : enableFlags = %08x, disableFlags = %08x # '%s: %s'\n",
                        $_->{'type'}, $_->{'setting'}, $_->{'enable'}, $_->{'disable'},
                        $feat->settingName($_->{'type'}, $_->{'setting'}));
        }
        
        my $subtables = $_->{'subtables'};
        foreach (@$subtables) {
            my $type = $_->{'type'};
            my $subFeatureFlags = $_->{'subFeatureFlags'};
            $fh->printf("\n\t%s table, %s, %s, subFeatureFlags = %08x # %s (%s)\n",
                        subtable_type_($type), $_->{'direction'}, $_->{'orientation'}, $subFeatureFlags,
                        "Default " . ((($subFeatureFlags & $defaultFlags) != 0) ? "On" : "Off"),
                        join(", ",
                            map {
                                join(": ", $feat->settingName($_->{'type'}, $_->{'setting'}) )
                            } grep { ($_->{'enable'} & $subFeatureFlags) != 0 } @$featureEntries
                        ) );
            
            if ($type == 0) {    # rearrangement
                print_classes_($fh, $_, $post);

                $fh->print("\n");
                my $states = $_->{'states'};
                my @verbs = (    "0", "Ax->xA", "xD->Dx", "AxD->DxA",
                                "ABx->xAB", "ABx->xBA", "xCD->CDx", "xCD->DCx",
                                "AxCD->CDxA", "AxCD->DCxA", "ABxD->DxAB", "ABxD->DxBA",
                                "ABxCD->CDxAB", "ABxCD->CDxBA", "ABxCD->DCxAB", "ABxCD->DCxBA");
                foreach (0 .. $#$states) {
                    $fh->printf("\t\tState %d:", $_);
                    my $state = $states->[$_];
                    foreach (@$state) {
                        my $flags;
                        $flags .= "!" if ($_->{'flags'} & 0x4000);
                        $flags .= "<" if ($_->{'flags'} & 0x8000);
                        $flags .= ">" if ($_->{'flags'} & 0x2000);
                        $fh->printf("\t(%s%d,%s)", $flags, $_->{'nextState'}, $verbs[($_->{'flags'} & 0x000f)]);
                    }
                    $fh->print("\n");
                }
            }
            
            elsif ($type == 1) {    # contextual
                print_classes_($fh, $_, $post);
                
                $fh->print("\n");
                my $states = $_->{'states'};
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
                my $mappings = $_->{'mappings'};
                foreach (0 .. $#$mappings) {
                    $fh->printf("\t\tMapping %d: %d [%s]\n", $_, $mappings->[$_], $post->{'VAL'}[$mappings->[$_]]);
                }
            }
            
            elsif ($type == 2) {    # ligature
                print_classes_($fh, $_, $post);
                
                $fh->print("\n");
                my $states = $_->{'states'};
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
                my $actionLists = $_->{'actionLists'};
                foreach (0 .. $#$actionLists) {
                    $fh->printf("\t\tList %d:\t", $_);
                    my $actionList = $actionLists->[$_];
                    $fh->printf("%s\n", join(", ", map { ($_->{'component'} . ($_->{'store'} ? "*" : "") ) } @$actionList));
                }

                my $ligatureTable = $_->{'ligatureTable'};

                $fh->print("\n");
                my $components = $_->{'components'};
                foreach (0 .. $#$components) {
                    $fh->printf("\t\tComponent %d: %s\n", $_, $components->[$_]);
                }
                
                $fh->print("\n");
                my $ligatures = $_->{'ligatures'};
                foreach (0 .. $#$ligatures) {
                    $fh->printf("\t\tLigature %d: %d [%s]\n", $_, $ligatures->[$_], $post->{'VAL'}[$ligatures->[$_]]);
                }
            }
            
            elsif ($type == 4) {    # non-contextual
                my $lookup = $_->{'lookup'};
                $fh->printf("\t\tLookup format %d\n", $_->{'format'});
                if (defined $lookup) {
                    foreach (sort { $a <=> $b } keys %$lookup) {
                        $fh->printf("\t\t\t%d [%s] -> %d [%s])\n", $_, $post->{'VAL'}[$_], $lookup->{$_}, $post->{'VAL'}[$lookup->{$_}]);
                    }
                }
            }
            
            elsif ($type == 5) {    # insertion
                print_classes_($fh, $_, $post);
                
                $fh->print("\n");
                my $states = $_->{'states'};
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
                my $insertLists = $_->{'insertLists'};
                foreach (0 .. $#$insertLists) {
                    my $insertList = $insertLists->[$_];
                    $fh->printf("\t\tList %d: %s\n", $_, join(", ", map { $_ . " [" . $post->{'VAL'}[$_] . "]" } @$insertList));
                }
            }
            
            else {
                # unknown
            }
        }
    }
}

sub print_classes_
{
    my ($fh, $subtable, $post) = @_;
    
    my $classes = $subtable->{'classes'};
    foreach (0 .. $#$classes) {
        my $class = $classes->[$_];
        if (defined $class) {
            $fh->printf("\t\tClass %d:\t%s\n", $_, join(", ", map { $_ . " [" . $post->{'VAL'}[$_] . "]" } @$class));
        }
    }
}

sub subtable_type_
{
    my ($val) = @_;
    my ($res);
    
    my @types =    (
                    'Rearrangement',
                    'Contextual',
                    'Ligature',
                    undef,
                    'Non-contextual',
                    'Insertion',
                );
    $res = $types[$val] or ('Undefined (' . $val . ')');
    
    $res;
}

1;

=head1 BUGS

None known

=head1 AUTHOR

Jonathan Kew L<Jonathan_Kew@sil.org>. See L<Font::TTF::Font> for copyright and
licensing.

=cut

