package Font::TTF::XMLparse;

=head1 NAME

Font::TTF::XMLparse - provides support for XML parsing. Requires Expat module XML::Parser::Expat

=head1 SYNOPSIS

    use Font::TTF::Font;
    use Font::TTF::XMLparse;

    $f = Font::TTF::Font->new;
    read_xml($f, $ARGV[0]);
    $f->out($ARGV[1]);

=head1 DESCRIPTION

This module contains the support routines for parsing XML and generating the
Truetype font structures as a result. The module has been separated from the rest
of the package in order to reduce the dependency that this would bring, of the
whole package on XML::Parser. This way, people without the XML::Parser can still
use the rest of the package.

The package interacts with another package through the use of a context containing
and element 'receiver' which is an object which can possibly receive one of the
following messages:

=over 4

=item XML_start

This message is called when an open tag occurs. It is called with the context,
tag name and the attributes. The return value has no meaning.

=item XML_end

This messages is called when a close tag occurs. It is called with the context,
tag name and attributes (held over from when the tag was opened). There are 3
possible return values from such a message:

=over 8

=item undef

This is the default return value indicating that default processing should
occur in which either the current element on the tree, or the text of this element
should be stored in the parent object.

=item $context

This magic value marks that the element should be deleted from the parent.
Nothing is stored in the parent. (This rather than '' is used to allow 0 returns.)

=item anything

Anything else is taken as the element content to be stored in the parent.

=back 4

=back 4

In addition, the context hash passed to these messages contains the following
keys:

=over 4

=item xml

This is the expat xml object. The context is also available as
$context->{'xml'}{' mycontext'}. But that is a long winded way of not saying much!

=item font

This is the base object that was passed in for XML parsing.

=item receiver

This holds the current receiver of parsing events. It may be set in associated
application to adjust which objects should receive messages when. It is also stored
in the parsing stack to ensure that where an object changes it during XML_start, that
that same object that received XML_start will receive the corresponding XML_end

=item stack

This is the parsing stack, used internally to hold the current receiver and attributes
for each element open, as a complete hierarchy back to the root element.

=item tree

This element contains the storage tree corresponding to the parent of each element
in the stack. The default action is to push undef onto this stack during XML_start
and then to resolve this, either in the associated application (by changing
$context->{'tree'}[-1]) or during XML_end of a child element, by which time we know
whether we are dealing with an array or a hash or what.

=item text

Character processing is to insert all the characters into the text element of the
context for available use later.

=back 4

=head1 METHODS

=cut

use XML::Parser::Expat;
require Exporter;

use strict;
use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw(read_xml);

sub read_xml
{
    my ($font, $fname) = @_;

    my ($xml) = XML::Parser::Expat->new;
    my ($context) = {'xml' => $xml, 'font' => $font};

    $xml->setHandlers('Start' => sub {
            my ($x, $tag, %attrs) = @_;
            my ($context) = $x->{' mycontext'};
            my ($fn) = $context->{'receiver'}->can('XML_start');

            push(@{$context->{'tree'}}, undef);
            push(@{$context->{'stack'}}, [$context->{'receiver'}, {%attrs}]);
            &{$fn}($context->{'receiver'}, $context, $tag, %attrs) if defined $fn;
        },
        'End' => sub {
            my ($x, $tag) = @_;
            my ($context) = $x->{' mycontext'};
            my ($fn) = $context->{'receiver'}->can('XML_end');
            my ($stackinfo) = pop(@{$context->{'stack'}});
            my ($current, $res);

            $context->{'receiver'} = $stackinfo->[0];
            $context->{'text'} =~ s/^\s*(.*?)\s*$/$1/o;
            $res = &{$fn}($context->{'receiver'}, $context, $tag, %{$stackinfo->[1]}) if defined $fn;
            $current = pop(@{$context->{'tree'}});
            $current = $context->{'text'} unless (defined $current);
            $context->{'text'} = '';

            if (defined $res)
            {
                return if ($res eq $context);
                $current = $res;
            }
            return unless $#{$context->{'tree'}} >= 0;
            if ($tag eq 'elem')
            {
                $context->{'tree'}[-1] = [] unless defined $context->{'tree'}[-1];
                push (@{$context->{'tree'}[-1]}, $current);
            } else
            {
                $context->{'tree'}[-1] = {} unless defined $context->{'tree'}[-1];
                $context->{'tree'}[-1]{$tag} = $current;
            }
        },
        'Char' => sub {
            my ($x, $str) = @_;
            $x->{' mycontext'}{'text'} .= $str;
        });

    $xml->{' mycontext'} = $context;

    $context->{'receiver'} = $font;
    if (ref $fname)
    { return $xml->parse($fname); }
    else
    { return $xml->parsefile($fname); }
}


