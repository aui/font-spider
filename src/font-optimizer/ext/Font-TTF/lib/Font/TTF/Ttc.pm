package Font::TTF::Ttc;

=head1 NAME

Font::TTF::Ttc - Truetype Collection class

=head1 DESCRIPTION

A TrueType collection is a collection of TrueType fonts in one file in which
tables may be shared between different directories. In order to support this,
the TTC introduces the concept of a table being shared by different TrueType
fonts. This begs the question of what should happen to the ' PARENT' property
of a particular table. It is made to point to the first directory object which
refers to it. It is therefore up to the application to sort out any confusion.
Confusion only occurs if shared tables require access to non-shared tables.
This should not happen since the shared tables are dealing with glyph
information only and the private tables are dealing with encoding and glyph
identification. Thus the general direction is from identification to glyph and
not the other way around (at least not without knowledge of the particular
context).

=head1 INSTANCE VARIABLES

The following instance variables are preceded by a space

=over 4

=item fname (P)

Filename for this TrueType Collection

=item INFILE (P)

The filehandle of this collection

=back

The following instance variable does not start with a space

=over 4

=item directs

An array of directories (Font::TTF::Font objects) for each sub-font in the directory

=back

=head1 METHODS

=cut

use strict;
use vars qw($VERSION);

use IO::File;

$VERSION = 0.0001;

=head2 Font::TTF::Ttc->open($fname)

Opens and reads the given filename as a TrueType Collection. Reading a collection
involves reading each of the directories which go to make up the collection.

=cut

sub open
{
    my ($class, $fname) = @_;
    my ($self) = {};
    my ($fh);

    unless (ref($fname))
    {
        $fh = IO::File->new($fname) or return undef;
        binmode $fh;
    } else
    { $fh = $fname; }
    
    bless $self, $class;
    $self->{' INFILE'} = $fh;
    $self->{' fname'} = $fname;
    $fh->seek(0, 0);
    $self->read;
}


=head2 $c->read

Reads a Collection by reading all the directories in the collection

=cut

sub read
{
    my ($self) = @_;
    my ($fh) = $self->{' INFILE'};
    my ($dat, $ttc, $ver, $num, $i, $loc);

    $fh->read($dat, 12);
    ($ttc, $ver, $num) = unpack("A4N2", $dat);

    return undef unless $ttc eq "ttcf";
    $fh->read($dat, $num << 2);
    for ($i = 0; $i < $num; $i++)
    {
        $loc = unpack("N", substr($dat, $i << 2, 4));       
        $self->{'directs'}[$i] = Font::TTF::Font->new('INFILE' => $fh,
                                                'PARENT' => $self,
                                                'OFFSET' => $loc) || return undef;
    }
    for ($i = 0; $i < $num; $i++)
    { $self->{'directs'}[$i]->read; }
    $self;
}


=head2 $c->find($direct, $name, $check, $off, $len)

Hunts around to see if a table with the given characteristics of name, checksum,
offset and length has been associated with a directory earlier in the list.
Actually on checks the offset since no two tables can share the same offset in
a TrueType font, collection or otherwise.

=cut

sub find
{
    my ($self, $direct, $name, $check, $off, $len) = @_;
    my ($d);

    foreach $d (@{$self->{'directs'}})
    {
        return undef if $d eq $direct;
        next unless defined $d->{$name};
        return $d->{$name} if ($d->{$name}{' OFFSET'} == $off);
    }
    undef;              # wierd that the font passed is not in the list!
}


=head2 $c->DESTROY

Closees any opened files by us

=cut

sub DESTROY
{
    my ($self) = @_;
    close ($self->{' INFILE'});
    undef;
}

=head1 BUGS

No known bugs, but then not ever executed!

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

