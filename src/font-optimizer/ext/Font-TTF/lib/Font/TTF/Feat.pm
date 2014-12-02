package Font::TTF::Feat;

=head1 NAME

Font::TTF::Feat - Font Features

=head1 DESCRIPTION

=head1 INSTANCE VARIABLES

=over 4

=item version

=item features

An array of hashes of the following form

=over 8

=item feature

feature id number

=item name

name index in name table

=item exclusive

exclusive flag

=item settings

hash of setting number against name string index

=back

=back

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);

use Font::TTF::Utils;

require Font::TTF::Table;

@ISA = qw(Font::TTF::Table);

=head2 $t->read

Reads the features from the TTF file into memory

=cut

sub read
{
    my ($self) = @_;
    my ($featureCount, $features);

    $self->SUPER::read_dat or return $self;

    ($self->{'version'}, $featureCount) = TTF_Unpack("vS", $self->{' dat'});

    $features = [];
    foreach (1 .. $featureCount) {
        my ($feature, $nSettings, $settingTable, $featureFlags, $nameIndex)
                = TTF_Unpack("SSLSS", substr($self->{' dat'}, $_ * 12, 12));
        push @$features,
            {
                'feature'    => $feature,
                'name'        => $nameIndex,
                'exclusive'    => (($featureFlags & 0x8000) != 0),
                'settings'    => { TTF_Unpack("S*", substr($self->{' dat'}, $settingTable, $nSettings * 4)) }
            };
    }
    $self->{'features'} = $features;
    
    delete $self->{' dat'}; # no longer needed, and may become obsolete
    
    $self;
}

=head2 $t->out($fh)

Writes the features to a TTF file

=cut

sub out
{
    my ($self, $fh) = @_;
    my ($features, $numFeatures, $settings, $featuresData, $settingsData);
    
    return $self->SUPER::out($fh) unless $self->{' read'};

    $features = $self->{'features'};
    $numFeatures = @$features;

    foreach (@$features) {
        $settings = $_->{'settings'};
        $featuresData .= TTF_Pack("SSLSS",
                                    $_->{'feature'},
                                    scalar keys %$settings,
                                    12 + 12 * $numFeatures + length $settingsData,
                                    ($_->{'exclusive'} ? 0x8000 : 0x0000),
                                    $_->{'name'});
        foreach (sort {$a <=> $b} keys %$settings) {
            $settingsData .= TTF_Pack("SS", $_, $settings->{$_});
        }
    }

    $fh->print(TTF_Pack("vSSL", $self->{'version'}, $numFeatures, 0, 0));
    $fh->print($featuresData);
    $fh->print($settingsData);

    $self;
}

=head2 $t->print($fh)

Prints a human-readable representation of the table

=cut

sub print
{
    my ($self, $fh) = @_;
    my ($names, $features, $settings);

    $self->read;

    $names = $self->{' PARENT'}->{'name'};
    $names->read;

    $fh = 'STDOUT' unless defined $fh;

    $features = $self->{'features'};
    foreach (@$features) {
        $fh->printf("Feature %d, %s, name %d # '%s'\n",
                    $_->{'feature'},
                    ($_->{'exclusive'} ? "exclusive" : "additive"),
                    $_->{'name'},
                    $names->{'strings'}[$_->{'name'}][1][0]{0});
        $settings = $_->{'settings'};
        foreach (sort { $a <=> $b } keys %$settings) {
            $fh->printf("\tSetting %d, name %d # '%s'\n",
                        $_, $settings->{$_}, $names->{'strings'}[$settings->{$_}][1][0]{0});
        }
    }
    
    $self;
}

sub settingName
{
    my ($self, $feature, $setting) = @_;

    $self->read;

    my $names = $self->{' PARENT'}->{'name'};
    $names->read;
    
    my $features = $self->{'features'};
    my ($featureEntry) = grep { $_->{'feature'} == $feature } @$features;
    my $featureName = $names->{'strings'}[$featureEntry->{'name'}][1][0]{0};
    my $settingName = $featureEntry->{'exclusive'}
            ? $names->{'strings'}[$featureEntry->{'settings'}->{$setting}][1][0]{0}
            : $names->{'strings'}[$featureEntry->{'settings'}->{$setting & ~1}][1][0]{0}
                . (($setting & 1) == 0 ? " On" : " Off");

    ($featureName, $settingName);
}

1;

=head1 BUGS

None known

=head1 AUTHOR

Jonathan Kew L<Jonathan_Kew@sil.org>. See L<Font::TTF::Font> for copyright and
licensing.

=cut

