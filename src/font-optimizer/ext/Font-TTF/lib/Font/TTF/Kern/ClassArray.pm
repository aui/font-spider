package Font::TTF::Kern::ClassArray;

=head1 NAME

Font::TTF::Kern::ClassArray - ClassArray Kern Subtable for AAT

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);
use Font::TTF::Utils;
use Font::TTF::AATutils;
use IO::File;

@ISA = qw(Font::TTF::Kern::Subtable);

sub new
{
    my ($class) = @_;
    my ($self) = {};
    
    $class = ref($class) || $class;
    bless $self, $class;
}

=head2 $t->read

Reads the table into memory

=cut

sub read
{
    my ($self, $fh) = @_;
 
    my $subtableStart = $fh->tell() - 8;
    my $dat;
    $fh->read($dat, 8);
    my ($rowWidth, $leftClassTable, $rightClassTable, $array) = unpack("nnnn", $dat);

    $fh->seek($subtableStart + $leftClassTable, IO::File::SEEK_SET);
    $fh->read($dat, 4);
    my ($firstGlyph, $nGlyphs) = unpack("nn", $dat);
    $fh->read($dat, $nGlyphs * 2);
    my $leftClasses = [];
    foreach (TTF_Unpack("S*", $dat)) {
        push @{$leftClasses->[($_ - $array) / $rowWidth]}, $firstGlyph++;
    }
    
    $fh->seek($subtableStart + $rightClassTable, IO::File::SEEK_SET);
    $fh->read($dat, 4);
    ($firstGlyph, $nGlyphs) = unpack("nn", $dat);
    $fh->read($dat, $nGlyphs * 2);
    my $rightClasses = [];
    foreach (TTF_Unpack("S*", $dat)) {
        push @{$rightClasses->[$_ / 2]}, $firstGlyph++;
    }
    
    $fh->seek($subtableStart + $array, IO::File::SEEK_SET);
    $fh->read($dat, $self->{'length'} - $array);

    my $offset = 0;
    my $kernArray = [];
    while ($offset < length($dat)) {
        push @$kernArray, [ TTF_Unpack("s*", substr($dat, $offset, $rowWidth)) ];
        $offset += $rowWidth;
    }    

    $self->{'leftClasses'} = $leftClasses;
    $self->{'rightClasses'} = $rightClasses;
    $self->{'kernArray'} = $kernArray;
    
    $fh->seek($subtableStart + $self->{'length'}, IO::File::SEEK_SET);
    
    $self;
}

=head2 $t->out_sub($fh)

Writes the table to a file

=cut

sub out_sub
{
}

=head2 $t->print($fh)

Prints a human-readable representation of the table

=cut

sub print
{
    my ($self, $fh) = @_;
    
    my $post = $self->post();
    
    $fh = 'STDOUT' unless defined $fh;

    
}

sub dumpXML
{
    my ($self, $fh) = @_;
    my $post = $self->post();
    
    $fh = 'STDOUT' unless defined $fh;
    $fh->printf("<leftClasses>\n");
    $self->dumpClasses($self->{'leftClasses'}, $fh);    
    $fh->printf("</leftClasses>\n");

    $fh->printf("<rightClasses>\n");
    $self->dumpClasses($self->{'rightClasses'}, $fh);    
    $fh->printf("</rightClasses>\n");
    
    $fh->printf("<kernArray>\n");
    my $kernArray = $self->{'kernArray'};
    foreach (0 .. $#$kernArray) {
        $fh->printf("<row index=\"%s\">\n", $_);
        my $row = $kernArray->[$_];
        foreach (0 .. $#$row) {
            $fh->printf("<val index=\"%s\" v=\"%s\"/>\n", $_, $row->[$_]);
        }
        $fh->printf("</row>\n");
    }
    $fh->printf("</kernArray>\n");
}

sub type
{
    return 'kernClassArray';
}



1;

=head1 BUGS

None known

=head1 AUTHOR

Jonathan Kew L<Jonathan_Kew@sil.org>. See L<Font::TTF::Font> for copyright and
licensing.

=cut

