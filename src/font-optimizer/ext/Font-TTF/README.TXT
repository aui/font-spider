        Perl Module: Font::TTF

=head1 Introduction

Perl module for TrueType font hacking. Supports reading, processing and
writing of the following tables: GDEF, GPOS, GSUB, LTSH, OS/2, PCLT,
bsln, cmap, cvt, fdsc, feat, fpgm, glyf, hdmx, head, hhea, hmtx, kern,
loca, maxp, mort, name, post, prep, prop, vhea, vmtx and the reading and
writing of all other table types.

In short, you can do almost anything with a standard TrueType font with
this module. Be Brave!

Any suggestions, improvements, additions, subclasses, etc. would be gratefully
received and probably included in a future release. Please send them to me.

This module has been tested on Win32, Unix and Mac.

Applications that were associated with this module have been moved to Font::TTF::Scripts where great things can be done.

=head1 SYNOPSIS

Here is the regression test (you provide your own font). Run it once and then
again on the output of the first run. There should be no differences between
the outputs of the two runs.

    use Font::TTF::Font;

    $f = Font::TTF::Font->open($ARGV[0]);

    # force a read of all the tables
    $f->tables_do(sub { $_[0]->read; });

    # force read of all glyphs (use read_dat to use lots of memory!)
    # $f->{'loca'}->glyphs_do(sub { $_[0]->read; });
    $f->{'loca'}->glyphs_do(sub { $_[0]->read_dat; });
    # NB. no need to $g->update since $_[0]->{'glyf'}->out will do it for us

    $f->out($ARGV[1]);
    $f->DESTROY;               # forces close of $in and maybe memory reclaim!

=head1 Installation

If you have received this package as part of an Activestate PPM style .zip file
then type

    ppm install Font-TTF.ppd

Otherwise.

To configure this module, cd to the directory that contains this README file
and type the following.

    perl Makefile.PL

Alternatively, if you plan to install Font::TTF somewhere other than
your system's perl library directory. You can type something like this:

    perl Makefile.PL PREFIX=/home/me/perl INSTALLDIRS=perl

Then to build you run make.

    make

If you have write access to the perl library directories, you may then
install by typing:

    make install

To tidy up, type:

    make realclean

Win32 users should use pmake instead of make. Alternatively installation can be
done on Win32 by typing:

    Setup

Or using the install feature in tools like WinZip.

=head1 CHANGES

=head2 Future Changes

I do not anticipate any more restructuring changes (but reserve the right to do so).

=head1 AUTHOR

Martin Hosken L<Martin_Hosken@sil.org>

Copyright Martin Hosken 1998 and following.

No warranty or expression of effectiveness for anything, least of all anyone's
safety, is implied in this software or documentation.

=head2 Licensing

The Perl TTF module is licensed under the Perl Artistic License.

