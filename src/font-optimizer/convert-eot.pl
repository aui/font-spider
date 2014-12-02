#!/usr/bin/perl

use strict;
use warnings;

use lib 'ext/Font-TTF/lib';
use Font::TTF::Font;
use Font::EOTWrapper;

use Getopt::Long;

main();

sub help {
    print <<EOF;
Convert between TTF and EOT. (Compressed EOTs are not supported.)

Usage:
  $0 [options] [inputfile] [outputfile]

Options:
  --ttf-to-eot    Convert input from TTF to EOT
  --eot-to-ttf    Convert input from EOT to TTF
EOF
    exit 1;
}

sub main {
    my $verbose = 0;
    my $ttf_to_eot;
    my $eot_to_ttf;

    my $result = GetOptions(
        'verbose' => \$verbose,
        'ttf-to-eot' => \$ttf_to_eot,
        'eot-to-ttf' => \$eot_to_ttf,
    ) or help();

    @ARGV == 2 or help();

    my ($input_file, $output_file) = @ARGV;

    if ($ttf_to_eot and $eot_to_ttf) {
        help();
    }

    if (not ($ttf_to_eot or $eot_to_ttf)) {
        if ($input_file =~ /\.[ot]tf$/i and $output_file =~ /\.eot$/i) {
            $ttf_to_eot = 1;
        } elsif ($input_file =~ /\.eot$/i and $output_file =~ /\.[ot]tf$/i) {
            $eot_to_ttf = 1;
        } else {
            help();
        }
    }

    if ($ttf_to_eot) {
        Font::EOTWrapper::convert($input_file, $output_file);
    } elsif ($eot_to_ttf) {
        Font::EOTWrapper::extract($input_file, $output_file);
    }
}
