#!/usr/bin/perl

# -CA flag is forbidden in #! line
use Encode qw(decode);
    @ARGV = map { decode 'utf-8', $_ } @ARGV;

use strict;
use warnings;

use lib 'ext/Font-TTF/lib';
use Font::Subsetter;

use Getopt::Long;

main();

sub help {
    print <<EOF;
Usage:
  $0 [options] [inputfile.ttf] [outputfile.ttf]

Options:
  --chars=STRING        characters to include in the subset (defaults to "test")
  --charsfile=FILE      utf8-encoded file containing characters to include
  --verbose, -v         print various details about the font and the subsetting
  --include=FEATURES    comma-separated list of feature tags to include
                        (all others will be excluded by default)
  --exclude=FEATURES    comma-separated list of feature tags to exclude
                        (all others will be included by default)
  --apply=FEATURES      comma-separated list of feature tags to apply to the
                        font directly (folding into the cmap table),
                        e.g. "smcp" to replace all letters with small-caps
                        versions. (You should use --include/--exclude to remove
                        the features, so they don't get applied a second time
                        when rendering.)
  --licensesubst=STRING substitutes STRING in place of the string \${LICENSESUBST}
                        in the font's License Description
EOF
    exit 1;
}

sub main {
    my $verbose = 0;
    my $chars;
    my $charsfile;
    my $include;
    my $exclude;
    my $apply;
    my $license_desc_subst;

    my $result = GetOptions(
        'chars=s' => \$chars,
        'charsfile=s' => \$charsfile,
        'verbose' => \$verbose,
        'include=s' => \$include,
        'exclude=s' => \$exclude,
        'apply=s' => \$apply,
        'licensesubst=s' => \$license_desc_subst,
    ) or help();

    if (defined $chars and defined $charsfile) {
        print "ERROR: Only one of '--chars' and --charsfile' can be specified\n\n";
        help();
    } elsif (defined $chars) {
        # just use $chars
    } elsif (defined $charsfile) {
        open my $f, '<', $charsfile or die "Failed to open $charsfile: $!";
        binmode $f, ':utf8';
        local $/;
        $chars = <$f>;
    } else {
        $chars = 'test';
    }

    @ARGV == 2 or help();

    my ($input_file, $output_file) = @ARGV;


    if ($verbose) {
        dump_sizes($input_file);
        print "Generating subsetted font...\n\n";
    }

    my $features;
    if ($include) {
        $features = { DEFAULT => 0 };
        $features->{$_} = 1 for split /,/, $include;
    } elsif ($exclude) {
        $features = { DEFAULT => 1 };
        $features->{$_} = 0 for split /,/, $exclude;
    }

    my $fold_features;
    if ($apply) {
        $fold_features = [ split /,/, $apply ];
    }

    my $subsetter = new Font::Subsetter();
    $subsetter->subset($input_file, $chars, {
        features => $features,
        fold_features => $fold_features,
        license_desc_subst => $license_desc_subst,
    });
    $subsetter->write($output_file);

    if ($verbose) {
        print "\n";
        print "Features:\n  ";
        print join ' ', $subsetter->feature_status();
        print "\n\n";
        print "Included glyphs:\n  ";
        print join ' ', $subsetter->glyph_names();
        print "\n\n";
        dump_sizes($output_file);
    }

    $subsetter->release();
}

sub dump_sizes {
    my ($filename) = @_;
    my $font = Font::TTF::Font->open($filename) or die "Failed to open $filename: $!";
    print "TTF table sizes:\n";
    my $s = 0;
    for (sort keys %$font) {
        next if /^ /;
        my $l = $font->{$_}{' LENGTH'};
        $s += $l;
        print "  $_: $l\n";
    }
    print "Total size: $s bytes\n\n";
    $font->release();
}
