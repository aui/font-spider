#!/usr/bin/perl -CA
  # use the -CA flag so @ARGV is interpreted as UTF-8

use strict;
use warnings;

binmode STDOUT, ':utf8';

use lib 'ext/Font-TTF/lib';
use Font::TTF::Font;

my @name_strings = qw(
    copyright
    family
    subfamily
    unique-identifier
    full-name
    version
    postscript
    trademark
    manufacturer
    designer
    description
    vendor-url
    designer-url
    license
    license-url
    RESERVED
    preferred-family
    preferred-subfamily
    compatible-full
    sample-text
    postscript-cid
    wws-family
    wws-subfamily
);
my %name_strings;
$name_strings{$name_strings[$_]} = $_ for 0..$#name_strings;

main();

sub help {
    print <<EOF;
This tool provides a (relatively) simple way to manipulate the 'name' table of
TrueType/OpenType fonts.

Usage:
  $0 [options] [commands] [inputfile.ttf] [outputfile.ttf]

Options:
  --verbose, -v         print various details about the modifications made
                                     
Any sequence of the following commands:
  --print                             print the font's current name strings
  --set [name] [string]               replace the name string's value
  --append [name] [string]            append to the name string's value
  --subst [name] [string1] [string2]  replace all occurrences of [string1]
                                      with [string2] in the name string's value

"[name]" can be any of the following: (see the Name ID table on
http://www.microsoft.com/typography/otspec/name.htm for full explanations)

    copyright, family, subfamily, unique-identifier, full-name, version,
    postscript, trademark, manufacturer, designer, description, vendor-url,
    designer-url, license, license-url, preferred-family, preferred-subfamily,
    compatible-full, sample-text, postscript-cid, wws-family, wws-subfamily

EOF

    exit 1;
}

sub modify_name {
    my ($font, $id, $sub) = @_;
    my $str = $font->{name}{strings}[$id];
    my $exists = 0;
    for my $plat (0..$#$str) {
        next unless $str->[$plat];
        for my $enc (0..$#{$str->[$plat]}) {
            next unless $str->[$plat][$enc];
            for my $lang (keys %{$str->[$plat][$enc]}) {
                next unless exists $str->[$plat][$enc]{$lang};
                my $val = $sub->($str->[$plat][$enc]{$lang}, $plat, $enc, $lang);
                $str->[$plat][$enc]{$lang} = $val;
                $exists = 1
            }
        }
    }
    if (not $exists) {
        warn "Can't find existing name string '$name_strings[$id]' ($id)\n";
    }
}


sub json_string {
    my ($str) = @_;
    $str =~ s/([\\"])/\\$1/g;
    $str =~ s/\r/\\r/g;
    $str =~ s/\n/\\n/g;
    $str =~ s/\t/\\t/g;
    $str =~ s/([\x00-\x1f])/sprintf '\u%04X', ord $1/eg;
    return qq{"$str"};
}

sub print_names {
    my ($font) = @_;
    my @lines;
    for my $nid (0..$#name_strings) {
        my $name = $font->{name}->find_name($nid);
        if (length $name) {
            push @lines, json_string($name_strings[$nid]).': '.json_string($name);
        }
    }
    
    print "{\n";
    print join ",\n\n", @lines;
    print "\n}\n";
}

sub parse_id {
    my ($name) = @_;
    if ($name =~ /^\d+$/ and $name < @name_strings) {
        return int $name;
    }
    my $id = $name_strings{lc $name};
    return $id if defined $id;
    warn "Invalid name string identifier '$name'\n\n";
    help();
}

sub main {
    my $verbose = 0;
    my $print = 0;
    my @commands;

    my @args = @ARGV;
    my @rest;
    while (@args) {
        $_ = shift @args;
        if ($_ eq '-v' or $_ eq '--verbose') {
            $verbose = 1;
        } elsif ($_ eq '-p' or $_ eq '--print') {
            $print = 1;
            push @commands, [ 'print' ];
        } elsif ($_ eq '--set') {
            @args >= 2 or help();
            my $id = parse_id(shift @args);
            my $val = shift @args;
            push @commands, [ 'set', $id, $val ];
        } elsif ($_ eq '--append') {
            @args >= 2 or help();
            my $id = parse_id(shift @args);
            my $val = shift @args;
            push @commands, [ 'append', $id, $val ];
        } elsif ($_ eq '--subst') {
            @args >= 3 or help();
            my $id = parse_id(shift @args);
            my $val1 = shift @args;
            my $val2 = shift @args;
            push @commands, [ 'subst', $id, $val1, $val2 ];
        } else {
            push @rest, $_;
        }
    }

    ($print and (@rest == 1 or @rest == 2)) or @rest == 2 or help();

    my ($input_file, $output_file) = @rest;

    my $font = Font::TTF::Font->open($input_file) or die "Error opening $input_file: $!";

    $font->{name}->read;

    for my $cmd (@commands) {
        if ($cmd->[0] eq 'print') {
            print_names($font);
        } elsif ($cmd->[0] eq 'set') {
            my $id = $cmd->[1];
            modify_name($font, $id, sub {
                my ($val, $plat, $enc, $lang) = @_;
                print "Setting string $id (platform=$plat encoding=$enc lang=$lang)\n" if $verbose;
                return $cmd->[2];
            });
        } elsif ($cmd->[0] eq 'append') {
            my $id = $cmd->[1];
            modify_name($font, $id, sub {
                my ($val, $plat, $enc, $lang) = @_;
                print "Appending to string $id (platform=$plat encoding=$enc lang=$lang)\n" if $verbose;
                return $val . $cmd->[2];
            });
        } elsif ($cmd->[0] eq 'subst') {
            my $id = $cmd->[1];
            modify_name($font, $id, sub {
                my ($val, $plat, $enc, $lang) = @_;
                my $pat = quotemeta($cmd->[2]);
                my $n = ($val =~ s/$pat/$cmd->[3]/g) || 0;
                print "Substituting string $id (platform=$plat encoding=$enc lang=$lang) - $n match(es)\n" if $verbose;
                warn "No match found for substitution on string '$name_strings[$id]'\n" if not $n;
                return $val;
            });
        } else {
            die;
        }
    }

    $font->out($output_file) if $output_file;

    $font->release;
}
