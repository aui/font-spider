#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw(no_plan);

use lib 'ext/Font-TTF/lib';
use Font::Subsetter;
use Unicode::Normalize;

# Test that we include characters needed for strings converted to NFC
for my $str (
    "i",
    "\xec",
    "i\x{0300}",
    "\x{0300}i",
    "\x{03b9}\x{0308}\x{0301}", # iota, combining diaeresis, combining acute
    "s\x{0323}\x{0307}", # s, combining dot below, combining dot above
    "s\x{0307}\x{0323}", # s, combining dot above, combining dot below
    "\x{1e61}\x{0323}", # s with dot above, combining dot below
    "\x{1e63}\x{0307}", # s with dot below, combining dot above
    "\x{212b}", # angstrom
) {
    my $subsetter = new Font::Subsetter;
    my %chars = $subsetter->expand_wanted_chars($str);
    for (map ord, split //, $str) {
        ok($chars{$_}, "char ".(sprintf '%04x', $_)." in string '".(join ' ', map { sprintf '%04x', $_ } unpack 'U*', $str)."'");
    }
    for (map ord, split //, Unicode::Normalize::NFC($str)) {
        ok($chars{$_}, "NFC char ".(sprintf '%04x', $_)." in string '".(join ' ', map { sprintf '%04x', $_ } unpack 'U*', $str)."'");
    }
}

# Test that spurious characters aren't included
for my $str (
    "a\xec",
) {
    my $subsetter = new Font::Subsetter;
    my %chars = $subsetter->expand_wanted_chars($str);
    my %exp;
    $exp{$_} = 1 for map ord, split //, $str;
    $exp{$_} = 1 for map ord, split //, Unicode::Normalize::NFC($str);
    for (sort keys %chars) {
        ok($exp{$_}, "expected char ".(sprintf '%04x', $_)." from string '".(join ' ', map { sprintf '%04x', $_ } unpack 'U*', $str)."'");
    }
}
