package Font::TTF::Mort::Subtable;

=head1 NAME

Font::TTF::Mort::Subtable - Mort subtable superclass for AAT

=head1 METHODS

=cut

use strict;
use Font::TTF::Utils;
use Font::TTF::AATutils;
use IO::File;

require Font::TTF::Mort::Rearrangement;
require Font::TTF::Mort::Contextual;
require Font::TTF::Mort::Ligature;
require Font::TTF::Mort::Noncontextual;
require Font::TTF::Mort::Insertion;

sub new
{
    my ($class) = @_;
    my ($self) = {};

    $class = ref($class) || $class;

    bless $self, $class;
}

sub create
{
    my ($class, $type, $coverage, $subFeatureFlags, $length) = @_;

    $class = ref($class) || $class;

    my $subclass;
    if ($type == 0) {
        $subclass = 'Font::TTF::Mort::Rearrangement';
    }
    elsif ($type == 1) {
        $subclass = 'Font::TTF::Mort::Contextual';
    }
    elsif ($type == 2) {
        $subclass = 'Font::TTF::Mort::Ligature';
    }
    elsif ($type == 4) {
        $subclass = 'Font::TTF::Mort::Noncontextual';
    }
    elsif ($type == 5) {
        $subclass = 'Font::TTF::Mort::Insertion';
    }
    
    my ($self) = $subclass->new(
            (($coverage & 0x4000) ? 'RL' : 'LR'),
            (($coverage & 0x2000) ? 'VH' : ($coverage & 0x8000) ? 'V' : 'H'),
            $subFeatureFlags
        );

    $self->{'type'} = $type;
    $self->{'length'} = $length;

    $self;
}

=head2 $t->out($fh)

Writes the table to a file

=cut

sub out
{
    my ($self, $fh) = @_;
    
    my ($subtableStart) = $fh->tell();
    my ($type) = $self->{'type'};
    my ($coverage) = $type;
    $coverage += 0x4000 if $self->{'direction'} eq 'RL';
    $coverage += 0x2000 if $self->{'orientation'} eq 'VH';
    $coverage += 0x8000 if $self->{'orientation'} eq 'V';
    
    $fh->print(TTF_Pack("SSL", 0, $coverage, $self->{'subFeatureFlags'}));    # placeholder for length
    
    my ($dat) = $self->pack_sub();
    $fh->print($dat);
    
    my ($length) = $fh->tell() - $subtableStart;
    my ($padBytes) = (4 - ($length & 3)) & 3;
    $fh->print(pack("C*", (0) x $padBytes));
    $length += $padBytes;
    $fh->seek($subtableStart, IO::File::SEEK_SET);
    $fh->print(pack("n", $length));
    $fh->seek($subtableStart + $length, IO::File::SEEK_SET);
}

=head2 $t->print($fh)

Prints a human-readable representation of the table

=cut

sub post
{
    my ($self) = @_;
    
    my ($post) = $self->{' PARENT'}{' PARENT'}{' PARENT'}{'post'};
    if (defined $post) {
        $post->read;
    }
    else {
        $post = {};
    }
    
    return $post;
}

sub feat
{
    my ($self) = @_;
    
    return $self->{' PARENT'}->feat();
}

sub print
{
    my ($self, $fh) = @_;
    
    my ($feat) = $self->feat();
    my ($post) = $self->post();
    
    $fh = 'STDOUT' unless defined $fh;

    my ($type) = $self->{'type'};
    my ($subFeatureFlags) = $self->{'subFeatureFlags'};
    my ($defaultFlags) = $self->{' PARENT'}{'defaultFlags'};
    my ($featureEntries) = $self->{' PARENT'}{'featureEntries'};
    $fh->printf("\n\t%s table, %s, %s, subFeatureFlags = %08x # %s (%s)\n",
                subtable_type_($type), $_->{'direction'}, $_->{'orientation'}, $subFeatureFlags,
                "Default " . ((($subFeatureFlags & $defaultFlags) != 0) ? "On" : "Off"),
                join(", ",
                    map {
                        join(": ", $feat->settingName($_->{'type'}, $_->{'setting'}) )
                    } grep { ($_->{'enable'} & $subFeatureFlags) != 0 } @$featureEntries
                ) );
}

sub subtable_type_
{
    my ($val) = @_;
    my ($res);
    
    my (@types) =    (
                        'Rearrangement',
                        'Contextual',
                        'Ligature',
                        undef,
                        'Non-contextual',
                        'Insertion',
                    );
    $res = $types[$val] or ('Undefined (' . $val . ')');
    
    $res;
}

=head2 $t->print_classes($fh)

Prints a human-readable representation of the table

=cut

sub print_classes
{
    my ($self, $fh) = @_;
    
    my ($post) = $self->post();
    
    my ($classes) = $self->{'classes'};
    foreach (0 .. $#$classes) {
        my $class = $classes->[$_];
        if (defined $class) {
            $fh->printf("\t\tClass %d:\t%s\n", $_, join(", ", map { $_ . " [" . $post->{'VAL'}[$_] . "]" } @$class));
        }
    }
}

1;

=head1 BUGS

None known

=head1 AUTHOR

Jonathan Kew L<Jonathan_Kew@sil.org>. See L<Font::TTF::Font> for copyright and
licensing.

=cut

