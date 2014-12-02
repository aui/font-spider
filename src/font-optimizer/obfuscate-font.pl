#!/usr/bin/perl

use strict;
use warnings;

use lib 'ext/Font-TTF/lib';
use Font::TTF::Font;

use Getopt::Long;

main();

sub help {
    print <<EOF;
Obfuscates fonts by deleting data that is not necessary for their use in web
browsers. They should still work via \@font-face, but are a bit harder to
install and use in other applications.
The generated font will be invalid, so there are no guarantees of correct
operation - be careful to test it with all current and future browsers that
you want it to work in.

Usage:
  $0 [options] [inputfile.ttf] [outputfile.ttf]

Options:
  --verbose, -v         print various details about the font
  At least one of the following is required:
  --all                 activate all of the options below
  --names               strip font name strings
  --post                strip PostScript glyph names
EOF
    exit 1;
}

sub set_name {
    my ($font, $id, $val, $verbose) = @_;
    my $str = $font->{name}{strings}[$id];
    for my $plat (0..$#$str) {
        next unless $str->[$plat];
        for my $enc (0..$#{$str->[$plat]}) {
            next unless $str->[$plat][$enc];
            for my $lang (keys %{$str->[$plat][$enc]}) {
                next unless exists $str->[$plat][$enc]{$lang};
                if ($verbose) {
                    print "Setting string $_ (plat $plat, enc $enc) to \"$val\"\n";
                }
                $str->[$plat][$enc]{$lang} = $val;
            }
        }
    }
}

sub strip_names {
    my ($font, $verbose) = @_;

    print "Stripping names\n" if $verbose;

    $font->{name}->read;

    for (16, 17, 18) {
        if ($verbose and $font->{name}{strings}[$_]) {
            print "Deleting string $_\n";
        }
        $font->{name}{strings}[$_] = undef;
    }

    for (1, 3, 5) {
        set_name($font, $_, '', $verbose);
    }

    for (4, 6) {
        set_name($font, $_, '-', $verbose);
    }
}

sub strip_post {
    my ($font, $verbose) = @_;

    print "Stripping post table\n" if $verbose;

    # Replace it with the minimum necessary to work in browsers
    # (particularly Opera is a bit fussy)
    my $data = pack NNnnNNNNN => 0x10000, 0,  0, 0,  0, 0, 0, 0, 0;
    $font->{post} = new Font::TTF::Table(dat => $data);
}

sub main {
    my $verbose = 0;
    my $all;
    my $names;
    my $post;

    my $result = GetOptions(
        'verbose' => \$verbose,
        'all' => \$all,
        'names' => \$names,
        'post' => \$post,
    ) or help();

    @ARGV == 2 or help();

    if (not ($all or $names or $post)) { help(); }

    my ($input_file, $output_file) = @ARGV;

    my $font = Font::TTF::Font->open($input_file) or die "Error opening $input_file: $!";

    strip_names($font, $verbose) if $all or $names;
    strip_post($font, $verbose) if $all or $post;

    $font->out($output_file);

    $font->release;
}
