package Font::TTF::Dumper;

=head1 NAME

Font::TTF::Dumper - Debug dump of a font datastructure, avoiding recursion on ' PARENT'

=head1 SYNOPSIS

    Font::TTF::Dumper;
    
    # Print a table from the font structure:
    print ttfdump($font->{$tag});
    
    # Print font table with name
    print ttfdump($font->{'head'}, 'head');
    
    # Print one glyph's data:
    print ttfdump($font->{'loca'}->read->{'glyphs'}[$gid], "glyph_$gid");

=head1 DESCRIPTION

Font::TTF data structures are trees created from hashes and arrays. When trying to figure
out how the structures work, sometimes it is helpful to use Data::Dumper on them. However,
many of the object structures have ' PARENT' links that refer back to the object's parent,
which means that Data::Dumper ends up dumping the whole font no matter what.

The purpose of this module is to do just one thing: invoke Data::Dumper with a
filter that skips over the ' PARENT' element of any hash.

To reduce output further, this module also skips over ' CACHE' elements and any 
hash element whose value is a Font::TTF::Glyph or Font::TTF::Font object. 
(Really should make this configurable.)

=cut

use strict;
use Data::Dumper;

use vars qw(@EXPORT @ISA);
require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw( ttfdump );

my %skip = ( Font => 1, Glyph => 1 );

sub ttfdump
{
    my ($var, $name) = @_;
    my $res;
    
    my $d = Data::Dumper->new([$var]);
    $d->Names([$name]) if defined $name;
    $d->Sortkeys(\&myfilter);   # This is the trick to keep from dumping the whole font
    $d->Indent(3);  # I want array indicies
    $d->Useqq(1);   # Perlquote -- slower but there might be binary data.
    $res = $d->Dump;
    $d->DESTROY;
    $res;
}

sub myfilter
{
    my ($hash) = @_;
    my @a = grep {
            ($_ eq ' PARENT' || $_ eq ' CACHE') ? 0 :
            ref($hash->{$_}) =~ m/^Font::TTF::(.*)$/ ? !$skip{$1} :
            1
        } (keys %{$hash}) ;
    # Sort numerically if that is reasonable:
    return [ sort {$a =~ /\D/ || $b =~ /\D/ ? $a cmp $b : $a <=> $b} @a ];
}

1;

=head1 See also

L<Font::TTF::Font>

=cut
