package Font::TTF::Fpgm;

=head1 NAME

Font::TTF::Fpgm - Font program in a TrueType font. Called when a font is loaded

=head1 DESCRIPTION

This is a minimal class adding nothing beyond a table, but is a repository
for fpgm type information for those processes brave enough to address hinting.

=cut

use strict;
use vars qw(@ISA $VERSION);

@ISA = qw(Font::TTF::Table);

$VERSION = 0.0001;

=head2 $t->read

Reading this table is simply a process of reading all the data into the RAM
copy. Nothing more is done with it.

=cut

sub read
{
    $_[0]->read_dat;
    $_[0]->{' read'} = 1;
}

=head2 $t->out_xml($context, $depth)

Outputs Fpgm program as XML

=cut

sub out_xml
{
    my ($self, $context, $depth) = @_;
    my ($fh) = $context->{'fh'};
    my ($dat);

    $self->read;
    $dat = Font::TTF::Utils::XML_binhint($self->{' dat'});
    $dat =~ s/\n(?!$)/\n$depth$context->{'indent'}/omg;
    $fh->print("$depth<code>\n");
    $fh->print("$depth$context->{'indent'}$dat");
    $fh->print("$depth</code>\n");
    $self;
}


=head2 $t->XML_end($context, $tag, %attrs)

Parse all that hinting code

=cut

sub XML_end
{
    my ($self) = shift;
    my ($context, $tag, %attrs) = @_;

    if ($tag eq 'code')
    {
        $self->{' dat'} = Font::TTF::Utils::XML_hintbin($context->{'text'});
        return $context;
    } else
    { return $self->SUPER::XML_end(@_); }
}

1;

=head1 BUGS

None known

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

