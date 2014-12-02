package Font::TTF::Ttopen;

=head1 NAME

Font::TTF::Ttopen - Opentype superclass for standard Opentype lookup based tables
(GSUB and GPOS)

=head1 DESCRIPTION

Handles all the script, lang, feature, lookup stuff for a
L<Font::TTF::Gsub>/L<Font::TTF::Gpos> table leaving the class specifics to the
subclass

=head1 INSTANCE VARIABLES

The instance variables of an opentype table form a complex sub-module hierarchy.

=over 4

=item Version

This contains the version of the table as a floating point number

=item SCRIPTS

The scripts list is a hash of script tags. Each script tag (of the form
$t->{'SCRIPTS'}{$tag}) has information below it.

=over 8

=item OFFSET

This variable is preceeded by a space and gives the offset from the start of the
table (not the table section) to the script table for this script

=item REFTAG

This variable is preceded by a space and gives a corresponding script tag to this
one such that the offsets in the file are the same. When writing, it is up to the
caller to ensure that the REFTAGs are set correctly, since these will be used to
assume that the scripts are identical. Note that REFTAG must refer to a script which
has no REFTAG of its own.

=item DEFAULT

This corresponds to the default language for this script, if there is one, and
contains the same information as an itemised language

=item LANG_TAGS

This contains an array of language tag strings (each 4 bytes) corresponding to
the languages listed by this script

=item $lang

Each language is a hash containing its information:

=over 12

=item OFFSET

This variable is preceeded by a a space and gives the offset from the start of
the whole table to the language table for this language

=item REFTAG

This variable is preceded by a space and has the same function as for the script
REFTAG, only for the languages within a script.

=item RE-ORDER

This indicates re-ordering information, and has not been set. The value should
always be 0.

=item DEFAULT

This holds the index of the default feature, if there is one, or -1 otherwise.

=item FEATURES

This is an array of feature tags for all the features enabled for this language

=back

=back

=item FEATURES

The features section of instance variables corresponds to the feature table in
the opentype table.

=over 8

=item FEAT_TAGS

This array gives the ordered list of feature tags for this table. It is used during
reading and writing for converting between feature index and feature tag.

=back

The rest of the FEATURES variable is itself a hash based on the feature tag for
each feature. Each feature has the following structure:

=over 8

=item OFFSET

This attribute is preceeded by a space and gives the offset relative to the start of the whole
table of this particular feature.

=item PARMS

This is an unused offset to the parameters for each feature

=item LOOKUPS

This is an array containing indices to lookups in the LOOKUP instance variable of the table

=item INDEX

This gives the feature index for this feature and is used during reading and writing for
converting between feature tag and feature index.

=back

=item LOOKUP

This variable is an array of lookups in order and is indexed via the features of a language of a
script. Each lookup contains subtables and other information:

=over 8

=item OFFSET

This name is preceeded by a space and contains the offset from the start of the table to this
particular lookup

=item TYPE

This is a subclass specific type for a lookup. It stipulates the type of lookup and hence subtables
within the lookup

=item FLAG

Holds the lookup flag bits

=item SUB

This holds an array of subtables which are subclass specific. Each subtable must have
an OFFSET. The other variables described here are an abstraction used in both the
GSUB and GPOS tables which are the target subclasses of this class.

=over 12

=item OFFSET

This is preceeded by a space and gives the offset relative to the start of the table for this
subtable

=item FORMAT

Gives the sub-table sub format for this GSUB subtable. It is assumed that this
value is correct when it comes time to write the subtable.

=item COVERAGE

Most lookups consist of a coverage table corresponding to the first
glyph to match. The offset of this coverage table is stored here and the coverage
table looked up against the GSUB table proper. There are two lookups
without this initial coverage table which is used to index into the RULES array.
These lookups have one element in the RULES array which is used for the whole
match.

=item RULES

The rules are a complex array. Each element of the array corresponds to an
element in the coverage table (governed by the coverage index). If there is
no coverage table, then there is considered to be only one element in the rules
array. Each element of the array is itself an array corresponding to the
possibly multiple string matches which may follow the initial glyph. Each
element of this array is a hash with fixed keys corresponding to information
needed to match a glyph string or act upon it. Thus the RULES element is an
array of arrays of hashes which contain the following keys:

=over 16

=item MATCH

This contains a sequence of elements held as an array. The elements may be
glyph ids (gid), class ids (cids), or offsets to coverage tables. Each element
corresponds to one glyph in the glyph string. See MATCH_TYPE for details of
how the different element types are marked.

=item PRE

This array holds the sequence of elements preceeding the first match element
and has the same form as the MATCH array.

=item POST

This array holds the sequence of elements to be tested for following the match
string and is of the same form as the MATCH array.

=item ACTION

This array holds information regarding what should be done if a match is found.
The array may either hold glyph ids (which are used to replace or insert or
whatever glyphs in the glyph string) or 2 element arrays consisting of:

=over 20

=item OFFSET

Offset from the start of the matched string that the lookup should start at
when processing the substring.

=item LOOKUP_INDEX

The index to a lookup to be acted upon on the match string.

=back

=back

=back

=back

=item CLASS

For those lookups which use class categories rather than glyph ids for matching
this is the offset to the class definition used to categories glyphs in the
match string.

=item PRE_CLASS

This is the offset to the class definition for the before match glyphs

=item POST_CLASS

This is the offset to the class definition for the after match glyphs.

=item ACTION_TYPE

This string holds the type of information held in the ACTION variable of a RULE.
It is subclass specific.

=item MATCH_TYPE

This holds the type of information in the MATCH array of a RULE. This is subclass
specific.

=item ADJUST

This corresponds to a single action for all items in a coverage table. The meaning
is subclass specific.

=item CACHE

This key starts with a space

A hash of other tables (such as coverage tables, classes, anchors, device tables)
based on the offset given in the subtable to that other information.
Note that the documentation is particularly
unhelpful here in that such tables are given as offsets relative to the
beginning of the subtable not the whole GSUB table. This includes those items which
are stored relative to another base within the subtable.

=back


=head1 METHODS

=cut

use Font::TTF::Table;
use Font::TTF::Utils;
use Font::TTF::Coverage;
use strict;
use vars qw(@ISA);

@ISA = qw(Font::TTF::Table);

=head2 $t->read

Reads the table passing control to the subclass to handle the subtable specifics

=cut

sub read
{
    my ($self) = @_;
    my ($dat, $i, $l, $oScript, $oFeat, $oLook, $tag, $nScript, $off, $dLang, $nLang, $lTag);
    my ($nFeat, $nLook, $nSub, $j, $temp);
    my ($fh) = $self->{' INFILE'};
    my ($moff) = $self->{' OFFSET'};

    $self->SUPER::read or return $self;
    $fh->read($dat, 10);
    ($self->{'Version'}, $oScript, $oFeat, $oLook) = TTF_Unpack("vSSS", $dat);

# read features first so that in the script/lang hierarchy we can use feature tags

    $fh->seek($moff + $oFeat, 0);
    $fh->read($dat, 2);
    $nFeat = unpack("n", $dat);
    $self->{'FEATURES'} = {};
    $l = $self->{'FEATURES'};
    $fh->read($dat, 6 * $nFeat);
    for ($i = 0; $i < $nFeat; $i++)
    {
    	($tag, $off) = unpack("a4n", substr($dat, $i * 6, 6));
    	while (defined $l->{$tag})
    	{
    	    if ($tag =~ m/(.*?)\s_(\d+)$/o)
    	    { $tag = $1 . " _" . ($2 + 1); }
    	    else
    	    { $tag .= " _0"; }
    	}
	    $l->{$tag}{' OFFSET'} = $off + $oFeat;
	    $l->{$tag}{'INDEX'} = $i;
	    push (@{$l->{'FEAT_TAGS'}}, $tag);
    }

    foreach $tag (grep {m/^.{4}(?:\s_\d+)?$/o} keys %$l)
    {
	    $fh->seek($moff + $l->{$tag}{' OFFSET'}, 0);
    	$fh->read($dat, 4);
	    ($l->{$tag}{'PARMS'}, $nLook) = unpack("n2", $dat);
    	$fh->read($dat, $nLook * 2);
	    $l->{$tag}{'LOOKUPS'} = [unpack("n*", $dat)];
    }

# Now the script/lang hierarchy

    $fh->seek($moff + $oScript, 0);
    $fh->read($dat, 2);
    $nScript = unpack("n", $dat);
    $self->{'SCRIPTS'} = {};
    $l = $self->{'SCRIPTS'};
    $fh->read($dat, 6 * $nScript);
    for ($i = 0; $i < $nScript; $i++)
    {
    	($tag, $off) = unpack("a4n", substr($dat, $i * 6, 6));
    	$off += $oScript;
        foreach (keys %$l)
        { $l->{$tag}{' REFTAG'} = $_ if ($l->{$_}{' OFFSET'} == $off
                                        && !defined $l->{$_}{' REFTAG'}); }
	    $l->{$tag}{' OFFSET'} = $off;
    }

    foreach $tag (keys %$l)
    {
        next if ($l->{$tag}{' REFTAG'});
    	$fh->seek($moff + $l->{$tag}{' OFFSET'}, 0);
    	$fh->read($dat, 4);
    	($dLang, $nLang) = unpack("n2", $dat);
    	$l->{$tag}{'DEFAULT'}{' OFFSET'} =
    	        $dLang + $l->{$tag}{' OFFSET'} if $dLang;
    	$fh->read($dat, 6 * $nLang);
    	for ($i = 0; $i < $nLang; $i++)
    	{
    	    ($lTag, $off) = unpack("a4n", substr($dat, $i * 6, 6));
    	    $off += $l->{$tag}{' OFFSET'};
    	    $l->{$tag}{$lTag}{' OFFSET'} = $off;
            foreach (@{$l->{$tag}{'LANG_TAGS'}}, 'DEFAULT')
            { $l->{$tag}{$lTag}{' REFTAG'} = $_ if ($l->{$tag}{$_}{' OFFSET'} == $off
                                                   && !$l->{$tag}{$_}{' REFTAG'}); }
    	    push (@{$l->{$tag}{'LANG_TAGS'}}, $lTag);
    	}
    	foreach $lTag (@{$l->{$tag}{'LANG_TAGS'}}, 'DEFAULT')
    	{
    	    next unless defined $l->{$tag}{$lTag};
            next if ($l->{$tag}{$lTag}{' REFTAG'});
    	    $fh->seek($moff + $l->{$tag}{$lTag}{' OFFSET'}, 0);
    	    $fh->read($dat, 6);
    	    ($l->{$tag}{$lTag}{'RE-ORDER'}, $l->{$tag}{$lTag}{'DEFAULT'}, $nFeat) 
    	      = unpack("n3", $dat);
    	    $fh->read($dat, $nFeat * 2);
    	    $l->{$tag}{$lTag}{'FEATURES'} = [map {$self->{'FEATURES'}{'FEAT_TAGS'}[$_]} unpack("n*", $dat)];
    	}
    	foreach $lTag (@{$l->{$tag}{'LANG_TAGS'}}, 'DEFAULT')
    	{
       	    next unless $l->{$tag}{$lTag}{' REFTAG'};
    	    $temp = $l->{$tag}{$lTag}{' REFTAG'};
    	    $l->{$tag}{$lTag} = &copy($l->{$tag}{$temp});
    	    $l->{$tag}{$lTag}{' REFTAG'} = $temp;
    	}
    }
    foreach $tag (keys %$l)
    {
        next unless $l->{$tag}{' REFTAG'};
        $temp = $l->{$tag}{' REFTAG'};
        $l->{$tag} = &copy($l->{$temp});
        $l->{$tag}{' REFTAG'} = $temp;
    }

# And finally the lookups

    $fh->seek($moff + $oLook, 0);
    $fh->read($dat, 2);
    $nLook = unpack("n", $dat);
    $fh->read($dat, $nLook * 2);
    $i = 0;
    map { $self->{'LOOKUP'}[$i++]{' OFFSET'} = $_; } unpack("n*", $dat);

    for ($i = 0; $i < $nLook; $i++)
    {
    	$l = $self->{'LOOKUP'}[$i];
    	$fh->seek($l->{' OFFSET'} + $moff + $oLook, 0);
    	$fh->read($dat, 6);
    	($l->{'TYPE'}, $l->{'FLAG'}, $nSub) = unpack("n3", $dat);
    	$fh->read($dat, $nSub * 2);
    	$j = 0;
        my @offsets = unpack("n*", $dat);
        my $isExtension = ($l->{'TYPE'} == $self->extension());
    	for ($j = 0; $j < $nSub; $j++)
    	{
    	    $l->{'SUB'}[$j]{' OFFSET'} = $offsets[$j];
       	    $fh->seek($moff + $oLook + $l->{' OFFSET'} + $l->{'SUB'}[$j]{' OFFSET'}, 0);
    	    if ($isExtension)
    	    {
    	        $fh->read($dat, 8);
    	        my $longOff;
    	        (undef, $l->{'TYPE'}, $longOff) = unpack("nnN", $dat);
    	        $l->{'SUB'}[$j]{' OFFSET'} += $longOff;
        	    $fh->seek($moff + $oLook + $l->{' OFFSET'} + $l->{'SUB'}[$j]{' OFFSET'}, 0);
            }
	        $self->read_sub($fh, $l, $j);
	    }
    }
    return $self;
}

=head2 $t->read_sub($fh, $lookup, $index)

This stub is to allow subclasses to read subtables of lookups in a table specific manner. A
reference to the lookup is passed in along with the subtable index. The file is located at the
start of the subtable to be read

=cut

sub read_sub
{ }


=head2 $t->extension()

Returns the lookup number for the extension table that allows access to 32-bit offsets.

=cut

sub extension
{ }


=head2 $t->out($fh)

Writes this Opentype table to the output calling $t->out_sub for each sub table
at the appropriate point in the output. The assumption is that on entry the
number of scripts, languages, features, lookups, etc. are all resolved and
the relationships fixed. This includes a script's LANG_TAGS list and that all
scripts and languages in their respective dictionaries either have a REFTAG or contain
real data.

=cut

sub out
{
    my ($self, $fh) = @_;
    my ($i, $j, $base, $off, $tag, $t, $l, $lTag, $oScript, @script, @tags);
    my ($end, $nTags, @offs, $oFeat, $oLook, $nSub, $nSubs, $big, $out);

    return $self->SUPER::out($fh) unless $self->{' read'};

# First sort the features
    $i = 0;
    $self->{'FEATURES'}{'FEAT_TAGS'} = [sort grep {m/^.{4}(?:\s_\d+)?$/o} %{$self->{'FEATURES'}}]
            if (!defined $self->{'FEATURES'}{'FEAT_TAGS'});
    foreach $t (@{$self->{'FEATURES'}{'FEAT_TAGS'}})
    { $self->{'FEATURES'}{$t}{'INDEX'} = $i++; }

    $base = $fh->tell();
    $fh->print(TTF_Pack("v", $self->{'Version'}));
    $fh->print(pack("n3", 10, 0, 0));
    $oScript = $fh->tell() - $base;
    @script = sort grep {length($_) == 4} keys %{$self->{'SCRIPTS'}};
    $fh->print(pack("n", $#script + 1));
    foreach $t (@script)
    { $fh->print(pack("a4n", $t, 0)); }

    $end = $fh->tell();
    foreach $t (@script)
    {
        $fh->seek($end, 0);
        $tag = $self->{'SCRIPTS'}{$t};
        next if ($tag->{' REFTAG'});
    	$tag->{' OFFSET'} = tell($fh) - $base - $oScript;
    	$fh->print(pack("n2", 0, $#{$tag->{'LANG_TAGS'}} + 1));
    	foreach $lTag (sort @{$tag->{'LANG_TAGS'}})
    	{ $fh->print(pack("a4n", $lTag, 0)); }
    	foreach $lTag (@{$tag->{'LANG_TAGS'}}, 'DEFAULT')
    	{
    	    my ($def);
    	    $l = $tag->{$lTag};
    	    next if (!defined $l || (defined $l->{' REFTAG'} && $l->{' REFTAG'} ne ''));
    	    $l->{' OFFSET'} = $fh->tell() - $base - $oScript - $tag->{' OFFSET'};
    	    if (defined $l->{'DEFAULT'})
#    	    { $def = $self->{'FEATURES'}{$l->{'FEATURES'}[$l->{'DEFAULT'}]}{'INDEX'}; }
            { $def = $l->{'DEFAULT'}; }
    	    else
    	    { $def = -1; }
    	    $fh->print(pack("n*", $l->{'RE_ORDER'} || 0, $def, $#{$l->{'FEATURES'}} + 1,
    	            map {$self->{'FEATURES'}{$_}{'INDEX'} || 0} @{$l->{'FEATURES'}}));
    	}
    	$end = $fh->tell();
    	if ($tag->{'DEFAULT'}{' REFTAG'} || defined $tag->{'DEFAULT'}{'FEATURES'})
    	{
        	$fh->seek($base + $oScript + $tag->{' OFFSET'}, 0);
            if (defined $tag->{'DEFAULT'}{' REFTAG'})
            {
                my ($ttag);
                for ($ttag = $tag->{'DEFAULT'}{' REFTAG'}; defined $tag->{$ttag}{' REFTAG'}; $ttag = $tag->{$ttag}{' REFTAG'})
                { }
                $off = $tag->{$ttag}{' OFFSET'};
            }
            else
            { $off = $tag->{'DEFAULT'}{' OFFSET'}; }
        	$fh->print(pack("n", $off));
    	}
    	$fh->seek($base + $oScript + $tag->{' OFFSET'} + 4, 0);
    	foreach (sort @{$tag->{'LANG_TAGS'}})
    	{
            if (defined $tag->{$_}{' REFTAG'})
            {
                my ($ttag);
                for ($ttag = $tag->{$_}{' REFTAG'}; defined $tag->{$ttag}{' REFTAG'}; $ttag = $tag->{$ttag}{' REFTAG'})
                { }
                $off = $tag->{$ttag}{' OFFSET'};
            }
            else
            { $off = $tag->{$_}{' OFFSET'}; }
    	    $fh->print(pack("a4n", $_, $off));
    	}
    }
    $fh->seek($base + $oScript + 2, 0);
    foreach $t (@script)
    {
        $tag = $self->{'SCRIPTS'}{$t};
        $off = $tag->{' REFTAG'} ? $tag->{$tag->{' REFTAG'}}{' OFFSET'} : $tag->{' OFFSET'};
        $fh->print(pack("a4n", $t, $off));
    }

    $fh->seek($end, 0);
    $oFeat = $end - $base;
    $nTags = $#{$self->{'FEATURES'}{'FEAT_TAGS'}} + 1;
    $fh->print(pack("n", $nTags));
    $fh->print(pack("a4n", "    ", 0) x $nTags);
    
    foreach $t (@{$self->{'FEATURES'}{'FEAT_TAGS'}})
    {
        $tag = $self->{'FEATURES'}{$t};
        $tag->{' OFFSET'} = tell($fh) - $base - $oFeat;
        $fh->print(pack("n*", 0, $#{$tag->{'LOOKUPS'}} + 1, @{$tag->{'LOOKUPS'}}));
    }
    $end = $fh->tell();
    $fh->seek($oFeat + $base + 2, 0);
    foreach $t (@{$self->{'FEATURES'}{'FEAT_TAGS'}})
    { $fh->print(pack("a4n", $t, $self->{'FEATURES'}{$t}{' OFFSET'})); }

    undef $big;
    $fh->seek($end, 0);
    $oLook = $end - $base;
    
    # Start Lookup List Table
    $nTags = $#{$self->{'LOOKUP'}} + 1;
    $fh->print(pack("n", $nTags));
    $fh->print(pack("n", 0) x $nTags);
    $end = $fh->tell();		# end of LookupListTable = start of Lookups
    foreach $tag (@{$self->{'LOOKUP'}})
    { $nSubs += $self->num_sub($tag); }
    for ($i = 0; $i < $nTags; $i++)
    {
        $fh->seek($end, 0);
        $tag = $self->{'LOOKUP'}[$i];
        $off = $end - $base - $oLook;	# BH 2004-03-04
        # Is there room, from the start of this i'th lookup, for this and the remaining
        # lookups to be wrapped in extension lookups?
        if (!defined $big && $off + ($nTags - $i) * 6 + $nSubs * 10 > 65535) # BH 2004-03-04
        {
			# Not enough room -- need to start an extension!            
            my ($k, $ext);
            $ext = $self->extension();
            # Must turn previous lookup into the first extension
            $i--;
            $tag = $self->{'LOOKUP'}[$i];
            $end = $tag->{' OFFSET'} + $base + $oLook;
            $fh->seek($end, 0);
            $big = $i;
            # For this and the remaining lookups, build extensions lookups
            for ($j = $i; $j < $nTags; $j++)
            {
                $tag = $self->{'LOOKUP'}[$j];
                $nSub = $self->num_sub($tag);
                $fh->print(pack("nnn", $ext, $tag->{'FLAG'}, $nSub));
                $fh->print(pack("n*", map {$_ * 8 + 6 + $nSub * 2} (0 .. $nSub-1)));	# BH 2004-03-04
                $tag->{' EXT_OFFSET'} = $fh->tell();	# = first extension lookup subtable
                $tag->{' OFFSET'} = $tag->{' EXT_OFFSET'} - $nSub * 2 - 6 - $base - $oLook; # offset to this extension lookup
                for ($k = 0; $k < $nSub; $k++)
                { $fh->print(pack('nnN', 1, $tag->{'TYPE'}, 0)); }
            }
            
            $tag = $self->{'LOOKUP'}[$i];
            # Leave file positioned after all the extension lookups -- where the referenced lookups will start.
        }
        $tag->{' OFFSET'} = $off unless defined $big;	# BH 2004-03-04
        $nSub = $self->num_sub($tag);
        if (!defined $big)
        {
            $fh->print(pack("nnn", $tag->{'TYPE'}, $tag->{'FLAG'}, $nSub));
            $fh->print(pack("n", 0) x $nSub);
        }
        else
        { $end = $tag->{' EXT_OFFSET'}; }
        my (@offs, $out, @refs);
        for ($j = 0; $j < $nSub; $j++)
        {
            my ($ctables) = {};
            my ($base) = length($out);
            push(@offs, tell($fh) - $end + $base);
            $out .= $self->out_sub($fh, $tag, $j, $ctables, $base);
            push (@refs, [$ctables, $base]);
        }
        out_final($fh, $out, \@refs);
        $end = $fh->tell();
        if (!defined $big)
        {
            $fh->seek($tag->{' OFFSET'} + $base + $oLook + 6, 0);
            $fh->print(pack("n*", @offs));
        }
        else
        {
            $fh->seek($tag->{' EXT_OFFSET'}, 0);
            for ($j = 0; $j < $nSub; $j++)
            { $fh->print(pack('nnN', 1, $tag->{'TYPE'}, $offs[$j] - $j * 8)); }
        }
    }
    $fh->seek($oLook + $base + 2, 0);
    $fh->print(pack("n*", map {$self->{'LOOKUP'}[$_]{' OFFSET'}} (0 .. $nTags - 1)));
    $fh->seek($base + 6, 0);
    $fh->print(pack('n2', $oFeat, $oLook));
    $fh->seek($end, 0);
    $self;
}


=head2 $t->num_sub($lookup)

Asks the subclass to count the number of subtables for a particular lookup and to
return that value. Used in out().

=cut

sub num_sub
{
    my ($self, $lookup) = @_;

    return $#{$lookup->{'SUB'}} + 1;
}


=head2 $t->out_sub($fh, $lookup, $index)

This stub is to allow subclasses to output subtables of lookups in a table specific manner. A
reference to the lookup is passed in along with the subtable index. The file is located at the
start of the subtable to be output

=cut

sub out_sub
{ }

=head2 $t->dirty

Setting GPOS or GSUB dirty means that OS/2 may need updating, so set it dirty.

=cut

sub dirty
{
    my ($self, $val) = @_;
    my $res = $self->SUPER::dirty ($val);
    $self->{' PARENT'}{'OS/2'}->read->dirty($val) if exists $self->{' PARENT'}{'OS/2'};
    $res;
}

=head2 $t->maxContext

Returns the length of the longest opentype rule in this table.

=cut

sub maxContext
{
    my ($self) = @_;
    
    # Make sure table is read
    $self->read;

    # Calculate my contribution to OS/2 usMaxContext
    
    my ($maxcontext, $l, $s, $r, $m);
   
    for $l (@{$self->{'LOOKUP'}})        # Examine each lookup
    {
        for $s (@{$l->{'SUB'}})         # Multiple possible subtables for this lookup
        {
            for $r (@{$s->{'RULES'}})   # One ruleset for each covered glyph
            {
                for $m (@{$r})          # Multiple possible matches for this covered glyph 
                {
                    my $lgt;
                    $lgt++ if exists $s->{'COVERAGE'};  # Count 1 for the coverage table if it exists
                    for (qw(MATCH PRE POST))
                    {
                        $lgt += @{$m->{$_}} if exists $m->{$_};
                    }
                    $maxcontext = $lgt if $lgt > $maxcontext;
                }
            }
            
        }
    }
    
    $maxcontext;    
}    


=head2 $t->update

Unless $t->{' PARENT'}{' noharmony'} is true, update will make sure that GPOS and GSUB include 
the same scripts and languages. Any added scripts and languages will have empty feature sets.

=cut

# Assumes we are called on both GSUB and GPOS. So simply ADDS scripts and languages to $self that it finds
# in the other table.

sub update
{
    my ($self) = @_;
    
    return undef unless ($self->SUPER::update);

    # Enforce script/lang congruence unless asked not to:
    return $self if $self->{' PARENT'}{' noharmony'};

    # Find my sibling (GSUB or GPOS, depending on which I am)
    my $sibling = ref($self) eq 'Font::TTF::GSUB' ? 'GPOS' : ref($self) eq 'Font::TTF::GPOS' ? 'GSUB' : undef;
    return $self unless $sibling && exists $self->{' PARENT'}{$sibling};
    $sibling = $self->{' PARENT'}{$sibling};
    next unless defined $sibling;
    
    # Look through scripts defined in sibling:
    for my $sTag (grep {length($_) == 4} keys %{$sibling->{'SCRIPTS'}})
    {
        my $sibScript = $sibling->{'SCRIPTS'}{$sTag};
        $sibScript = $sibling->{$sibScript->{' REFTAG'}} if exists $sibScript->{' REFTAG'} && $sibScript->{' REFTAG'} ne '';
        
        $self->{'SCRIPTS'}{$sTag} = {} unless defined $self->{'SCRIPTS'}{$sTag}; # Create script if not present in $self
        
        my $myScript = $self->{'SCRIPTS'}{$sTag};
        $myScript = $self->{$myScript->{' REFTAG'}} if exists $myScript->{' REFTAG'} && $myScript->{' REFTAG'} ne '';
                
        foreach my $lTag (@{$sibScript->{'LANG_TAGS'}})
        {
            # Ok, found a script/lang that is in our sibling.
            next if exists $myScript->{$lTag};  # Already in $self
            
            # Need to create this lang:
            push @{$myScript->{'LANG_TAGS'}}, $lTag;
            $myScript->{$lTag} = { 'FEATURES' => [] };
        }
        unless (defined $myScript->{'DEFAULT'})
        {
            # Create default lang for this script. Link to 'dflt' if it exists
            $myScript->{'DEFAULT'} = exists $myScript->{'dflt'} ? {' REFTAG' => 'dflt'} : { 'FEATURES' => [] };
        }
    }
    $self;
}

=head1 Internal Functions & Methods

Most of these methods are used by subclasses for handling such things as coverage
tables.

=head2 copy($ref)

Internal function to copy the top level of a dictionary to create a new dictionary.
Only the top level is copied.

=cut

sub copy
{
    my ($ref) = @_;
    my ($res) = {};

    foreach (keys %$ref)
    { $res->{$_} = $ref->{$_}; }
    $res;
}


=head2 $t->read_cover($cover_offset, $lookup_loc, $lookup, $fh, $is_cover)

Reads a coverage table and stores the results in $lookup->{' CACHE'}, that is, if
it hasn't been read already.

=cut

sub read_cover
{
    my ($self, $offset, $base, $lookup, $fh, $is_cover) = @_;
    my ($loc) = $fh->tell();
    my ($cover, $str);

    return undef unless $offset;
    $str = sprintf("%X", $base + $offset);
    return $lookup->{' CACHE'}{$str} if defined $lookup->{' CACHE'}{$str};
    $fh->seek($base + $offset, 0);
    $cover = Font::TTF::Coverage->new($is_cover)->read($fh);
    $fh->seek($loc, 0);
    $lookup->{' CACHE'}{$str} = $cover;
    return $cover;
}


=head2 ref_cache($obj, $cache, $offset)

Internal function to keep track of the local positioning of subobjects such as
coverage and class definition tables, and their offsets.
What happens is that the cache is a hash of
sub objects indexed by the reference (using a string mashing of the
reference name which is valid for the duration of the reference) and holds a
list of locations in the output string which should be filled in with the
offset to the sub object when the final string is output in out_final.

Uses tricks for Tie::Refhash

=cut

sub ref_cache
{
    my ($obj, $cache, $offset) = @_;

    return 0 unless defined $obj;
    unless (defined $cache->{"$obj"})
    { push (@{$cache->{''}}, $obj); }
    push (@{$cache->{"$obj"}}, $offset);
    return 0;
}


=head2 out_final($fh, $out, $cache_list, $state)

Internal function to actually output everything to the file handle given that
now we know the offset to the first sub object to be output and which sub objects
are to be output and what locations need to be updated, we can now
generate everything. $cache_list is an array of two element arrays. The first element
is a cache object, the second is an offset to be subtracted from each reference
to that object made in the cache.

If $state is 1, then the output is not sent to the filehandle and the return value
is the string to be output. If $state is absent or 0 then output is not limited
by storing in a string first and the return value is "";

=cut

sub out_final
{
    my ($fh, $out, $cache_list, $state) = @_;
    my ($len) = length($out || '');
    my ($base_loc) = $state ? 0 : $fh->tell();
    my ($loc, $t, $r, $s, $master_cache, $offs, $str, %vecs);

    $fh->print($out || '') unless $state;       # first output the current attempt
    foreach $r (@$cache_list)
    {
        $offs = $r->[1];
        foreach $t (@{$r->[0]{''}})
        {
            $str = "$t";
            if (!defined $master_cache->{$str})
            {
                my ($vec) = $t->signature();
                if ($vecs{$vec})
                { $master_cache->{$str} = $master_cache->{$vecs{$vec}}; }
                else
                {
                    $vecs{$vec} = $str;
                    $master_cache->{$str} = ($state ? length($out) : $fh->tell())
                                                                       - $base_loc;
                    if ($state)
                    { $out .= $t->out($fh, 1); }
                    else
                    { $t->out($fh, 0); }
                }
            }
            foreach $s (@{$r->[0]{$str}})
            { substr($out, $s, 2) = pack('n', $master_cache->{$str} - $offs); }
        }
    }
    if ($state)
    { return $out; }
    else
    {
        $loc = $fh->tell();
        $fh->seek($base_loc, 0);
        $fh->print($out || '');       # the corrected version
        $fh->seek($loc, 0);
    }
}


=head2 $self->read_context($lookup, $fh, $type, $fmt, $cover, $count, $loc)

Internal method to read context (simple and chaining context) lookup subtables for
the GSUB and GPOS table types. The assumed values for $type correspond to those
for GSUB, so GPOS should adjust the values upon calling.

=cut

sub read_context
{
    my ($self, $lookup, $fh, $type, $fmt, $cover, $count, $loc) = @_;
    my ($dat, $i, $s, $t, @subst, @srec, $mcount, $scount);
    
    if ($type == 5 && $fmt < 3)
    {
        if ($fmt == 2)
        {
            $fh->read($dat, 2);
            $lookup->{'CLASS'} = $self->read_cover($count, $loc, $lookup, $fh, 0);
            $count = TTF_Unpack('S', $dat);
        }
        $fh->read($dat, $count << 1);
        foreach $s (TTF_Unpack('S*', $dat))
        {
            if ($s == 0)
            {
                push (@{$lookup->{'RULES'}}, []);
                next;
            }
            @subst = ();
            $fh->seek($loc + $s, 0);
            $fh->read($dat, 2);
            $t = TTF_Unpack('S', $dat);
            $fh->read($dat, $t << 1);
            foreach $t (TTF_Unpack('S*', $dat))
            {
                $fh->seek($loc + $s + $t, 0);
                @srec = ();
                $fh->read($dat, 4);
                ($mcount, $scount) = TTF_Unpack('S2', $dat);
                $mcount--;
                $fh->read($dat, ($mcount << 1) + ($scount << 2));
                for ($i = 0; $i < $scount; $i++)
                { push (@srec, [TTF_Unpack('S2', substr($dat,
                    ($mcount << 1) + ($i << 2), 4))]); }
                push (@subst, {'ACTION' => [@srec],
                               'MATCH' => [TTF_Unpack('S*',
                                    substr($dat, 0, $mcount << 1))]});
            }
            push (@{$lookup->{'RULES'}}, [@subst]);
        }
        $lookup->{'ACTION_TYPE'} = 'l';
        $lookup->{'MATCH_TYPE'} = ($fmt == 2 ? 'c' : 'g');
    } elsif ($type == 5 && $fmt == 3)
    {
        $fh->read($dat, ($cover << 1) + ($count << 2));
        @subst = (); @srec = ();
        for ($i = 0; $i < $cover; $i++)
        { push (@subst, $self->read_cover(TTF_Unpack('S', substr($dat, $i << 1, 2)),
                                $loc, $lookup, $fh, 1)); }
        for ($i = 0; $i < $count; $i++)
        { push (@srec, [TTF_Unpack('S2', substr($dat, ($count << 1) + ($i << 2), 4))]); }
        $lookup->{'RULES'} = [[{'ACTION' => [@srec], 'MATCH' => [@subst]}]];
        $lookup->{'ACTION_TYPE'} = 'l';
        $lookup->{'MATCH_TYPE'} = 'o';
    } elsif ($type == 6 && $fmt < 3)
    {
        if ($fmt == 2)
        {
            $fh->read($dat, 6);
            $lookup->{'PRE_CLASS'} = $self->read_cover($count, $loc, $lookup, $fh, 0) if $count;
            ($i, $mcount, $count) = TTF_Unpack('S3', $dat);     # messy: 2 classes & count
            $lookup->{'CLASS'} = $self->read_cover($i, $loc, $lookup, $fh, 0) if $i;
            $lookup->{'POST_CLASS'} = $self->read_cover($mcount, $loc, $lookup, $fh, 0) if $mcount;
        }
        $fh->read($dat, $count << 1);
        foreach $s (TTF_Unpack('S*', $dat))
        {
            if ($s == 0)
            {
                push (@{$lookup->{'RULES'}}, []);
                next;
            }
            @subst = ();
            $fh->seek($loc + $s, 0);
            $fh->read($dat, 2);
            $t = TTF_Unpack('S', $dat);
            $fh->read($dat, $t << 1);
            foreach $i (TTF_Unpack('S*', $dat))
            {
                $fh->seek($loc + $s + $i, 0);
                @srec = ();
                $t = {};
                $fh->read($dat, 2);
                $mcount = TTF_Unpack('S', $dat);
                if ($mcount > 0)
                {
                    $fh->read($dat, $mcount << 1);
                    $t->{'PRE'} = [TTF_Unpack('S*', $dat)];
                }
                $fh->read($dat, 2);
                $mcount = TTF_Unpack('S', $dat);
                if ($mcount > 1)
                {
                    $fh->read($dat, ($mcount - 1) << 1);
                    $t->{'MATCH'} = [TTF_Unpack('S*', $dat)];
                }
                $fh->read($dat, 2);
                $mcount = TTF_Unpack('S', $dat);
                if ($mcount > 0)
                {
                    $fh->read($dat, $mcount << 1);
                    $t->{'POST'} = [TTF_Unpack('S*', $dat)];
                }
                $fh->read($dat, 2);
                $scount = TTF_Unpack('S', $dat);
                $fh->read($dat, $scount << 2);
                for ($i = 0; $i < $scount; $i++)
                { push (@srec, [TTF_Unpack('S2', substr($dat, $i << 2))]); }
                $t->{'ACTION'} = [@srec];
                push (@subst, $t);
            }
            push (@{$lookup->{'RULES'}}, [@subst]);
        }
        $lookup->{'ACTION_TYPE'} = 'l';
        $lookup->{'MATCH_TYPE'} = ($fmt == 2 ? 'c' : 'g');
    } elsif ($type == 6 && $fmt == 3)
    {
        $t = {};
        unless ($cover == 0)
        {
            @subst = ();
            $fh->read($dat, $cover << 1);
            foreach $s (TTF_Unpack('S*', $dat))
            { push(@subst, $self->read_cover($s, $loc, $lookup, $fh, 1)); }
            $t->{'PRE'} = [@subst];
        }
        $fh->read($dat, 2);
        $count = TTF_Unpack('S', $dat);
        unless ($count == 0)
        {
            @subst = ();
            $fh->read($dat, $count << 1);
            foreach $s (TTF_Unpack('S*', $dat))
            { push(@subst, $self->read_cover($s, $loc, $lookup, $fh, 1)); }
            $t->{'MATCH'} = [@subst];
        }
        $fh->read($dat, 2);
        $count = TTF_Unpack('S', $dat);
        unless ($count == 0)
        {
            @subst = ();
            $fh->read($dat, $count << 1);
            foreach $s (TTF_Unpack('S*', $dat))
            { push(@subst, $self->read_cover($s, $loc, $lookup, $fh, 1)); }
            $t->{'POST'} = [@subst];
        }
        $fh->read($dat, 2);
        $count = TTF_Unpack('S', $dat);
        @subst = ();
        $fh->read($dat, $count << 2);
        for ($i = 0; $i < $count; $i++)
        { push (@subst, [TTF_Unpack('S2', substr($dat, $i << 2, 4))]); }
        $t->{'ACTION'} = [@subst];
        $lookup->{'RULES'} = [[$t]];
        $lookup->{'ACTION_TYPE'} = 'l';
        $lookup->{'MATCH_TYPE'} = 'o';
    }
    $lookup;
}


=head2 $self->out_context($lookup, $fh, $type, $fmt, $ctables, $out, $num)

Provides shared behaviour between GSUB and GPOS tables during output for context
(chained and simple) rules. In addition, support is provided here for type 4 GSUB
tables, which are not used in GPOS. The value for $type corresponds to the type
in a GSUB table so calling from GPOS should adjust the value accordingly.

=cut

sub out_context
{
    my ($self, $lookup, $fh, $type, $fmt, $ctables, $out, $num, $base) = @_;
    my ($offc, $offd, $i, $j, $r, $t, $numd);

    $out ||= '';
    if (($type == 4 || $type == 5 || $type == 6) && ($fmt == 1 || $fmt == 2))
    {
        my ($base_off);
        
        if ($fmt == 1)
        {
            $out = pack("nnn", $fmt, Font::TTF::Ttopen::ref_cache($lookup->{'COVERAGE'}, $ctables, 2 + $base),
                            $num);
            $base_off = 6;
        } elsif ($type == 5)
        {
            $out = pack("nnnn", $fmt, Font::TTF::Ttopen::ref_cache($lookup->{'COVERAGE'}, $ctables, 2 + $base),
                            Font::TTF::Ttopen::ref_cache($lookup->{'CLASS'}, $ctables, 4 + $base), $num);
            $base_off = 8;
        } elsif ($type == 6)
        {
            $out = pack("n6", $fmt, Font::TTF::Ttopen::ref_cache($lookup->{'COVERAGE'}, $ctables, 2 + $base),
                                Font::TTF::Ttopen::ref_cache($lookup->{'PRE_CLASS'}, $ctables, 4 + $base),
                                Font::TTF::Ttopen::ref_cache($lookup->{'CLASS'}, $ctables, 6 + $base),
                                Font::TTF::Ttopen::ref_cache($lookup->{'POST_CLASS'}, $ctables, 8 + $base),
                                $num);
            $base_off = 12;
        }

        $out .= pack('n*', (0) x $num);
        $offc = length($out);
        for ($i = 0; $i < $num; $i++)
        {
            $r = $lookup->{'RULES'}[$i];
            next unless exists $r->[0]{'ACTION'};
            $numd = $#{$r} + 1;
            substr($out, ($i << 1) + $base_off, 2) = pack('n', $offc);
            $out .= pack('n*', $numd, (0) x $numd);
            $offd = length($out) - $offc;
            for ($j = 0; $j < $numd; $j++)
            {
                substr($out, $offc + 2 + ($j << 1), 2) = pack('n', $offd);
                if ($type == 4)
                {
                    $out .= pack('n*', $r->[$j]{'ACTION'}[0], $#{$r->[$j]{'MATCH'}} + 2,
                                        @{$r->[$j]{'MATCH'}});
                } elsif ($type == 5)
                {
                    $out .= pack('n*', $#{$r->[$j]{'MATCH'}} + 2,
                                        $#{$r->[$j]{'ACTION'}} + 1,
                                        @{$r->[$j]{'MATCH'}});
                    foreach $t (@{$r->[$j]{'ACTION'}})
                    { $out .= pack('n2', @$t); }
                } elsif ($type == 6)
                {
                    $out .= pack('n*', $#{$r->[$j]{'PRE'}} + 1, @{$r->[$j]{'PRE'}},
                                    $#{$r->[$j]{'MATCH'}} + 2, @{$r->[$j]{'MATCH'}},
                                    $#{$r->[$j]{'POST'}} + 1, @{$r->[$j]{'POST'}},
                                    $#{$r->[$j]{'ACTION'}} + 1);
                    foreach $t (@{$r->[$j]{'ACTION'}})
                    { $out .= pack('n2', @$t); }
                }
                $offd = length($out) - $offc;
            }
            $offc = length($out);
        }
    } elsif ($type == 5 && $fmt == 3)
    {
        $out .= pack('n3', $fmt, $#{$lookup->{'RULES'}[0][0]{'MATCH'}} + 1,
                                $#{$lookup->{'RULES'}[0][0]{'ACTION'}} + 1);
        foreach $t (@{$lookup->{'RULES'}[0][0]{'MATCH'}})
        { $out .= pack('n', Font::TTF::Ttopen::ref_cache($t, $ctables, length($out) + $base)); }
        foreach $t (@{$lookup->{'RULES'}[0][0]{'ACTION'}})
        { $out .= pack('n2', @$t); }
    } elsif ($type == 6 && $fmt == 3)
    {
        $r = $lookup->{'RULES'}[0][0];
		no strict 'refs';	# temp fix - more code needed (probably "if" statements in the event 'PRE' or 'POST' are empty)
        $out .= pack('n2', $fmt, defined $r->{'PRE'} ? scalar @{$r->{'PRE'}} : 0);
        foreach $t (@{$r->{'PRE'}})
        { $out .= pack('n', Font::TTF::Ttopen::ref_cache($t, $ctables, length($out) + $base)); }
        $out .= pack('n', defined $r->{'MATCH'} ? scalar @{$r->{'MATCH'}} : 0);
        foreach $t (@{$r->{'MATCH'}})
        { $out .= pack('n', Font::TTF::Ttopen::ref_cache($t, $ctables, length($out) + $base)); }
        $out .= pack('n', defined $r->{'POST'} ? scalar @{$r->{'POST'}} : 0);
        foreach $t (@{$r->{'POST'}})
        { $out .= pack('n', Font::TTF::Ttopen::ref_cache($t, $ctables, length($out) + $base)); }
        $out .= pack('n', defined $r->{'ACTION'} ? scalar @{$r->{'ACTION'}} : 0);
        foreach $t (@{$r->{'ACTION'}})
        { $out .= pack('n2', @$t); }
    }
    $out;
}

=head1 BUGS

=over 4

=item *

No way to share cachable items (coverage tables, classes, anchors, device tables)
across different lookups. The items are always output after the lookup and
repeated if necessary. Within lookup sharing is possible.

=back

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

1;

