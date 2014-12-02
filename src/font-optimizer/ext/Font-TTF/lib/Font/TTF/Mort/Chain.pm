package Font::TTF::Mort::Chain;

=head1 NAME

Font::TTF::Mort::Chain - Chain Mort subtable for AAT

=cut

use strict;
use Font::TTF::Utils;
use Font::TTF::AATutils;
use Font::TTF::Mort::Subtable;
use IO::File;

=head2 $t->new

=cut

sub new
{
    my ($class, %parms) = @_;
    my ($self) = {};
    my ($p);

    $class = ref($class) || $class;
    foreach $p (keys %parms)
    { $self->{" $p"} = $parms{$p}; }
    bless $self, $class;
}

=head2 $t->read($fh)

Reads the chain into memory

=cut

sub read
{
    my ($self, $fh) = @_;
    my ($dat);

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

        my $subtable = Font::TTF::Mort::Subtable->create($type, $coverage, $subFeatureFlags, $length);
        $subtable->read($fh);
        $subtable->{' PARENT'} = $self;
        
        push @$subtables, $subtable;
        $fh->seek($subtableStart + $length, IO::File::SEEK_SET);
    }
    
    $self->{'defaultFlags'} = $defaultFlags;
    $self->{'featureEntries'} = $featureEntries;
    $self->{'subtables'} = $subtables;

    $fh->seek($chainStart + $chainLength, IO::File::SEEK_SET);

    $self;
}

=head2 $t->out($fh)

Writes the table to a file either from memory or by copying

=cut

sub out
{
    my ($self, $fh) = @_;
    
    my $chainStart = $fh->tell();
    my ($featureEntries, $subtables) = ($_->{'featureEntries'}, $_->{'subtables'});
    $fh->print(TTF_Pack("LLSS", $_->{'defaultFlags'}, 0, scalar @$featureEntries, scalar @$subtables)); # placeholder for length
    
    foreach (@$featureEntries) {
        $fh->print(TTF_Pack("SSLL", $_->{'type'}, $_->{'setting'}, $_->{'enable'}, $_->{'disable'}));
    }
    
    foreach (@$subtables) {
        $_->out($fh);
    }
    
    my $chainLength = $fh->tell() - $chainStart;
    $fh->seek($chainStart + 4, IO::File::SEEK_SET);
    $fh->print(pack("N", $chainLength));
    $fh->seek($chainStart + $chainLength, IO::File::SEEK_SET);
}

=head2 $t->print($fh)

Prints a human-readable representation of the chain

=cut

sub feat
{
    my ($self) = @_;
    
    my $feat = $self->{' PARENT'}{' PARENT'}{'feat'};
    if (defined $feat) {
        $feat->read;
    }
    else {
        $feat = {};
    }
    
    return $feat;
}

sub print
{
    my ($self, $fh) = @_;
    
    $fh->printf("version %f\n", $self->{'version'});
    
    my $defaultFlags = $self->{'defaultFlags'};
    $fh->printf("chain: defaultFlags = %08x\n", $defaultFlags);
    
    my $feat = $self->feat();
    my $featureEntries = $self->{'featureEntries'};
    foreach (@$featureEntries) {
        $fh->printf("\tfeature %d, setting %d : enableFlags = %08x, disableFlags = %08x # '%s: %s'\n",
                    $_->{'type'}, $_->{'setting'}, $_->{'enable'}, $_->{'disable'},
                    $feat->settingName($_->{'type'}, $_->{'setting'}));
    }
    
    my $subtables = $self->{'subtables'};
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
        
        $_->print($fh);
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

