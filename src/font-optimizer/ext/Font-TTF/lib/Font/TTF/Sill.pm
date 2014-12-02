package Font::TTF::Sill;

=head1 NAME

Font::TTF::Sill - Graphite language mapping table

=head1 DESCRIPTION

=head1 INSTANCE VARIABLES

=over 4

=item version

Table version number.

=item langs

Contains a hash where the key is the language id and the value is an array of
language records

=back

=head2 Language Records

Each language record is itself an array of two values [fid, val]. fid is the
feature id and is held as a long.

=cut

use Font::TTF::Utils;
require Font::TTF::Table;

@ISA = qw(Font::TTF::Table);

sub read
{
    my ($self) = @_;
    my ($num, $i, $j);

    return $self if ($self->{' read'});
    $self->SUPER::read_dat or return $self;

    ($self->{'version'}, $num) = TTF_Unpack("vS", $self->{' dat'});

    foreach $i (1 .. $num)        # ignore bogus entry at end
    {
        my ($lid, $numf, $offset) = unpack("A4nn", substr($self->{' dat'}, $i * 8 + 4));      # 12 - 8 = 4 since i starts at 1. A4 strips nulls
        my (@settings);

        foreach $j (1 .. $numf)
        {
            my ($fid, $val) = TTF_Unpack("Ls", substr($self->{' dat'}, $offset + $j * 8 - 8));
            push (@settings, [$fid, $val]);
        }
        $self->{'langs'}{$lid} = [@settings];
    }
    delete $self->{' dat'};
    $self->{' read'} = 1;
    $self;
}

sub out
{
    my ($self, $fh) = @_;
    my ($num, $range, $select, $shift) = TTF_bininfo(scalar keys %{$self->{'langs'}}, 1);
    my ($offset) = $num * 8 + 20;   #header = 12, dummy = 8
    my ($k, $s);

    return $self->SUPER::out($fh) unless ($self->{' read'});
    $fh->print(TTF_Pack("vSSSS", $self->{'version'}, $num, $range, $select, $shift));
    foreach $k (sort (keys %{$self->{'langs'}}), '+1')
    {
        my ($numf) = scalar @{$self->{'langs'}{$k}} unless ($k eq '+1');
        $fh->print(pack("a4nn", $k, $numf, $offset));
        $offset += $numf * 8;
    }

    foreach $k (sort keys %{$self->{'langs'}})
    {
        foreach $s (@{$self->{'langs'}{$k}})
        { $fh->print(TTF_Pack("LsS", @{$s}, 0)); }
    }
    $self;
}

sub XML_element
{
    my ($self) = shift;
    my ($context, $depth, $key, $dat) = @_;
    my ($fh) = $context->{'fh'};
    my ($k, $s);

    return $self->SUPER::XML_element(@_) unless ($key eq 'langs');
    foreach $k (sort keys %{$self->{'langs'}})
    {
        $fh->printf("%s<lang id='%s'>\n", $depth, $k);
        foreach $s (@{$self->{'langs'}{$k}})
        {
            my ($fid) = $s->[0];
            if ($fid > 0x00FFFFFF)
            { $fid = unpack("A4", pack ("N", $fid)); }
            else
            { $fid = sprintf("%d", $fid); }
            $fh->printf("%s%s<feature id='%s' value='%d'/>\n",
                $depth, $context->{'indent'}, $fid, $s->[1]);
        }
        $fh->printf("%s</lang>\n", $depth);
    }
    $self;
}
1;
        
        
