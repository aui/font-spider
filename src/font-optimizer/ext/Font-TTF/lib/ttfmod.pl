#       Title:      TTFMOD.PL
#       Author:     M. Hosken
#       Description:    Read TTF file calling user functions for each table
#                       and output transformed tables to new TTF file.
#       Useage:     TTFMOD provides the complete control loop for processing
#                   the TTF files.  All that the caller need supply is an
#                   associative array of functions to call keyed by the TTF
#                   table name and the two filenames.
#
#           &ttfmod($infile, $outfile, *fns [, @must]);
#
#                   *fns is an associative array keyed by table name with
#                   values of the name of the subroutine in package main to
#                   be called to transfer the table from INFILE to OUTFILE.
#                   The subroutine is called with the following parameters and
#                   expected return values:
#
#           ($len, $csum) = &sub(*INFILE, *OUTFILE, $len);
#
#                   INFILE and OUTFILE are the input and output streams, $len
#                   is the length of the table according to the directory.
#                   The return values are $len = new length of table to be
#                   given in the table directory.  $csum = new value of table
#                   checksum.  A way to test that this is correct is to
#                   checksum the whole file (e.g. using CSUM.BAT) and to
#                   ensure that the value is 0xB1B0AFBA according to a 32 bit
#                   checksum calculated bigendien.
#
#                   @must consists of a list of tables which must exist in the
#                   final output file, either by being there alread or by being
#                   inserted.
#
# Modifications:
# MJPH  1.00    22-SEP-1994     Original
# MJPH  1.1     18-MAR-1998     Added @must to ttfmod()
# MJPH  1.1.1   25-MAR-1998     Added $csum to copytab (to make reusable)

package ttfmod;

sub main'ttfmod {
    local($infile, $outfile, *fns, @must) = @_;

    # open files as binary.  Notice OUTFILE is opened for update not just write
    open(INFILE, "$infile") || die "Unable top open \"$infile\" for reading";
    binmode INFILE;
    open(OUTFILE, "+>$outfile") || die "Unable to open \"$outfile\" for writing";
    binmode OUTFILE;

    seek(INFILE, 0, 0);
    read(INFILE, $dir_head, 12) || die "Reading table header";
    ($dir_num) = unpack("x4n", $dir_head);
    print OUTFILE $dir_head;
    # read and unpack table directory
    for ($i = 0; $i < $dir_num; $i++)
        {
        read(INFILE, $dir_val, 16) || die "Reading table entry";
        $dir{unpack("a4", $dir_val)} = join(":", $i, unpack("x4NNN", $dir_val));
        print OUTFILE $dir_val;
        printf STDERR "%s %08x\n", unpack("a4", $dir_val), unpack("x8N", $dir_val)
                if (defined $main'opt_z);
        }
    foreach $n (@must)
    {
        next if defined $dir{$n};
        $dir{$n} = "$i:0:-1:0";
        $i++; $dir_num++;
        print OUTFILE pack("a4NNN", $n, 0, -1, 0);
    }
    substr($dir_head, 4, 2) = pack("n", $dir_num);
    $csum = unpack("%32N*", $dir_head);
    $off = tell(OUTFILE);
    seek(OUTFILE, 0, 0);
    print OUTFILE $dir_head;
    seek (OUTFILE, $off, 0);
    # process tables in order they occur in the file
    @dirlist = sort byoffset keys(%dir);
    foreach $tab (@dirlist)
        {
        @tab_split = split(':', $dir{$tab});
        seek(INFILE, $tab_split[2], 0);         # offset
        $tab_split[2] = tell(OUTFILE);
        if (defined $fns{$tab})
            {
            $temp = "main'$fns{$tab}";
            ($dir_len, $sum) = &$temp(*INFILE, *OUTFILE, $tab_split[3]);
            }
        else
            {
            ($dir_len, $sum) = &copytab(*INFILE, *OUTFILE, $tab_split[3]);
            }
        $tab_split[3] = $dir_len;               # len
        $tab_split[1] = $sum;                   # checksum
        $out_dir{$tab} = join(":", @tab_split);
        }
    # now output directory in same order as original directory
    @dirlist = sort byindex keys(%out_dir);
    foreach $tab (@dirlist)
        {
        @tab_split = split(':', $out_dir{$tab});
        seek (OUTFILE, 12 + $tab_split[0] * 16, 0);     # directory index
        print OUTFILE pack("A4N3", $tab, @tab_split[1..3]);
        foreach $i (1..3, 1)        # checksum directory values with csum twice
            {
            $csum += $tab_split[$i];
    # this line ensures $csum stays within 32 bit bounds, clipping as necessary
            if ($csum > 0xffffffff) { $csum -= 0xffffffff; $csum--; }
            }
    # checksum the tag
        $csum += unpack("N", $tab);
        if ($csum > 0xffffffff) { $csum -= 0xffffffff; $csum--; }
        }
    # handle main checksum
    @tab_split = split(':', $out_dir{"head"});
    seek(OUTFILE, $tab_split[2], 0);
    read(OUTFILE, $head_head, 12);          # read first bit of "head" table
    @head_split = unpack("N3", $head_head);
    $tab_split[1] -= $head_split[2];        # subtract old checksum
    $csum -= $head_split[2] * 2;            # twice because had double effect
                                            # already
    if ($csum < 0 ) { $csum += 0xffffffff; $csum++; }
    $head_split[2] = 0xB1B0AFBA - $csum;    # calculate new checksum
    seek (OUTFILE, 12 + $tab_split[0] * 16, 0);
    print OUTFILE pack("A4N3", "head", @tab_split[1..3]);
    seek (OUTFILE, $tab_split[2], 0);       # rewrite first bit of "head" table
    print OUTFILE pack("N3", @head_split);

    # finish up
    close(OUTFILE);
    close(INFILE);
    }

# support function for sorting by table offset
sub byoffset {
    @t1 = split(':', $dir{$a});
    @t2 = split(':', $dir{$b});
    return 1 if ($t1[2] == -1);     # put inserted tables at the end
    return -1 if ($t2[2] == -1);
    return $t1[2] <=> $t2[2];
    }

# support function for sorting by directory entry order
sub byindex {
    $t1 = split(':', $dir{$a}, 1);
    $t2 = split(':', $dir{$b}, 1);
    return $t1 <=> $t2;
    }

# default table action: copies a table from input to output, recalculating
#   the checksum (just to be absolutely sure).
sub copytab {
    local(*INFILE, *OUTFILE, $len, $csum) = @_;

    while ($len > 0)
        {
        $count = ($len > 8192) ? 8192 : $len;       # 8K buffering
        read(INFILE, $buf, $count) == $count || die "Copying";
        $buf .= "\0" x (4 - ($count & 3)) if ($count & 3);      # pad to long
        print OUTFILE $buf;
        $csum += unpack("%32N*", $buf);
        if ($csum > 0xffffffff) { $csum -= 0xffffffff; $csum--; }
        $len -= $count;
        }
    ($_[2], $csum);
    }

# test routine to copy file from input to output, no changes
package main;

if ($test_package)
    {
    &ttfmod($ARGV[0], $ARGV[1], *dummy);
    }
else
    { 1; }
