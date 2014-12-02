package Font::TTF::Table;

=head1 NAME

Font::TTF::Table - Superclass for tables and used for tables we don't have a class for

=head1 DESCRIPTION

Looks after the purely table aspects of a TTF table, such as whether the table
has been read before, locating the file pointer, etc. Also copies tables from
input to output.

=head1 INSTANCE VARIABLES

Instance variables start with a space

=over 4

=item read

Flag which indicates that the table has already been read from file.

=item dat

Allows the creation of unspecific tables. Data is simply output to any font
file being created.

=item INFILE

The read file handle

=item OFFSET

Location of the file in the input file

=item LENGTH

Length in the input directory

=item CSUM

Checksum read from the input file's directory

=item PARENT

The L<Font::TTF::Font> that table is part of

=back

=head1 METHODS

=cut

use strict;
use vars qw($VERSION);
use Font::TTF::Utils;

$VERSION = 0.0001;

=head2 Font::TTF::Table->new(%parms)

Creates a new table or subclass. Table instance variables are passed in
at this point as an associative array.

=cut

sub new
{
    my ($class, %parms) = @_;
    my ($self) = {};
    my ($p);

    $class = ref($class) || $class;
    foreach $p (keys %parms)
    { $self->{" $p"} = $parms{$p}; }
    bless $self, $class;
}


=head2 $t->read

Reads the table from the input file. Acts as a superclass to all true tables.
This method marks the table as read and then just sets the input file pointer
but does not read any data. If the table has already been read, then returns
C<undef> else returns C<$self>

=cut

sub read
{
    my ($self) = @_;

    return $self->read_dat if (ref($self) eq "Font::TTF::Table");
    return undef if $self->{' read'};
    $self->{' INFILE'}->seek($self->{' OFFSET'}, 0);
    $self->{' read'} = 1;
    $self;
}


=head2 $t->read_dat

Reads the table into the C<dat> instance variable for those tables which don't
know any better

=cut

sub read_dat
{
    my ($self) = @_;

# can't just $self->read here otherwise those tables which start their read sub with
# $self->read_dat are going to permanently loop
    return undef if ($self->{' read'});
#    $self->{' read'} = 1;      # Let read do this, now out will call us for subclasses
    $self->{' INFILE'}->seek($self->{' OFFSET'}, 0);
    $self->{' INFILE'}->read($self->{' dat'}, $self->{' LENGTH'});
    $self;
}

=head2 $t->out($fh)

Writes out the table to the font file. If there is anything in the
C<data> instance variable then this is output, otherwise the data is copied
from the input file to the output

=cut

sub out
{
    my ($self, $fh) = @_;
    my ($dat, $i, $len, $count);

    if (defined $self->{' dat'})
    {
        $fh->print($self->{' dat'});
        return $self;
    }

    return undef unless defined $self->{' INFILE'};
    $self->{' INFILE'}->seek($self->{' OFFSET'}, 0);
    $len = $self->{' LENGTH'};
    while ($len > 0)
    {
        $count = ($len > 4096) ? 4096 : $len;
        $self->{' INFILE'}->read($dat, $count);
        $fh->print($dat);
        $len -= $count;
    }
    $self;
}


=head2 $t->out_xml($context)

Outputs this table in XML format. The table is first read (if not already read) and then if
there is no subclass, then the data is dumped as hex data

=cut

sub out_xml
{
    my ($self, $context, $depth) = @_;
    my ($k);

    if (ref($self) eq __PACKAGE__)
    {
        $self->read_dat;
        Font::TTF::Utils::XML_hexdump($context, $depth, $self->{' dat'});
    }
    else
    {
        $self->read;
        foreach $k (sort grep {$_ !~ m/^\s/o} keys %{$self})
        {
            $self->XML_element($context, $depth, $k, $self->{$k});
        }
    }
    $self;
}


=head2 $t->XML_element

Output a particular element based on its contents.

=cut

sub XML_element
{
    my ($self, $context, $depth, $k, $dat) = @_;
    my ($fh) = $context->{'fh'};
    my ($ndepth, $d);

    return unless defined $dat;
    
    if (!ref($dat))
    {
        $fh->printf("%s<%s>%s</%s>\n", $depth, $k, $dat, $k);
        return $self;
    }

    $fh->printf("%s<%s>\n", $depth, $k);
    $ndepth = $depth . $context->{'indent'};

    if (ref($dat) eq 'SCALAR')
    { $self->XML_element($context, $ndepth, 'scalar', $$dat); }
    elsif (ref($dat) eq 'ARRAY')
    {
        foreach $d (@{$dat})
        { $self->XML_element($context, $ndepth, 'elem', $d); }
    }
    elsif (ref($dat) eq 'HASH')
    {
        foreach $d (sort grep {$_ !~ m/^\s/o} keys %{$dat})
        { $self->XML_element($context, $ndepth, $d, $dat->{$d}); }
    }
    else
    {
        $context->{'name'} = ref($dat);
        $context->{'name'} =~ s/^.*://o;
        $dat->out_xml($context, $ndepth);
    }

    $fh->printf("%s</%s>\n", $depth, $k);
    $self;
}


=head2 $t->XML_end($context, $tag, %attrs)

Handles the default type of <data> for those tables which aren't subclassed

=cut

sub XML_end
{
    my ($self, $context, $tag, %attrs) = @_;
    my ($dat, $addr);

    return undef unless ($tag eq 'data');
    $dat = $context->{'text'};
    $dat =~ s/([0-9a-f]{2})\s*/hex($1)/oig;
    if (defined $attrs{'addr'})
    { $addr = hex($attrs{'addr'}); }
    else
    { $addr = length($self->{' dat'}); }
    substr($self->{' dat'}, $addr, length($dat)) = $dat;
    return $context;
}
    

=head2 $t->dirty($val)

This sets the dirty flag to the given value or 1 if no given value. It returns the
value of the flag

=cut

sub dirty
{
    my ($self, $val) = @_;
    my ($res) = $self->{' isDirty'};

    $self->{' isDirty'} = defined $val ? $val : 1;
    $res;
}

=head2 $t->update

Each table knows how to update itself. This consists of doing whatever work
is required to ensure that the memory version of the table is consistent
and that other parameters in other tables have been updated accordingly.
I.e. by the end of sending C<update> to all the tables, the memory version
of the font should be entirely consistent.

Some tables which do no work indicate to themselves the need to update
themselves by setting isDirty above 1. This method resets that accordingly.

=cut

sub update
{
    my ($self) = @_;

    if ($self->{' isDirty'})
    {
        $self->read;
        $self->{' isDirty'} = 0;
        return $self;
    }
    else
    { return undef; }
}


=head2 $t->empty

Clears a table of all data to the level of not having been read

=cut

sub empty
{
    my ($self) = @_;
    my (%keep);

    foreach (qw(INFILE LENGTH OFFSET CSUM PARENT))
    { $keep{" $_"} = 1; }

    map {delete $self->{$_} unless $keep{$_}} keys %$self;
    $self;
}


=head2 $t->release

Releases ALL of the memory used by this table, and all of its component/child
objects.  This method is called automatically by
'Font::TTF::Font-E<gt>release' (so you don't have to call it yourself).

B<NOTE>, that it is important that this method get called at some point prior
to the actual destruction of the object.  Internally, we track things in a
structure that can result in circular references, and without calling
'C<release()>' these will not properly get cleaned up by Perl.  Once this
method has been called, though, don't expect to be able to do anything with the
C<Font::TTF::Table> object; it'll have B<no> internal state whatsoever.

B<Developer note:>  As part of the brute-force cleanup done here, this method
will throw a warning message whenever unexpected key values are found within
the C<Font::TTF::Table> object.  This is done to help ensure that any
unexpected and unfreed values are brought to your attention so that you can bug
us to keep the module updated properly; otherwise the potential for memory
leaks due to dangling circular references will exist.

=cut

sub release
{
    my ($self) = @_;

# delete stuff that we know we can, here

    my @tofree = map { delete $self->{$_} } keys %{$self};

    while (my $item = shift @tofree)
    {
        my $ref = ref($item);
        if (UNIVERSAL::can($item, 'release'))
        { $item->release(); }
        elsif ($ref eq 'ARRAY')
        { push( @tofree, @{$item} ); }
        elsif (UNIVERSAL::isa($ref, 'HASH'))
        { release($item); }
    }

# check that everything has gone - it better had!
    foreach my $key (keys %{$self})
    { warn ref($self) . " still has '$key' key left after release.\n"; }
}


sub __dumpvar__
{
    my ($self, $key) = @_;

    return ($key eq ' PARENT' ? '...parent...' : $self->{$key});
}

1;

=head1 BUGS

No known bugs

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

