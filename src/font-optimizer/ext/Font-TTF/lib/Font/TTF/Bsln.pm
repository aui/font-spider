package Font::TTF::Bsln;

=head1 NAME

Font::TTF::Bsln - Baseline table in a font

=head1 DESCRIPTION

=head1 INSTANCE VARIABLES

=item version

=item xformat

=item defaultBaseline

=item deltas

=item stdGlyph

=item ctlPoints

=item lookupFormat

=item lookup

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);

use Font::TTF::AATutils;
use Font::TTF::Utils;
require Font::TTF::Table;

@ISA = qw(Font::TTF::Table);

=head2 $t->read

Reads the table into memory

=cut

sub read
{
    my ($self) = @_;
    my ($dat, $fh);
    
    $self->SUPER::read or return $self;

    $fh = $self->{' INFILE'};
    $fh->read($dat, 8);
    my ($version, $format, $defaultBaseline) = TTF_Unpack("vSS", $dat);

    if ($format == 0 or $format == 1) {
        $fh->read($dat, 64);
        $self->{'deltas'} = [TTF_Unpack("s*", $dat)];
    }
    elsif ($format == 2 or $format == 3) {
        $fh->read($dat, 2);
        $self->{'stdGlyph'} = unpack("n", $dat);
        $fh->read($dat, 64);
        $self->{'ctlPoints'} = unpack("n*", $dat);
    }
    else {
        die "unknown table format";
    }
    
    if ($format == 1 or $format == 3) {
        my $len = $self->{' LENGTH'} - ($fh->tell() - $self->{' OFFSET'});
        my ($lookupFormat, $lookup) = AAT_read_lookup($fh, 2, $len, $defaultBaseline);
        $self->{'lookupFormat'} = $lookupFormat;
        $self->{'lookup'} = $lookup;
    }

    $self->{'version'} = $version;
    $self->{'format'} = $format;
    $self->{'defaultBaseline'} = $defaultBaseline;

    $self;
}

=head2 $t->out($fh)

Writes the table to a file either from memory or by copying

=cut

sub out
{
    my ($self, $fh) = @_;
    
    return $self->SUPER::out($fh) unless $self->{' read'};

    my $format = $self->{'format'};
    my $defaultBaseline = $self->{'defaultBaseline'};
    $fh->print(TTF_Pack("vSS", $self->{'version'}, $format, $defaultBaseline));

    AAT_write_lookup($fh, $self->{'lookupFormat'}, $self->{'lookup'}, 2, $defaultBaseline) if ($format == 1 or $format == 3);
}

=head2 $t->print($fh)

Prints a human-readable representation of the table

=cut

sub print
{
    my ($self, $fh) = @_;

    $self->read;
        
    $fh = 'STDOUT' unless defined $fh;
    
    my $format = $self->{'format'};
    $fh->printf("version %f\nformat %d\ndefaultBaseline %d\n", $self->{'version'}, $format, $self->{'defaultBaseline'});
    if ($format == 0 or $format == 1) {
        $fh->printf("\tdeltas:\n");
        my $deltas = $self->{'deltas'};
        foreach (0 .. 31) {
            $fh->printf("\t\t%d: %d%s\n", $_, $deltas->[$_], defined baselineName_($_) ? "\t# " . baselineName_($_) : "");
        }
    }
    if ($format == 2 or $format == 3) {
        $fh->printf("\tstdGlyph = %d\n", $self->{'stdGlyph'});
        my $ctlPoints = $self->{'ctlPoints'};
        foreach (0 .. 31) {
            $fh->printf("\t\t%d: %d%s\n", $_, $ctlPoints->[$_], defined baselineName_($_) ? "\t# " . baselineName_($_) : "");
        }
    }
    if ($format == 1 or $format == 3) {
        $fh->printf("lookupFormat %d\n", $self->{'lookupFormat'});
        my $lookup = $self->{'lookup'};
        foreach (sort { $a <=> $b } keys %$lookup) {
            $fh->printf("\tglyph %d: %d%s\n", $_, $lookup->{$_}, defined baselineName_($_) ? "\t# " . baselineName_($_) : "");
        }
    }
}

sub baselineName_
{
    my ($b) = @_;
    my @baselines = ( 'Roman', 'Ideographic centered', 'Ideographic low', 'Hanging', 'Math' );
    $baselines[$b];
}

1;


=head1 BUGS

None known

=head1 AUTHOR

Jonathan Kew L<Jonathan_Kew@sil.org>. See L<Font::TTF::Font> for copyright and
licensing.

=cut

