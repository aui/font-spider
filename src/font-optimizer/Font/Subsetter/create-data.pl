use strict;
use warnings;

use Unicode::Normalize;

print <<EOF;
package Font::Subsetter::NormalizationData;
use strict;
use warnings;
our \@data = (
EOF

# Output is:
#  [x, a,b,c...],
# where the codepoint x is the NFC normalization of the string a,b,c

my @data;

open my $f, '/usr/lib/perl5/5.8.8/unicore/UnicodeData.txt' or die $!;
while (<$f>) {
    my @c = split /;/, $_;
    # Find characters which canonically decompose (without any
    # compatibility tag "<foo>")
    next unless $c[5] and $c[5] !~ /^</;

    {
        # Print the character and its maximally-decomposed codepoints,
        # if they re-compose into it
        my @x = split //, Unicode::Normalize::NFD(chr hex $c[0]);
        push @data, [hex $c[0], map ord, @x]
            if Unicode::Normalize::NFC(join '', @x) eq chr hex $c[0];
    }

    # Try to find all other strings that can become this character under NFC:
    # If the maximal decomposition is "abc", we might want the strings
    # "NFC(ab) c", "NFC(ac) b", etc, so attempt all permutations of abc
    # and then try all groupings to apply NFC to
    
    my @norm = split //, Unicode::Normalize::NFD(chr hex $c[0]);
    if (@norm == 3) {
        my ($a, $b, $c) = @norm;
        for my $cs (permut([$a, $b, $c], [])) { # all permutations
            for my $cs2 ('ab c', 'a bc') { # all groupings
                my @x = map Unicode::Normalize::NFC($_), map { s/(.)/$cs->[ord($1)-ord('a')]/eg; $_ } split / /, $cs2;
                # If NFC didn't collapse everything into single characters, this string is not interesting
                next if grep length != 1, @x;
                # If the string doesn't NFC into the desired character, it's not interesting
                next unless Unicode::Normalize::NFC(join '', @x) eq chr hex $c[0];
                # This string is good
                push @data, [hex $c[0], map ord, @x];
            }
        }
    } elsif (@norm == 4) {
        my ($a, $b, $c, $d) = @norm;
        for my $cs (permut([$a, $b, $c, $d], [])) {
            for my $cs2 ('ab c d', 'a bc d', 'a b cd', 'ab cd', 'abc d', 'a bcd') {
                my @x = map Unicode::Normalize::NFC($_), map { s/(.)/$cs->[ord($1)-ord('a')]/eg; $_ } split / /, $cs2;
                next if grep length != 1, @x;
                next unless Unicode::Normalize::NFC(join '', @x) eq chr hex $c[0];
                push @data, [hex $c[0], map ord, @x];
            }
        }
    } elsif (@norm > 4) {
        die "\@norm too big";
    }
}

print uniq(map "[".join(',', @$_)."],\n", @data);

print <<EOF;
);

1;
EOF

sub permut {
    my @r;
    my @head = @{ $_[0] };
    my @tail = @{ $_[1] };
    unless (@head) {
        push @r, \@tail;
    } else {
        for my $i (0 .. $#head) {
            my @newhead = @head;
            my @newtail = @tail;
            unshift(@newtail, splice(@newhead, $i, 1));
            push @r, permut([@newhead], [@newtail]);
        }
    }
    return @r;
}

sub uniq {
    my @u;
    my %u;
    for (@_) {
        push @u, $_ unless $u{$_}++;
    }
    @u;
}
