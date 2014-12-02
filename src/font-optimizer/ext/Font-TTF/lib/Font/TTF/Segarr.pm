package Font::TTF::Segarr;

=head1 NAME

Font::TTF::Segarr - Segmented array

=head1 DESCRIPTION

Holds data either directly or indirectly as a series of arrays. This class
looks after the set of arrays and masks the individual sub-arrays, thus saving
a class, we hope.

=head1 INSTANCE VARIABLES

All instance variables do not start with a space.

The segmented array is simply an array of segments

Each segment is a more complex affair:

=over 4

=item START

In terms of the array, the address for the 0th element in this segment.

=item LEN

Number of elements in this segment

=item VAL

The array which contains the elements

=back

=head1 METHODS

=cut

use strict;
use vars qw(@types $VERSION);
$VERSION = 0.0001;

@types = ('', 'C', 'n', '', 'N');

=head2 Font::TTF::Segarr->new($size)

Creates a new segmented array with a given data size

=cut

sub new
{
    my ($class) = @_;
    my ($self) = [];

    bless $self, (ref($class) || $class);
}


=head2 $s->fastadd_segment($start, $is_sparse, @dat)

Creates a new segment and adds it to the array assuming no overlap between
the new segment and any others in the array. $is_sparse indicates whether the
passed in array contains C<undef>s or not. If false no checking is done (which
is faster, but riskier). If equal to 2 then 0 is considered undef as well.

Returns the number of segments inserted.

=cut

sub fastadd_segment
{
    my ($self) = shift;
    my ($start) = shift;
    my ($sparse) = shift;
    my ($p, $i, $seg, @seg);


    if ($sparse)
    {
        for ($i = 0; $i <= $#_; $i++)
        {
            if (!defined $seg && (($sparse != 2 && defined $_[$i]) || $_[$i] != 0))
            { $seg->{'START'} = $start + $i; $seg->{'VAL'} = []; }
            
            if (defined $seg && (($sparse == 2 && $_[$i] == 0) || !defined $_[$i]))
            {
                $seg->{'LEN'} = $start + $i - $seg->{'START'};
                push(@seg, $seg);
                $seg = undef;
            } elsif (defined $seg)
            { push (@{$seg->{'VAL'}}, $_[$i]); }
        }
        if (defined $seg)
        {
            push(@seg, $seg);
            $seg->{'LEN'} = $start + $i - $seg->{'START'};
        }
    } else
    {
        $seg->{'START'} = $start;
        $seg->{'LEN'} = $#_ + 1;
        $seg->{'VAL'} = [@_];
        @seg = ($seg);
    }

    for ($i = 0; $i <= $#$self; $i++)
    {
        if ($self->[$i]{'START'} > $start)
        {
            splice(@$self, $i, 0, @seg);
            return wantarray ? @seg : scalar(@seg);
        }
    }
    push(@$self, @seg);
    return wantarray ? @seg : scalar(@seg);
}


=head2 $s->add_segment($start, $overwrite, @dat)

Creates a new segment and adds it to the array allowing for possible overlaps
between the new segment and the existing ones. In the case of overlaps, elements
from the new segment are deleted unless $overwrite is set in which case the
elements already there are over-written.

This method also checks the data coming in to see if it is sparse (i.e. contains
undef values). Gaps cause new segments to be created or not to over-write existing
values.

=cut

sub add_segment
{
    my ($self) = shift;
    my ($start) = shift;
    my ($over) = shift;
    my ($seg, $i, $s, $offset, $j, $newi);

    return $self->fastadd_segment($start, $over, @_) if ($#$self < 0);
    $offset = 0;
    for ($i = 0; $i <= $#$self && $offset <= $#_; $i++)
    {
        $s = $self->[$i];
        if ($s->{'START'} <= $start + $offset)              # only < for $offset == 0
        {
            if ($s->{'START'} + $s->{'LEN'} > $start + $#_)
            {
                for ($j = $offset; $j <= $#_; $j++)
                {
                    if ($over)
                    { $s->{'VAL'}[$start - $s->{'START'} + $j] = $_[$j] if defined $_[$j]; }
                    else
                    { $s->{'VAL'}[$start - $s->{'START'} + $j] ||= $_[$j] if defined $_[$j]; }
                }
                $offset = $#_ + 1;
                last;
            } elsif ($s->{'START'} + $s->{'LEN'} > $start + $offset)        # is $offset needed here?
            {
                for ($j = $offset; $j < $s->{'START'} + $s->{'LEN'} - $start; $j++)
                {
                    if ($over)
                    { $s->{'VAL'}[$start - $s->{'START'} + $j] = $_[$j] if defined $_[$j]; }
                    else
                    { $s->{'VAL'}[$start - $s->{'START'} + $j] ||= $_[$j] if defined $_[$j]; }
                }
                $offset = $s->{'START'} + $s->{'LEN'} - $start;
            }
        } else                                              # new seg please
        {
            if ($s->{'START'} > $start + $#_ + 1)
            {
                $i += $self->fastadd_segment($start + $offset, 1, @_[$offset .. $#_]) - 1;
                $offset = $#_ + 1;
            }
            else
            {
                $i += $self->fastadd_segment($start + $offset, 1, @_[$offset .. $s->{'START'} - $start]) - 1;
                $offset = $s->{'START'} - $start + 1;
            }
        }
    }
    if ($offset <= $#_)
    {
        $seg->{'START'} = $start + $offset;
        $seg->{'LEN'} = $#_ - $offset + 1;
        $seg->{'VAL'} = [@_[$offset .. $#_]];
        push (@$self, $seg);
    }
    $self->tidy;
}


=head2 $s->tidy

Merges any immediately adjacent segments

=cut

sub tidy
{
    my ($self) = @_;
    my ($i, $sl, $s);

    for ($i = 1; $i <= $#$self; $i++)
    {
        $sl = $self->[$i - 1];
        $s = $self->[$i];
        if ($s->{'START'} == $sl->{'START'} + $sl->{'LEN'})
        {
            $sl->{'LEN'} += $s->{'LEN'};
            push (@{$sl->{'VAL'}}, @{$s->{'VAL'}});
            splice(@$self, $i, 1);
            $i--;
        }
    }
    $self;
}


=head2 $s->at($addr, [$len])

Looks up the data held at the given address by locating the appropriate segment
etc. If $len > 1 then returns an array of values, spaces being filled with undef.

=cut

sub at
{
    my ($self, $addr, $len) = @_;
    my ($i, $dat, $s, @res, $offset);

    $len = 1 unless defined $len;
    $offset = 0;
    for ($i = 0; $i <= $#$self; $i++)
    {
        $s = $self->[$i];
        next if ($s->{'START'} + $s->{'LEN'} < $addr + $offset);        # only fires on $offset == 0
        if ($s->{'START'} > $addr + $offset)
        {
            push (@res, (undef) x ($s->{'START'} > $addr + $len ?
                    $len - $offset : $s->{'START'} - $addr - $offset));
            $offset = $s->{'START'} - $addr;
        }
        last if ($s->{'START'} >= $addr + $len);
        
        if ($s->{'START'} + $s->{'LEN'} >= $addr + $len)
        {
            push (@res, @{$s->{'VAL'}}[$addr + $offset - $s->{'START'} ..
                    $addr + $len - $s->{'START'} - 1]);
            $offset = $len;
            last;
        } else
        {
            push (@res, @{$s->{'VAL'}}[$addr + $offset - $s->{'START'} .. $s->{'LEN'} - 1]);
            $offset = $s->{'START'} + $s->{'LEN'} - $addr;
        }
    }
    push (@res, (undef) x ($len - $offset)) if ($offset < $len);
    return wantarray ? @res : $res[0];
}


=head2 $s->remove($addr, [$len])

Removes the item or items from addr returning them as an array or the first
value in a scalar context. This is very like C<at>, including padding with
undef, but it deletes stuff as it goes.

=cut

sub remove
{
    my ($self, $addr, $len) = @_;
    my ($i, $dat, $s, @res, $offset);

    $len = 1 unless defined $len;
    $offset = 0;
    for ($i = 0; $i <= $#$self; $i++)
    {
        $s = $self->[$i];
        next if ($s->{'START'} + $s->{'LEN'} < $addr + $offset);
        if ($s->{'START'} > $addr + $offset)
        {
            push (@res, (undef) x ($s->{'START'} > $addr + $len ?
                    $len - $offset : $s->{'START'} - $addr - $offset));
            $offset = $s->{'START'} - $addr;
        }
        last if ($s->{'START'} >= $addr + $len);
        
        unless ($s->{'START'} == $addr + $offset)
        {
            my ($seg) = {};

            $seg->{'START'} = $s->{'START'};
            $seg->{'LEN'} = $addr + $offset - $s->{'START'};
            $seg->{'VAL'} = [splice(@{$s->{'VAL'}}, 0, $addr + $offset - $s->{'START'})];
            $s->{'LEN'} -= $addr + $offset - $s->{'START'};
            $s->{'START'} = $addr + $offset;

            splice(@$self, $i, 0, $seg);
            $i++;
        }

        if ($s->{'START'} + $s->{'LEN'} >= $addr + $len)
        {
            push (@res, splice(@{$s->{'VAL'}}, 0, $len - $offset));
            $s->{'LEN'} -= $len - $offset;
            $s->{'START'} += $len - $offset;
            $offset = $len;
            last;
        } else
        {
            push (@res, @{$s->{'VAL'}});
            $offset = $s->{'START'} + $s->{'LEN'} - $addr;
            splice(@$self, $i, 0);
            $i--;
        }
    }
    push (@res, (undef) x ($len - $offset)) if ($offset < $len);
    return wantarray ? @res : $res[0];
}
    

=head2 $s->copy

Deep copies this array

=cut

sub copy
{
    my ($self) = @_;
    my ($res, $p);

    $res = [];
    foreach $p (@$self)
    { push (@$res, $self->copy_seg($p)); }
    $res;
}
    

=head2 $s->copy_seg($seg)

Creates a deep copy of a segment

=cut

sub copy_seg
{
    my ($self, $seg) = @_;
    my ($p, $res);

    $res = {};
    $res->{'VAL'} = [@{$seg->{'VAL'}}];
    foreach $p (keys %$seg)
    { $res->{$p} = $seg->{$p} unless defined $res->{$p}; }
    $res;
}


1;

=head1 BUGS

No known bugs.

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

