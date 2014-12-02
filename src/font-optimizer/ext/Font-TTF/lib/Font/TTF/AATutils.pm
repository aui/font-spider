package Font::TTF::AATutils;

use strict;
use vars qw(@ISA @EXPORT);
require Exporter;

use Font::TTF::Utils;
use IO::File;

@ISA = qw(Exporter);
@EXPORT = qw(
    AAT_read_lookup
    AAT_pack_lookup
    AAT_write_lookup
    AAT_pack_classes
    AAT_write_classes
    AAT_pack_states
    AAT_write_states
    AAT_read_state_table
    AAT_read_subtable
    xmldump
);

sub xmldump
{
    my ($var, $links, $depth, $processedVars, $type) = @_;

    $processedVars = {} unless (defined $processedVars);
    print("<?xml version='1.0' encoding='UTF-8'?>\n") if $depth == 0;    # not necessarily true encoding for all text!

    my $indent = "\t" x $depth;

    my ($objType, $addr) = ($var =~ m/^.+=(.+)\((.+)\)$/);
    unless (defined $type) {
        if (defined $addr) {
            if (defined $processedVars->{$addr}) {
                if ($links) {
                    printf("%s%s\n", $indent, "<a href=\"#$addr\">$objType</a>");
                }
                else {
                    printf("%s%s\n", $indent, "<a>$objType</a>");
                }
                return;
            }
            $processedVars->{$addr} = 1;
        }
    }
    
    $type = ref $var unless defined $type;
    
    if ($type eq 'REF') {
        printf("%s<ref val=\"%s\"/>\n", $indent, $$var);
    }
    elsif ($type eq 'SCALAR') {
        printf("%s<scalar>%s</scalar>\n", $indent, $var);
    }
    elsif ($type eq 'ARRAY') {
        # printf("%s<array>\n", $indent);
        foreach (0 .. $#$var) {
            if (ref($var->[$_])) {
                printf("%s<arrayItem index=\"%d\">\n", $indent, $_);
                xmldump($var->[$_], $links, $depth + 1, $processedVars);
                printf("%s</arrayItem>\n", $indent);
            }
            else {
                printf("%s<arrayItem index=\"%d\">%s</arrayItem>\n", $indent, $_, $var->[$_]);
            }
        }
        # printf("%s</array>\n", $indent);
    }
    elsif ($type eq 'HASH') {
        # printf("%s<hash>\n", $indent);
        foreach (sort keys %$var) {
            if (ref($var->{$_})) {
                printf("%s<hashElem key=\"%s\">\n", $indent, $_);
                xmldump($var->{$_}, $links, $depth + 1, $processedVars);
                printf("%s</hashElem>\n", $indent);
            }
            else {
                printf("%s<hashElem key=\"%s\">%s</hashElem>\n", $indent, $_, $var->{$_});
            }
        }
        # printf("%s</hash>\n", $indent);
    }
    elsif ($type eq 'CODE') {
        printf("%s<CODE/>\n", $indent, $var);
    }
    elsif ($type eq 'GLOB') {
        printf("%s<GLOB/>\n", $indent, $var);
    }
    elsif ($type eq '') {
        printf("%s<val>%s</val>\n", $indent, $var);
    }
    else {
        if ($links) {
            printf("%s<obj class=\"%s\" id=\"#%s\">\n", $indent, $type, $addr);
        }
        else {
            printf("%s<obj class=\"%s\">\n", $indent, $type);
        }
        xmldump($var, $links, $depth + 1, $processedVars, $objType);
        printf("%s</obj>\n", $indent);
    }
}

=head2 ($classes, $states) = AAT_read_subtable($fh, $baseOffset, $subtableStart, $limits)

=cut

sub AAT_read_subtable
{
    my ($fh, $baseOffset, $subtableStart, $limits) = @_;
    
    my $limit = 0xffffffff;
    foreach (@$limits) {
        $limit = $_ if ($_ > $subtableStart and $_ < $limit);
    }
    die if $limit == 0xffffffff;
    
    my $dat;
    $fh->seek($baseOffset + $subtableStart, IO::File::SEEK_SET);
    $fh->read($dat, $limit - $subtableStart);
    
    $dat;
}

=head2 $length = AAT_write_state_table($fh, $classes, $states, $numExtraTables, $packEntry)

$packEntry is a subroutine for packing an entry into binary form, called as

$dat = $packEntry($entry, $entryTable, $numEntries)

where the entry is a comma-separated list of nextStateOffset, flags, actions

=cut

sub AAT_pack_state_table
{
    my ($classes, $states, $numExtraTables, $packEntry) = @_;
    
    my ($dat) = pack("n*", (0) x (4 + $numExtraTables));    # placeholders for stateSize, classTable, stateArray, entryTable
    
    my ($firstGlyph, $lastGlyph) = (0xffff, 0, 0);
    my (@classTable, $i);
    foreach $i (0 .. $#$classes) {
        my $class = $classes->[$i];
        foreach (@$class) {
            $firstGlyph = $_ if $_ < $firstGlyph;
            $lastGlyph = $_ if $_ > $lastGlyph;
            $classTable[$_] = $i;
        }
    }
    
    my $classTable = length($dat);
    $dat .= pack("nnC*", $firstGlyph, $lastGlyph - $firstGlyph + 1,
                    map { defined $classTable[$_] ? $classTable[$_] : 1 } ($firstGlyph .. $lastGlyph));
    $dat .= pack("C", 0) if (($lastGlyph - $firstGlyph) & 1) == 0;    # pad if odd number of glyphs
    
    my $stateArray = length($dat);
    my (@entries, %entries);
    my $state = $states->[0];
    my $stateSize = @$state;
    die "stateSize below minimum allowed (4)" if $stateSize < 4;
    die "stateSize (" . $stateSize . ") too small for max class number (" . $#$classes . ")" if $stateSize < $#$classes + 1;
    warn "state array has unreachable columns" if $stateSize > $#$classes + 1;

    foreach (@$states) {
        die "inconsistent state size" if @$_ != $stateSize;
        foreach (@$_) {
            my $actions = $_->{'actions'};
            my $entry = join(",", $stateArray + $_->{'nextState'} * $stateSize, $_->{'flags'}, ref($actions) eq 'ARRAY' ? @$actions : $actions);
            if (not defined $entries{$entry}) {
                push @entries, $entry;
                $entries{$entry} = $#entries;
                die "too many different state array entries" if $#entries == 256;
            }
            $dat .= pack("C", $entries{$entry});
        }
    }
    $dat .= pack("C", 0) if (@$states & 1) != 0 and ($stateSize & 1) != 0;    # pad if state array size is odd
    
    my $entryTable = length($dat);
    $dat .= map { &$packEntry($_, $entryTable, $#entries + 1) } @entries;
    
    my ($dat1) = pack("nnnn", $stateSize, $classTable, $stateArray, $entryTable);
    substr($dat, 0, length($dat1)) = $dat1;
    
    return $dat;
}

sub AAT_write_state_table
{
    my ($fh, $classes, $states, $numExtraTables, $packEntry) = @_;
    
    my $stateTableStart = $fh->tell();

    $fh->print(pack("n*", (0) x (4 + $numExtraTables)));    # placeholders for stateSize, classTable, stateArray, entryTable
    
    my ($firstGlyph, $lastGlyph) = (0xffff, 0, 0);
    my (@classTable, $i);
    foreach $i (0 .. $#$classes) {
        my $class = $classes->[$i];
        foreach (@$class) {
            $firstGlyph = $_ if $_ < $firstGlyph;
            $lastGlyph = $_ if $_ > $lastGlyph;
            $classTable[$_] = $i;
        }
    }
    
    my $classTable = $fh->tell() - $stateTableStart;
    $fh->print(pack("nnC*", $firstGlyph, $lastGlyph - $firstGlyph + 1,
                    map { defined $classTable[$_] ? $classTable[$_] : 1 } ($firstGlyph .. $lastGlyph)));
    $fh->print(pack("C", 0)) if (($lastGlyph - $firstGlyph) & 1) == 0;    # pad if odd number of glyphs
    
    my $stateArray = $fh->tell() - $stateTableStart;
    my (@entries, %entries);
    my $state = $states->[0];
    my $stateSize = @$state;
    die "stateSize below minimum allowed (4)" if $stateSize < 4;
    die "stateSize (" . $stateSize . ") too small for max class number (" . $#$classes . ")" if $stateSize < $#$classes + 1;
    warn "state array has unreachable columns" if $stateSize > $#$classes + 1;

    foreach (@$states) {
        die "inconsistent state size" if @$_ != $stateSize;
        foreach (@$_) {
            my $actions = $_->{'actions'};
            my $entry = join(",", $stateArray + $_->{'nextState'} * $stateSize, $_->{'flags'}, ref($actions) eq 'ARRAY' ? @$actions : $actions);
            if (not defined $entries{$entry}) {
                push @entries, $entry;
                $entries{$entry} = $#entries;
                die "too many different state array entries" if $#entries == 256;
            }
            $fh->print(pack("C", $entries{$entry}));
        }
    }
    $fh->print(pack("C", 0)) if (@$states & 1) != 0 and ($stateSize & 1) != 0;    # pad if state array size is odd
    
    my $entryTable = $fh->tell() - $stateTableStart;
    $fh->print(map { &$packEntry($_, $entryTable, $#entries + 1) } @entries);
    
    my $length = $fh->tell() - $stateTableStart;
    $fh->seek($stateTableStart, IO::File::SEEK_SET);
    $fh->print(pack("nnnn", $stateSize, $classTable, $stateArray, $entryTable));
    
    $fh->seek($stateTableStart + $length, IO::File::SEEK_SET);
    $length;
}

sub AAT_pack_classes
{
    my ($classes) = @_;
    
    my ($firstGlyph, $lastGlyph) = (0xffff, 0, 0);
    my (@classTable, $i);
    foreach $i (0 .. $#$classes) {
        my $class = $classes->[$i];
        foreach (@$class) {
            $firstGlyph = $_ if $_ < $firstGlyph;
            $lastGlyph = $_ if $_ > $lastGlyph;
            $classTable[$_] = $i;
        }
    }
    
    my ($dat) = pack("nnC*", $firstGlyph, $lastGlyph - $firstGlyph + 1,
                    map { defined $classTable[$_] ? $classTable[$_] : 1 } ($firstGlyph .. $lastGlyph));
    $dat .= pack("C", 0) if (($lastGlyph - $firstGlyph) & 1) == 0;    # pad if odd number of glyphs
    
    return $dat;
}

sub AAT_write_classes
{
    my ($fh, $classes) = @_;
    
    $fh->print(AAT_pack_classes($fh, $classes));
}

sub AAT_pack_states
{
    my ($classes, $stateArray, $states, $buildEntryProc) = @_;
    
    my ($entries, %entryHash);
    my $state = $states->[0];
    my $stateSize = @$state;
    
    die "stateSize below minimum allowed (4)" if $stateSize < 4;
    die "stateSize (" . $stateSize . ") too small for max class number (" . $#$classes . ")" if $stateSize < $#$classes + 1;
    warn "state array has unreachable columns" if $stateSize > $#$classes + 1;
    
    my ($dat);
    foreach (@$states) {
        die "inconsistent state size" if @$_ != $stateSize;
        foreach (@$_) {
            my $entry = join(",", $stateArray + $_->{'nextState'} * $stateSize, &$buildEntryProc($_));
            if (not defined $entryHash{$entry}) {
                push @$entries, $entry;
                $entryHash{$entry} = $#$entries;
                die "too many different state array entries" if $#$entries == 256;
            }
            $dat .= pack("C", $entryHash{$entry});
        }
    }
    $dat .= pack("C", 0) if (@$states & 1) != 0 and ($stateSize & 1) != 0;    # pad if state array size is odd

    ($dat, $stateSize, $entries);
}

sub AAT_write_states
{
    my ($fh, $classes, $stateArray, $states, $buildEntryProc) = @_;
    
    my ($entries, %entryHash);
    my $state = $states->[0];
    my $stateSize = @$state;
    
    die "stateSize below minimum allowed (4)" if $stateSize < 4;
    die "stateSize (" . $stateSize . ") too small for max class number (" . $#$classes . ")" if $stateSize < $#$classes + 1;
    warn "state array has unreachable columns" if $stateSize > $#$classes + 1;

    foreach (@$states) {
        die "inconsistent state size" if @$_ != $stateSize;
        foreach (@$_) {
            my $entry = join(",", $stateArray + $_->{'nextState'} * $stateSize, &$buildEntryProc($_));
            if (not defined $entryHash{$entry}) {
                push @$entries, $entry;
                $entryHash{$entry} = $#$entries;
                die "too many different state array entries" if $#$entries == 256;
            }
            $fh->print(pack("C", $entryHash{$entry}));
        }
    }
    $fh->print(pack("C", 0)) if (@$states & 1) != 0 and ($stateSize & 1) != 0;    # pad if state array size is odd

    ($stateSize, $entries);
}

=head2 ($classes, $states, $entries) = AAT_read_state_table($fh, $numActionWords)

=cut

sub AAT_read_state_table
{
    my ($fh, $numActionWords) = @_;
    
    my $stateTableStart = $fh->tell();
    my $dat;
    $fh->read($dat, 8);
    my ($stateSize, $classTable, $stateArray, $entryTable) = unpack("nnnn", $dat);
    
    my $classes;    # array of lists of glyphs

    $fh->seek($stateTableStart + $classTable, IO::File::SEEK_SET);
    $fh->read($dat, 4);
    my ($firstGlyph, $nGlyphs) = unpack("nn", $dat);
    $fh->read($dat, $nGlyphs);
    foreach (unpack("C*", $dat)) {
        if ($_ != 1) {
            my $class = $classes->[$_];
            push(@$class, $firstGlyph);
            $classes->[$_] = $class unless defined $classes->[$_];
        }
        $firstGlyph++;
    }

    $fh->seek($stateTableStart + $stateArray, IO::File::SEEK_SET);
    my $states;    # array of arrays of hashes{nextState, flags, actions}

    my $entrySize = 4 + ($numActionWords * 2);
    my $lastState = 1;
    my $entries;
    while ($#$states < $lastState) {
        $fh->read($dat, $stateSize);
        my @stateEntries = unpack("C*", $dat);
        my $state;
        foreach (@stateEntries) {
            if (not defined $entries->[$_]) {
                my $loc = $fh->tell();
                $fh->seek($stateTableStart + $entryTable + ($_ * $entrySize), IO::File::SEEK_SET);
                $fh->read($dat, $entrySize);
                my ($nextState, $flags, $actions);
                ($nextState, $flags, @$actions) = unpack("n*", $dat);
                $nextState -= $stateArray;
                $nextState /= $stateSize;
                $entries->[$_] = { 'nextState' => $nextState, 'flags' => $flags };
                $entries->[$_]->{'actions'} = $actions if $numActionWords > 0;
                $lastState = $nextState if ($nextState > $lastState);
                $fh->seek($loc, IO::File::SEEK_SET);
            }
            push(@$state, $entries->[$_]);
        }
        push(@$states, $state);
    }

    ($classes, $states, $entries);
}

=head2 ($format, $lookup) = AAT_read_lookup($fh, $valueSize, $length, $default)

=cut

sub AAT_read_lookup
{
    my ($fh, $valueSize, $length, $default) = @_;

    my $lookupStart = $fh->tell();
    my ($dat, $unpackChar);
    if ($valueSize == 1) {
        $unpackChar = "C";
    }
    elsif ($valueSize == 2) {
        $unpackChar = "n";
    }
    elsif ($valueSize == 4) {
        $unpackChar = "N";
    }
    else {
        die "unsupported value size";
    }
        
    $fh->read($dat, 2);
    my $format = unpack("n", $dat);
    my $lookup;
    
    if ($format == 0) {
        $fh->read($dat, $length - 2);
        my $i = -1;
        $lookup = { map { $i++; ($_ != $default) ? ($i, $_) : () } unpack($unpackChar . "*", $dat) };
    }
    
    elsif ($format == 2) {
        $fh->read($dat, 10);
        my ($unitSize, $nUnits, $searchRange, $entrySelector, $rangeShift) = unpack("nnnnn", $dat);
        die if $unitSize != 4 + $valueSize;
        foreach (1 .. $nUnits) {
            $fh->read($dat, $unitSize);
            my ($lastGlyph, $firstGlyph, $value) = unpack("nn" . $unpackChar, $dat);
            if ($firstGlyph != 0xffff and $value != $default) {
                foreach ($firstGlyph .. $lastGlyph) {
                    $lookup->{$_} = $value;
                }
            }
        }
    }
    
    elsif ($format == 4) {
        $fh->read($dat, 10);
        my ($unitSize, $nUnits, $searchRange, $entrySelector, $rangeShift) = unpack("nnnnn", $dat);
        die if $unitSize != 6;
        foreach (1 .. $nUnits) {
            $fh->read($dat, $unitSize);
            my ($lastGlyph, $firstGlyph, $offset) = unpack("nnn", $dat);
            if ($firstGlyph != 0xffff) {
                my $loc = $fh->tell();
                $fh->seek($lookupStart + $offset, IO::File::SEEK_SET);
                $fh->read($dat, ($lastGlyph - $firstGlyph + 1) * $valueSize);
                my @values = unpack($unpackChar . "*", $dat);
                foreach (0 .. $lastGlyph - $firstGlyph) {
                    $lookup->{$firstGlyph + $_} = $values[$_] if $values[$_] != $default;
                }
                $fh->seek($loc, IO::File::SEEK_SET);
            }
        }
    }
    
    elsif ($format == 6) {
        $fh->read($dat, 10);
        my ($unitSize, $nUnits, $searchRange, $entrySelector, $rangeShift) = unpack("nnnnn", $dat);
        die if $unitSize != 2 + $valueSize;
        foreach (1 .. $nUnits) {
            $fh->read($dat, $unitSize);
            my ($glyph, $value) = unpack("n" . $unpackChar, $dat);
            $lookup->{$glyph} = $value if $glyph != 0xffff and $value != $default;
        }
    }
    
    elsif ($format == 8) {
        $fh->read($dat, 4);
        my ($firstGlyph, $glyphCount) = unpack("nn", $dat);
        $fh->read($dat, $glyphCount * $valueSize);
        $firstGlyph--;
        $lookup = { map { $firstGlyph++; $_ != $default ? ($firstGlyph, $_) : () } unpack($unpackChar . "*", $dat) };
    }
    
    else {
        die "unknown lookup format";
    }

    $fh->seek($lookupStart + $length, IO::File::SEEK_SET);

    ($format, $lookup);
}

=head2 AAT_write_lookup($fh, $format, $lookup, $valueSize, $default)

=cut

sub AAT_pack_lookup
{
    my ($format, $lookup, $valueSize, $default) = @_;

    my $packChar;
    if ($valueSize == 1) {
        $packChar = "C";
    }
    elsif ($valueSize == 2) {
        $packChar = "n";
    }
    elsif ($valueSize == 4) {
        $packChar = "N";
    }
    else {
        die "unsupported value size";
    }
        
    my ($dat) = pack("n", $format);

    my ($firstGlyph, $lastGlyph) = (0xffff, 0);
    foreach (keys %$lookup) {
        $firstGlyph = $_ if $_ < $firstGlyph;
        $lastGlyph = $_ if $_ > $lastGlyph;
    }
    my $glyphCount = $lastGlyph - $firstGlyph + 1;

    if ($format == 0) {
        $dat .= pack($packChar . "*", map { defined $lookup->{$_} ? $lookup->{$_} : defined $default ? $default : $_ } (0 .. $lastGlyph));
    }

    elsif ($format == 2) {
        my $prev = $default;
        my $segStart = $firstGlyph;
        my $dat1;
        foreach ($firstGlyph .. $lastGlyph + 1) {
            my $val = $lookup->{$_};
            $val = $default unless defined $val;
            if ($val != $prev) {
                $dat1 .= pack("nn" . $packChar, $_ - 1, $segStart, $prev) if $prev != $default;
                $prev = $val;
                $segStart = $_;
            }
        }
        $dat1 .= pack("nn" . $packChar, 0xffff, 0xffff, 0);
        my $unitSize = 4 + $valueSize;
        $dat .= pack("nnnnn", $unitSize, TTF_bininfo(length($dat1) / $unitSize, $unitSize));
        $dat .= $dat1;
    }
        
    elsif ($format == 4) {
        my $segArray = new Font::TTF::Segarr($valueSize);
        $segArray->add_segment($firstGlyph, 1, map { $lookup->{$_} } ($firstGlyph .. $lastGlyph));
        my ($start, $end, $offset);
        $offset = 12 + @$segArray * 6 + 6;    # 12 is size of format word + binSearchHeader; 6 bytes per segment; 6 for terminating segment
        my $dat1;
        foreach (@$segArray) {
            $start = $_->{'START'};
            $end = $start + $_->{'LEN'} - 1;
            $dat1 .= pack("nnn", $end, $start, $offset);
            $offset += $_->{'LEN'} * 2;
        }
        $dat1 .= pack("nnn", 0xffff, 0xffff, 0);
        $dat .= pack("nnnnn", 6, TTF_bininfo(length($dat1) / 6, 6));
        $dat .= $dat1;
        foreach (@$segArray) {
            $dat1 = $_->{'VAL'};
            $dat .= pack($packChar . "*", @$dat1);
        }
    }
        
    elsif ($format == 6) {
        die "unsupported" if $valueSize != 2;
        my $dat1 = pack("n*", map { $_, $lookup->{$_} } sort { $a <=> $b } grep { $lookup->{$_} ne $default } keys %$lookup);
        my $unitSize = 2 + $valueSize;
        $dat .= pack("nnnnn", $unitSize, TTF_bininfo(length($dat1) / $unitSize, $unitSize));
        $dat .= $dat1;
    }
        
    elsif ($format == 8) {
        $dat .= pack("nn", $firstGlyph, $lastGlyph - $firstGlyph + 1);
        $dat .= pack($packChar . "*", map { defined $lookup->{$_} ? $lookup->{$_} : defined $default ? $default : $_ } ($firstGlyph .. $lastGlyph));
    }
    
    else {
        die "unknown lookup format";
    }
    
    my $padBytes = (4 - (length($dat) & 3)) & 3;
    $dat .= pack("C*", (0) x $padBytes);
    
    return $dat;
}

sub AAT_write_lookup
{
    my ($fh, $format, $lookup, $valueSize, $default) = @_;

    my $lookupStart = $fh->tell();
    my $packChar;
    if ($valueSize == 1) {
        $packChar = "C";
    }
    elsif ($valueSize == 2) {
        $packChar = "n";
    }
    elsif ($valueSize == 4) {
        $packChar = "N";
    }
    else {
        die "unsupported value size";
    }
        
    $fh->print(pack("n", $format));

    my ($firstGlyph, $lastGlyph) = (0xffff, 0);
    foreach (keys %$lookup) {
        $firstGlyph = $_ if $_ < $firstGlyph;
        $lastGlyph = $_ if $_ > $lastGlyph;
    }
    my $glyphCount = $lastGlyph - $firstGlyph + 1;

    if ($format == 0) {
        $fh->print(pack($packChar . "*", map { defined $lookup->{$_} ? $lookup->{$_} : defined $default ? $default : $_ } (0 .. $lastGlyph)));
    }

    elsif ($format == 2) {
        my $prev = $default;
        my $segStart = $firstGlyph;
        my $dat;
        foreach ($firstGlyph .. $lastGlyph + 1) {
            my $val = $lookup->{$_};
            $val = $default unless defined $val;
            if ($val != $prev) {
                $dat .= pack("nn" . $packChar, $_ - 1, $segStart, $prev) if $prev != $default;
                $prev = $val;
                $segStart = $_;
            }
        }
        $dat .= pack("nn" . $packChar, 0xffff, 0xffff, 0);
        my $unitSize = 4 + $valueSize;
        $fh->print(pack("nnnnn", $unitSize, TTF_bininfo(length($dat) / $unitSize, $unitSize)));
        $fh->print($dat);
    }
        
    elsif ($format == 4) {
        my $segArray = new Font::TTF::Segarr($valueSize);
        $segArray->add_segment($firstGlyph, 1, map { $lookup->{$_} } ($firstGlyph .. $lastGlyph));
        my ($start, $end, $offset);
        $offset = 12 + @$segArray * 6 + 6;    # 12 is size of format word + binSearchHeader; 6 bytes per segment; 6 for terminating segment
        my $dat;
        foreach (@$segArray) {
            $start = $_->{'START'};
            $end = $start + $_->{'LEN'} - 1;
            $dat .= pack("nnn", $end, $start, $offset);
            $offset += $_->{'LEN'} * 2;
        }
        $dat .= pack("nnn", 0xffff, 0xffff, 0);
        $fh->print(pack("nnnnn", 6, TTF_bininfo(length($dat) / 6, 6)));
        $fh->print($dat);
        foreach (@$segArray) {
            $dat = $_->{'VAL'};
            $fh->print(pack($packChar . "*", @$dat));
        }
    }
        
    elsif ($format == 6) {
        die "unsupported" if $valueSize != 2;
        my $dat = pack("n*", map { $_, $lookup->{$_} } sort { $a <=> $b } grep { $lookup->{$_} ne $default } keys %$lookup);
        my $unitSize = 2 + $valueSize;
        $fh->print(pack("nnnnn", $unitSize, TTF_bininfo(length($dat) / $unitSize, $unitSize)));
        $fh->print($dat);
    }
        
    elsif ($format == 8) {
        $fh->print(pack("nn", $firstGlyph, $lastGlyph - $firstGlyph + 1));
        $fh->print(pack($packChar . "*", map { defined $lookup->{$_} ? $lookup->{$_} : defined $default ? $default : $_ } ($firstGlyph .. $lastGlyph)));
    }
    
    else {
        die "unknown lookup format";
    }
    
    my $length = $fh->tell() - $lookupStart;
    my $padBytes = (4 - ($length & 3)) & 3;
    $fh->print(pack("C*", (0) x $padBytes));
    $length += $padBytes;
    
    $length;
}

1;

