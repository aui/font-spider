package Font::TTF::Anchor;

=head1 NAME

Font::TTF::Anchor - Anchor points for GPOS tables

=head1 DESCRIPTION

The Anchor defines an anchor point on a glyph providing various information
depending on how much is available, including such information as the co-ordinates,
a curve point and even device specific modifiers.

=head1 INSTANCE VARIABLES

=over 4

=item x

XCoordinate of the anchor point

=item y

YCoordinate of the anchor point

=item p

Curve point on the glyph to use as the anchor point

=item xdev

Device table (delta) for the xcoordinate

=item ydev

Device table (delta) for the ycoordinate

=item xid

XIdAnchor for multiple master horizontal metric id

=item yid

YIdAnchor for multiple master vertical metric id

=back

=head1 METHODS

=cut

use strict;
use Font::TTF::Utils;


=head2 new

Creates a new Anchor

=cut

sub new
{
    my ($class) = shift;
    my ($self) = {@_};

    bless $self, $class;
}


=head2 read($fh)

Reads the anchor from the given file handle at that point. The file handle is left
at an arbitrary read point, usually the end of something!

=cut

sub read
{
    my ($self, $fh) = @_;
    my ($dat, $loc, $fmt, $p, $xoff, $yoff);

    $fh->read($dat, 6);
    $fmt = unpack('n', $dat);
    if ($fmt == 4)
    { ($self->{'xid'}, $self->{'yid'}) = TTF_Unpack('S2', substr($dat,2)); }
    else
    { ($self->{'x'}, $self->{'y'}) = TTF_Unpack('s2', substr($dat,2)); }

    if ($fmt == 2)
    {
        $fh->read($dat, 2);
        $self->{'p'} = unpack('n', $dat);
    } elsif ($fmt == 3)
    {
        $fh->read($dat, 4);
        ($xoff, $yoff) = unpack('n2', $dat);
        $loc = $fh->tell() - 10;
        if ($xoff)
        {
            $fh->seek($loc + $xoff, 0);
            $self->{'xdev'} = Font::TTF::Delta->new->read($fh);
        }
        if ($yoff)
        {
            $fh->seek($loc + $yoff, 0);
            $self->{'ydev'} = Font::TTF::Delta->new->read($fh);
        }
    }
    $self;
}


=head2 out($fh, $style)

Outputs the Anchor to the given file handle at this point also addressing issues
of deltas. If $style is set, then no output is sent to the file handle. The return
value is the output string.

=cut

sub out
{
    my ($self, $fh, $style) = @_;
    my ($xoff, $yoff, $fmt, $out);

    if (defined $self->{'xid'} || defined $self->{'yid'})
    { $out = TTF_Pack('SSS', 4, $self->{'xid'}, $self->{'yid'}); }
    elsif (defined $self->{'p'})
    { $out = TTF_Pack('Ssss', 2, @{$self}{'x', 'y', 'p'}); }
    elsif (defined $self->{'xdev'} || defined $self->{'ydev'})
    {
        $out = TTF_Pack('Sss', 3, @{$self}{'x', 'y'});
        if (defined $self->{'xdev'})
        {
            $out .= pack('n2', 10, 0);
            $out .= $self->{'xdev'}->out($fh, 1);
            $yoff = length($out) - 10;
        }
        else
        { $out .= pack('n2', 0, 0); }
        if (defined $self->{'ydev'})
        {
            $yoff = 10 unless $yoff;
            substr($out, 8, 2) = pack('n', $yoff);
            $out .= $self->{'ydev'}->out($fh, 1);
        }
    } else
    { $out = TTF_Pack('Sss', 1, @{$self}{'x', 'y'}); }
    $fh->print($out) unless $style;
    $out;
}


sub signature
{
    my ($self) = @_;
    return join (",", map {"${_}=$self->{$_}"} qw(x y p xdev ydev xid yid));
}


=head2 $a->out_xml($context)

Outputs the anchor in XML

=cut

sub out_xml
{
    my ($self, $context, $depth) = @_;
    my ($fh) = $context->{'fh'};
    my ($end);
    
    $fh->print("$depth<anchor x='$self->{'x'}' y='$self->{'y'}'");
    $fh->print(" p='$self->{'p'}'") if defined ($self->{'p'});
    $end = (defined $self->{'xdev'} || defined $self->{'ydev'} || defined $self->{'xid'} || defined $self->{'yid'});
    unless ($end)
    {
        $fh->print("/>\n");
        return $self;
    }

    if (defined $self->{'xdev'})
    {
        $fh->print("$depth$context->{'indent'}<xdev>\n");
        $self->{'xdev'}->out_xml($context, $depth . ($context->{'indent'} x 2));
        $fh->print("$depth$context->{'indent'}</xdev>\n");
    }
    
    if (defined $self->{'ydev'})
    {
        $fh->print("$depth$context->{'indent'}<ydev>\n");
        $self->{'ydev'}->out_xml($context, $depth . ($context->{'indent'} x 2));
        $fh->print("$depth$context->{'indent'}</ydev>\n");
    }
    
    if (defined $self->{'xid'} || defined $self->{'yid'})
    {
        $fh->print("$depth$context->{'indent'}<mmaster");
        $fh->print(" xid='$self->{'xid'}'") if defined ($self->{'xid'});
        $fh->print(" yid='$self->{'yid'}'") if defined ($self->{'yid'});
        $fh->print("/>\n");
    }
    $fh->print("$depth</anchor>\n");
    $self;
}
        

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

1;

