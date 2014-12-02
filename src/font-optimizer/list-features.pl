#!/usr/bin/perl

use strict;
use warnings;

use lib 'ext/Font-TTF/lib';
use Font::TTF::Font;

use Getopt::Long;

main();

sub help {
    print <<EOF;
Lists GSUB/GPOS features in a font.

Usage:
  $0 [options] [inputfile.ttf]

Options:
  (None)
EOF
    exit 1;
}

sub main {
    my $verbose = 0;

    my $result = GetOptions(
    ) or help();

    @ARGV == 1 or help();

    my ($input_file) = @ARGV;

    my $font = Font::TTF::Font->open($input_file) or die "Error opening $input_file: $!";

    my %feats;
    my @feats;
    for my $table (grep defined, $font->{GPOS}, $font->{GSUB}) {
        $table->read;
        for my $feature (@{$table->{FEATURES}{FEAT_TAGS}}) {
            $feature =~ /^(\w{4})( _\d+)?$/ or die "Unrecognised feature tag syntax '$feature'";
            my $tag = $1;
            next if $feats{$tag}++;
            push @feats, $tag;
        }
    }
    print map "$_\n", @feats;

    $font->release;
}
