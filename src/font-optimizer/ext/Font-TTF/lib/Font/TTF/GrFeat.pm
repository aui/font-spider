package Font::TTF::GrFeat;

=head1 NAME

Font::TTF::GrFeat - Graphite Font Features

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

=item default

the default setting number

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

	return $self if $self->{' read'};
	$self->SUPER::read_dat or return $self;

	($self->{'version'}, $featureCount) = TTF_Unpack("vS", $self->{' dat'});

	$features = [];
	foreach (1 .. $featureCount) {
		my ($feature, $nSettings, $settingTable, $featureFlags, $nameIndex, $reserved);
		if ($self->{'version'} == 1)
		{
			($feature, $nSettings, $settingTable, $featureFlags, $nameIndex)
				= TTF_Unpack("SSLSS", substr($self->{' dat'}, $_ * 12, 12));
			#The version 1 Feat table ends with a feature (id 1) named NoName
			#with zero settings but with an offset to the last entry in the setting
			#array. This last setting has id 0 and an invalid name id. This last
			#feature is changed to have one setting.
			if ($_ == $featureCount && $nSettings == 0) {$nSettings = 1;}
		}
		else #version == 2
			{($feature, $nSettings, $reserved, $settingTable, $featureFlags, $nameIndex)
				= TTF_Unpack("LSSLSS", substr($self->{' dat'}, 12 + ($_ - 1) * 16, 16))};
		my $feature = 
			{
				'feature'	=> $feature,
				'name'		=> $nameIndex,
			};
			
		#interpret the featureFlags & store settings
		$feature->{'exclusive'} = (($featureFlags & 0x8000) != 0);
		
		my @settings = TTF_Unpack("S*", substr($self->{' dat'}, $settingTable, $nSettings * 4));
		if ($featureFlags & 0x4000)
			{$feature->{'default'} = $featureFlags & 0x00FF;}
		else
			{$feature->{'default'} = @settings[0];}
		$feature->{'settings'} = {@settings};
		
		push(@$features, $feature);
	}
	
	$self->{'features'} = $features;
	
	delete $self->{' dat'}; # no longer needed, and may become obsolete
	$self->{' read'} = 1;
	$self;
}

=head2 $t->out($fh)

Writes the features to a TTF file

=cut

sub out
{
	my ($self, $fh) = @_;
	my ($features, $numFeatures, $settings, $featureFlags, $featuresData, $settingsData);
	
	return $self->SUPER::out($fh) unless $self->{' read'};

	$features = $self->{'features'};
	$numFeatures = @$features;
	$featuresData, $settingsData = ('', '');

	foreach (@$features) {
		$settings = $_->{'settings'};
		$featureFlags = ($_->{'exclusive'} ? 0x8000 : 0x0000);
		
#		output default setting first instead of using the featureFlags (as done below)
#		$featureFlags = ($_->{'exclusive'} ? 0x8000 : 0x0000) |
#								($_->{'default'} != 0 ? 0x4000 | ($_->{'default'} & 0x00FF) 
#														: 0x0000);
		if ($self->{'version'} == 1)
		{
			$featuresData .= TTF_Pack("SSLSS",
										$_->{'feature'},
										scalar keys %$settings,
										12 + 12 * $numFeatures + length $settingsData,
										$featureFlags, 
										$_->{'name'});
		}
		else #version == 2
		{
			$featuresData .= TTF_Pack("LSSLSS",
										$_->{'feature'},
										scalar keys %$settings,
										0, 
										12 + 16 * $numFeatures + length $settingsData,
										$featureFlags, 
										$_->{'name'});
		}
		
		#output default setting first
		#the settings may not be in their original order
		my $defaultSetting = $_->{'default'};
		$settingsData .= TTF_Pack("SS", $defaultSetting, $settings->{$defaultSetting});
		foreach (sort {$a <=> $b} keys %$settings) {
			if ($_ == $defaultSetting) {next;} #skip default setting
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
		$fh->printf("Feature %d, %s, default: %d name %d # '%s'\n",
					$_->{'feature'},
					($_->{'exclusive'} ? "exclusive" : "additive"),
					$_->{'default'}, 
					$_->{'name'},
					$names->{'strings'}[$_->{'name'}][3][1]{1033});
		$settings = $_->{'settings'};
		foreach (sort { $a <=> $b } keys %$settings) {
			$fh->printf("\tSetting %d, name %d # '%s'\n",
						$_, $settings->{$_}, $names->{'strings'}[$settings->{$_}][3][1]{1033});
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
	my $featureName = $names->{'strings'}[$featureEntry->{'name'}][3][1]{1033};
	my $settingName = $featureEntry->{'exclusive'}
			? $names->{'strings'}[$featureEntry->{'settings'}->{$setting}][3][1]{1033}
			: $names->{'strings'}[$featureEntry->{'settings'}->{$setting & ~1}][3][1]{1033}
				. (($setting & 1) == 0 ? " On" : " Off");

	($featureName, $settingName);
}

1;

=head1 BUGS

The version 1 Feat table ends with a feature (id 1) named NoName
with zero settings but with an offset to the last entry in the setting
array. This last setting has id 0 and an invalid name id. This last
feature is changed to have one setting.

=head1 AUTHOR

Alan Ward (derived from Jonathan Kew's Feat.pm).
See L<Font::TTF::Font> for copyright and licensing.

=cut

