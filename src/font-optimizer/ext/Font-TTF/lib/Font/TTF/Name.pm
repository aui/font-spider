package Font::TTF::Name;

=head1 NAME

Font::TTF::Name - String table for a TTF font

=head1 DESCRIPTION

Strings are held by number, platform, encoding and language. Strings are
accessed as:

    $f->{'name'}{'strings'}[$number][$platform_id][$encoding_id]{$language_id}

Notice that the language is held in an associative array due to its sparse
nature on some platforms such as Microsoft ($pid = 3). Notice also that the
array order is different from the stored array order (platform, encoding,
language, number) to allow for easy manipulation of strings by number (which is
what I guess most people will want to do).

By default, C<$Font::TTF::Name::utf8> is set to 1, and strings will be stored as UTF8 wherever
possible. The method C<is_utf8> can be used to find out if a string in a particular
platform and encoding will be returned as UTF8. Unicode strings are always
converted if utf8 is requested. Otherwise, strings are stored according to platform:

You now have to set <$Font::TTF::Name::utf8> to 0 to get the old behaviour.

=over 4

=item Apple Unicode (platform id = 0)

Data is stored as network ordered UCS2. There is no encoding id for this platform
but there are language ids as per Mac language ids.

=item Mac (platform id = 1)

Data is stored as 8-bit binary data, leaving the interpretation to the user
according to encoding id.

=item Unicode (platform id = 2)

Currently stored as 16-bit network ordered UCS2. Upon release of Perl 5.005 this
will change to utf8 assuming current UCS2 semantics for all encoding ids.

=item Windows (platform id = 3)

As per Unicode, the data is currently stored as 16-bit network ordered UCS2. Upon
release of Perl 5.005 this will change to utf8 assuming current UCS2 semantics for
all encoding ids.

=back

=head1 INSTANCE VARIABLES

=over 4

=item strings

An array of arrays, etc.

=back

=head1 METHODS

=cut

use strict;
use vars qw(@ISA $VERSION @apple_encs @apple_encodings $utf8 $cp_1252 @cp_1252 %win_langs %langs_win %langs_mac @ms_langids @mac_langs);
use Font::TTF::Table;
use Font::TTF::Utils;
@ISA = qw(Font::TTF::Table);

$utf8 = 1;

{
    my ($count, $i);
    eval {require Compress::Zlib;};
    unless ($@)
    {
        for ($i = 0; $i <= $#apple_encs; $i++)
        {
            $apple_encodings[0][$i] = [unpack("n*", Compress::Zlib::uncompress(unpack("u", $apple_encs[$i])))]
                if (defined $apple_encs[$i]);
            foreach (0 .. 127)
            { $apple_encodings[0][$i][$_] = $_; }
            $count = 0;
            $apple_encodings[1][$i] = {map {$_ => $count++} @{$apple_encodings[0][$i]}};
        }
        $cp_1252[0] = [unpack("n*", Compress::Zlib::uncompress(unpack("u", $cp_1252)))];
        $count = 0;
        $cp_1252[1] = {map({$_ => $count++} @{$cp_1252[0]})};
    }
    for ($i = 0; $i < $#ms_langids; $i++)
    {
        if (defined $ms_langids[$i][1])
        {
            my ($j);
            for ($j = 0; $j < $#{$ms_langids[$i][1]}; $j++)
            {
                my ($v) = $ms_langids[$i][1][$j];
                if ($v =~ m/^-/o)
                { $win_langs{(($j + 1) << 10) + $i} = $ms_langids[$i][0] . $v; }
                else
                { $win_langs{(($j + 1) << 10) + $i} = $v; }
            }
        }
        else
        { $win_langs{$i + 0x400} = $ms_langids[$i][0]; }
    }
    %langs_win = map {my ($t) = $win_langs{$_}; my (@res) = ($t => $_); push (@res, $t => $_) if ($t =~ s/-.*$//o && ($_ & 0xFC00) == 0x400); @res} keys %win_langs;
    $i = 0;
    %langs_mac = map {$_ => $i++} @mac_langs;
}
    

$VERSION = 1.1;             # MJPH  17-JUN-2000     Add utf8 support
# $VERSION = 1.001;           # MJPH  10-AUG-1998     Put $number first in list

=head2 $t->read

Reads all the names into memory

=cut

sub read
{
    my ($self) = @_;
    my ($fh) = $self->{' INFILE'};
    my ($dat, $num, $stroff, $i, $pid, $eid, $lid, $nid, $len, $off, $here);

    $self->SUPER::read or return $self;
    $fh->read($dat, 6);
    ($num, $stroff) = unpack("x2nn", $dat);
    for ($i = 0; $i < $num; $i++)
    {
        use bytes;              # hack to fix bugs in 5.8.7
        read($fh, $dat, 12);
        ($pid, $eid, $lid, $nid, $len, $off) = unpack("n6", $dat);
        $here = $fh->tell();
        $fh->seek($self->{' OFFSET'} + $stroff + $off, 0);
        $fh->read($dat, $len);
        if ($utf8)
        {
            if ($pid == 1 && defined $apple_encodings[0][$eid])
            { $dat = TTF_word_utf8(pack("n*", map({$apple_encodings[0][$eid][$_]} unpack("C*", $dat)))); }
            elsif ($pid == 2 && $eid == 2 && defined @cp_1252)
            { $dat = TTF_word_utf8(pack("n*", map({$cp_1252[0][$_]} unpack("C*", $dat)))); }
            elsif ($pid == 0 || $pid == 3 || ($pid == 2 && $eid == 1))
            { $dat = TTF_word_utf8($dat); }
        }
        $self->{'strings'}[$nid][$pid][$eid]{$lid} = $dat;
        $fh->seek($here, 0);
    }
    $self;
}


=head2 $t->out($fh)

Writes out all the strings

=cut

sub out
{
    my ($self, $fh) = @_;
    my ($pid, $eid, $lid, $nid, $todo, @todo);
    my ($len, $offset, $loc, $stroff, $endloc, $str_trans);

    return $self->SUPER::out($fh) unless $self->{' read'};

    $loc = $fh->tell();
    $fh->print(pack("n3", 0, 0, 0));
    foreach $nid (0 .. $#{$self->{'strings'}})
    {
        foreach $pid (0 .. $#{$self->{'strings'}[$nid]})
        {
            foreach $eid (0 .. $#{$self->{'strings'}[$nid][$pid]})
            {
                foreach $lid (sort keys %{$self->{'strings'}[$nid][$pid][$eid]})
                {
                    $str_trans = $self->{'strings'}[$nid][$pid][$eid]{$lid};
                    if ($utf8)
                    {
                        if ($pid == 1 && defined $apple_encodings[1][$eid])
                        { $str_trans = pack("C*",
                                map({$apple_encodings[1][$eid]{$_} || 0x3F} unpack("n*",
                                TTF_utf8_word($str_trans)))); }
                        elsif ($pid == 2 && $eid == 2 && defined @cp_1252)
                        { $str_trans = pack("C*",
                                map({$cp_1252[1][$eid]{$_} || 0x3F} unpack("n*",
                                TTF_utf8_word($str_trans)))); }
                        elsif ($pid == 2 && $eid == 0)
                        { $str_trans =~ s/[\xc0-\xff][\x80-\xbf]+/?/og; }
                        elsif ($pid == 0 || $pid == 3 || ($pid == 2 && $eid == 1))
                        { $str_trans = TTF_utf8_word($str_trans); }
                    }
                    push (@todo, [$pid, $eid, $lid, $nid, $str_trans]);
                }
            }
        }
    }

    $offset = 0;
    @todo = (sort {$a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] || $a->[2] <=> $b->[2]
            || $a->[3] <=> $b->[3]} @todo);
    foreach $todo (@todo)
    {
        $len = length($todo->[4]);
        $fh->print(pack("n6", @{$todo}[0..3], $len, $offset));
        $offset += $len;
    }
    
    $stroff = $fh->tell() - $loc;
    foreach $todo (@todo)
    { $fh->print($todo->[4]); }

    $endloc = $fh->tell();
    $fh->seek($loc, 0);
    $fh->print(pack("n3", 0, $#todo + 1, $stroff));
    $fh->seek($endloc, 0);
    $self;
}


=head2 $t->XML_element($context, $depth, $key, $value)

Outputs the string element in nice XML (which is all the table really!)

=cut

sub XML_element
{
    my ($self) = shift;
    my ($context, $depth, $key, $value) = @_;
    my ($fh) = $context->{'fh'};
    my ($nid, $pid, $eid, $lid);

    return $self->SUPER::XML_element(@_) unless ($key eq 'strings');

    foreach $nid (0 .. $#{$self->{'strings'}})
    {
        next unless ref($self->{'strings'}[$nid]);
#        $fh->print("$depth<strings id='$nid'>\n");
        foreach $pid (0 .. $#{$self->{'strings'}[$nid]})
        {
            foreach $eid (0 .. $#{$self->{'strings'}[$nid][$pid]})
            {
                foreach $lid (sort {$a <=> $b} keys %{$self->{'strings'}[$nid][$pid][$eid]})
                {
                    my ($lang) = $self->get_lang($pid, $lid) || $lid;
                    $fh->printf("%s<string id='%s' platform='%s' encoding='%s' language='%s'>\n%s%s%s\n%s</string>\n",
                            $depth, $nid, $pid, $eid, $lang, $depth,
                            $context->{'indent'}, $self->{'strings'}[$nid][$pid][$eid]{$lid}, $depth);
                }
            }
        }
#        $fh->print("$depth</strings>\n");
    }
    $self;
}


=head2 $t->XML_end($context, $tag, %attrs)

Store strings in the right place

=cut

sub XML_end
{
    my ($self) = shift;
    my ($context, $tag, %attrs) = @_;

    if ($tag eq 'string')
    {
        my ($lid) = $self->find_name($attrs{'platform'}, $attrs{'language'}) || $attrs{'language'};
        $self->{'strings'}[$attrs{'id'}][$attrs{'platform'}][$attrs{'encoding'}]{$lid}
            = $context->{'text'};
        return $context;
    }
    else
    { return $self->SUPER::XML_end(@_); }
}

=head2 is_utf8($pid, $eid)

Returns whether a string of a given platform and encoding is going to be in UTF8

=cut

sub is_utf8
{
    my ($self, $pid, $eid) = @_;

    return ($utf8 && ($pid == 0 || $pid == 3 || ($pid == 2 && ($eid != 2 || defined @cp_1252))
            || ($pid == 1 && defined $apple_encodings[$eid])));
}


=head2 find_name($nid)

Hunts down a name in all the standard places and returns the string and for an
array context the pid, eid & lid as well

=cut

sub find_name
{
    my ($self, $nid) = @_;
    my ($res, $pid, $eid, $lid, $look, $k);

    my (@lookup) = ([3, 1, 1033], [3, 1, -1], [3, 0, 1033], [3, 0, -1], [2, 1, -1], [2, 2, -1], [2, 0, -1],
                    [0, 0, 0], [1, 0, 0]);
    foreach $look (@lookup)
    {
        ($pid, $eid, $lid) = @$look;
        if ($lid == -1)
        {
            foreach $k (keys %{$self->{'strings'}[$nid][$pid][$eid]})
            {
                if (($res = $self->{strings}[$nid][$pid][$eid]{$k}) ne '')
                {
                    $lid = $k;
                    last;
                }
            }
        } else
        { $res = $self->{strings}[$nid][$pid][$eid]{$lid} }
        if ($res ne '')
        { return wantarray ? ($res, $pid, $eid, $lid) : $res; }
    }
    return '';
}


=head2 set_name($nid, $str[, $lang[, @cover]])

Sets the given name id string to $str for all platforms and encodings that
this module can handle. If $lang is set, it is interpretted as a language
tag and if the particular language of a string is found to match, then
that string is changed, otherwise no change occurs.

If supplied, @cover should be a list of references to two-element arrays 
containing pid,eid pairs that should added to the name table if not already present.

This function does not add any names to the table unless @cover is supplied. 

=cut

sub set_name
{
    my ($self, $nid, $str, $lang, @cover) = @_;
    my ($pid, $eid, $lid, $c);

    foreach $pid (0 .. $#{$self->{'strings'}[$nid]})
    {
        my $strNL = $str;
        $strNL =~ s/\n/\r\n/og  if $pid == 3;
        $strNL =~ s/\n/\r/og    if $pid == 1;
        foreach $eid (0 .. $#{$self->{'strings'}[$nid][$pid]})
        {
            foreach $lid (keys %{$self->{'strings'}[$nid][$pid][$eid]})
            {
                next unless (!defined $lang || $self->match_lang($pid, $lid, $lang));
                $self->{'strings'}[$nid][$pid][$eid]{$lid} = $strNL;
                foreach $c (0 .. scalar @cover)
                {
                    next unless ($cover[$c][0] == $pid && $cover[$c][1] == $eid);
                    delete $cover[$c];
                    last;
                }
            }
        }
    }
    foreach $c (@cover)
    {
        my ($pid, $eid) = @{$c};
        my ($lid) = $self->find_lang($pid, $lang);
        my $strNL = $str;
        $strNL =~ s/\n/\r\n/og  if $pid == 3;
        $strNL =~ s/\n/\r/og    if $pid == 1;
        $self->{'strings'}[$nid][$pid][$eid]{$lid} = $strNL;
    }
    return $self;
}

=head2 Font::TTF::Name->match_lang($pid, $lid, $lang)

Compares the language associated to the string of given platform and language
with the given language tag. If the language matches the tag (i.e. is equal
or more defined than the given language tag) returns true. This is calculated
by finding whether the associated language tag starts with the given language
tag.

=cut

sub match_lang
{
    my ($self, $pid, $lid, $lang) = @_;
    my ($langid) = $self->get_lang($pid, $lid);

    return ($lid == $lang) if ($lang != 0 || $lang eq '0');
    return !index(lc($langid), lc($lang));
}

=head2 Font::TTF::Name->get_lang($pid, $lid)

Returns the language tag associated with a particular platform and language id

=cut

sub get_lang
{
    my ($self, $pid, $lid) = @_;

    if ($pid == 3)
    { return $win_langs{$lid}; }
    elsif ($pid == 1)
    { return $mac_langs[$lid]; }
    return '';
}


=head2 Font::TTF::Name->find_lang($pid, $lang)

Looks up the language name and returns a lang id if one exists

=cut

sub find_lang
{
    my ($self, $pid, $lang) = @_;

    if ($pid == 3)
    { return $langs_win{$lang}; }
    elsif ($pid == 1)
    { return $langs_mac{$lang}; }
    return undef;
}


BEGIN {
@apple_encs = (
<<'EOT',
M>)RES==NCW$`@.'G_S5Q*L(!#?+K1VO4:.W6IJA-:\^BM?>L>1&NP(A0Q$BL
M<*!62ZV8Z1)[K]BE$MR#O,=/7OW]7T&*6"NMI4K31EOMM)>N@XXZZ2Q#IBZZ
MZJ:['GKJ)4NVWOKHJ]\_/\!`@PR68XBAALDUW`@CC3+:&&.-,UZ>?!-,-,ED
M4TPUS70SS#3+;`7FF&N>0D7F6V"A119;8JEEEEMAI5566V.M==;;H-A&FVRV
MQ5;;_OTONJ3<%;?<5^NQ1YYXYJGG7GKME3?>>N^=#S[ZY(O/OOKNFU]^JO<[
M!$?LLMO>$#OAH4-*4F+'[(L+E*F,6SH:%\9%]C@>1W&CN&%2:9QNO]-))5ZH
M<]9.!^/DQ/8X-V[@@#,AS0ZE+KB7R$ODA\:A26@>6H2FH9D?J17^)(I#3C@8
MLD)V?:(^"BE.AN30,F0XK\(Y5UUVW0TW77/'W;H_;JM6HRJ1&95%M0Y'E5%5
.5.U4]""JB<K_`B>`?E$`
EOT

undef,
undef,
undef,
<<'EOT',
M>)RES[=/%```1O$WO8G_@$'J';W70Z2WHS>5WJN%8D6%D;BZ,3*P,;#C2D(8
M,9&)08V)+4*(1((X2'(#[.:;7[[\*./_%D,L<<230"(!@B213`JII)%.!IED
MD4T.N>213P&%%%%,B!)N4LJMR[Z<"BJIHIH::JFCG@;"--)$,RVTTD8['732
M13>WN<-=>NBECWX&&&2(848898QQ)IADBFEFF.4>]WG`0^:89X%%'O&8)SSE
M&<]9X@4O><4R*Y?_.ZRSRQ[[''#(1S[PB<]NL\D7OO&5[_S@9TR`(XXYX1=O
M.>4W9_SAG`O^7OF=O>XW*N)WV!%''7/<"2>=<MH90D9'_-X(AHTUSG@33#1@
MT"2333'5--/-,-,LL\TQUSSS+;#0(HL-7?DMM\)*JZRVQEKKK+?!L(TVV6R+
9K;;9;H<K+KGJ>S?<\K5O(G[7?/</+>Y>'```
EOT

<<'EOT',
M>)RED$LSEW$`A9_-^00L,H-^(=>4Y%^2J'1Q*Y+[I2(BHA`B?!%J6EM1*28S
M;9II[/PI*7*_%TUN\_*VZ%W:FN9LSYEGGD,\_Q?#$?SP)X"C!!)$,"&$$L8Q
MPCG."2(X222GB,+%:<X0S5EB.$<LYXES]A>XR"42N,P5KG*-1))()H54KG.#
M--*Y20:WR"2+;'+()8]\"BBDB-O<X2[%E'"/4LJX3SD5/*"2*AY230V/>$PM
M==3SA`8::>(IS;3PC%;::'?X'^W#?&(0-Z-,,,,TL\PSQP)+K+#,*C]9XQ?K
M_.8/FVRPQ0[;[+&+S=_]_J;KX/Y6I?&U.JQ.Z[GU0@-VBNTR@;Q4G]ZI5V_U
MQG@83^-M?,PAXV6'VF'ZH&Z]4H_>J]]IO=:0W!K6B#[KBT;U56/ZIN\:UX1^
?:%)3FM:,9C6G>2UH44M:UHI6'?<BYX,"6O\!%-%\5```
EOT

<<'EOT',
M>)RES5=OSG$`0.$CYR.(A(3DUS]J4WOO59O6;&F+UMY[7R&(V'N^4ETZ=*"J
M:M:H=>E*0D1B)7HC1KC0[R#G^LEA,/]7((Z(EK2B-?&TH2WM:$\'.M*)SG0A
M@:YTHSL]Z$DO>M.'OO2C/P,8R*`&/X2A#&,X(QC)*$:3R!C&,H[Q3&`BDYC,
M%))(9BK3F,X,9C*+%%*9S1S22">#N<QC/IEDL8"%+&(Q2UC*,I:S@I6L8C5K
M6,LZUK.!C6QB,UO8RC:VLZ/A7TL5Y=11P6O>N(MWO.>#.\GG(Y_YQ!>^DAT7
M\8WZ$%$3$OC.#W(IYC=_^!N"1SWF*<]ZP1AO*:'`;*^0%V502J6'*8LRHRQR
M/.)Q3WC2TY[QG+D6FF^!19ZGR(M>BA*]3"'5(9Z8.>:YVSV-DD/CT"0T#RU"
MT]",G^YUG_L]8+$E7O6%!WUIF>4^]9K7?6R%E59YQUM6>]L:[WK/5][WH;7>
4M,X'/O&1-WSF<P]9^BOV#YW%>_\`
EOT

<<'EOT',
M>)RERT=.%5``0-&+7K'&!B(@X/L/^/3>ZZ?SZ=*K@`KVWOL:U!68.#!&8G2@
M$Q?F5/=@SOB0XO\$$D2**:&4)&644T$E55130RUUU--`(TTTTT(K;;3302==
M=--#[[_?1S\###+$,".,DF:,<2:89(II9KC`+'/,L\`B2RRSPBIKK+/!13;9
M8IM+7.8*.^QRE6M<YP8WN<5M[G"7>]SG`0]YQ&.>\)1G/.<%+WG%:][PEI0G
M/>5IL\SVC#F>-=<\\SUG@846>=Y@PFBQ)9::M,QR*ZRTRFIKK+4N!+[[CD]\
M#I%?9O*-+XGH/N?BMON=CT7\B#MQUR5^^MY#ZH('7?:PJQYQS14/L!?S,S[$
M=,SD*[]#DH\>==UC;K@8LD)V*`B%(3?D\2<4>=Q-3[B5R#'#66>LM\%&FVRV
GQ5;;;+?#3KOLML=>4_;9[X"##CGLB*.F'7/<"2>=<CKL_06V`DD#
EOT

undef,
<<'EOT',
M>)RED-DVUG$`1;=:U*Y%0C)5O^^/SSS/F>>9#"$JE7D>"D6\3S=>Q^MPU^JF
M&^M<G[7//G1ROP1B1.130"%QBBBFA%+***>"2JJHIH9:ZJBG@4:::*:%M[32
M1CL==_TNNNFAES[Z&6"0(889890QQIE@DG=,,<T,L[QGCGD6^,`B2WSD$Y]9
MY@M?^<8*JZRQS@:;;+'-#KOLL<\!AQQQS'=^<,(I9_SD%^=<\)M+KN[X-U%:
M2`\9(2MDAWB(^,-U+/KKYYJ'_W_`!!_XT$23?.1C]8E/3?&9J2:;9KH9/O>%
MF;XTRVQSS#7/5[[VC<&8D?D66&C<(HLML=0RRZVPTBJ7K;;&6NNLM\%&FVRV
L):388:===MMCKP,..F2_(XXZYK#CMKGZS[YU-]QTRVUWW'7/?0]N`4(?0WT`
EOT

<<'EOT',
M>)RED,5.0U$415=(D.X!$"ANMX^VN+M#D>+N[H4"Q5W^APF_PZ\PY.9-"`-&
MY.3LG>-"#_\3@P^'8OP$"%)"*6644T$E55130RUUU--`(TTTTT(K;;3302==
M=-OZ7OH(T<\`@PP19I@11AECG`DFF6*:&6:98YX%%EEBF15666.=#3;98IL=
M=MECGP,.B7#$,5%...6,&.=<<,D5U]QPRQWW//#($\^\\,J;G?_II)ETXS79
M)L<$C<,['S[GYSY=?FWK6E>Z^?L'BK,:KP0E*DD>R?6E*-7E='DM9BA36<I6
MCG*5IWP5J%!%,O+)4;'\"BBH$I7:S')5J%)5JE:-M6JMUKM]FM1LL55M)EG=
GZE&O^A1R(V$-NSRF<8L3ZO3L_]KN4!$=Z5A1G>A49XKI_!M<9D8J
EOT

<<'EOT',
M>)RED,E3SW$8QU_77@<''+A]^Y5(2-F7+"%92\B^ES5ES]H,)L(8&21E*UNH
M&"8T8ZS3I(FS_T"$_`L^-^/D8)YY/^]Y/\L\"Y/Y/XN()T8"B0P@B8$,(IG!
MI#"$H0PCE>&DD<X(1C**T8QA+.,8SP0FDL&DT#^%J60RC>G,((N99#.+V<QA
M+O.83PZY+""/A2QB,?DL82G+6,X*5K**U:QA+>M8SP8**&0CF]C,%K:RC2*V
M4TP).]C)+G:SA[WLHY3]'.`@ASC,$<K"_,^QWE&?J&_4+^H?)44Q[M,<'_MS
M7USAOS[@48]YW')/>-(*3WG:,R%ZSDK/!K[@1<][R2HO6^T5:ZSUJM>\[@UO
M6F>]M[SM'>]ZSX90_\"'-MIDLX^">ASPQ*?!M_C,Y[ZP->KE*U_[QK>^\WW(
CM/O!ML"=?K3#3[Z,*_AKOR]V^=5O=OO='_ZTQU^_`2-%:*``
EOT

undef,
undef,
undef,
undef,
undef,
undef,
undef,
undef,
undef,
<<'EOT',
M>)REC]=.E&$`1(\%&W@4004%_7:!I?>.Z-+[TJL*=K"`BH`*J,_"+2'A!7PW
MX;\2[LG<3#*9G!F2G$V!&'$***2(!,644$H9Y5102175U%!+'?4TT$@3S;30
M2AN/:.<Q3Z)^!YUTT4T/O?31SP"###',""E&&6.<"2:98IH99IECG@6>\HSG
M+++$"U[RBM>\X2WO6&:%]WS@(Y]898W/?.$KZWQC@TVV^,X/?K+-#KO\XC=_
M(OX!?T/"`0<=<MB1$Q?R0KXIDB%NK?TVV&B3S:?RG)`;]?<\YWDO>-$T+WG9
M*U[UFNEF>%V]X4TSO666V=[VCG?-,==[WC?/?!_XT&#,N`466F3"8DLLM<QR
M*ZRTRFIK(GJ=]?_Y+;;:]N\HI(>LD&W2#COMLML>>^V+=IX\2<7BCCGNA)-.
0.>V,L\XY[P*'[!\#D^='L@``
EOT

undef,
undef,
undef,
undef,
undef,
undef,
undef,
undef,
undef,
);

$cp_1252 = (
<<'EOT',
M>)P-SD-B'5```,#YJ6VE>DEM&[\VD]JVF?H./4'-U+93V[9M:SV;$141(Y74
MTD@KG?0RR"B3S++(*IOL<L@IE]SRR"N?_`J(55`AA1515!`G7C'%E5!2*:65
M458YY550426555%5-=754%,MM=515SWU-=!05".--=%4,\VUT%(KK;715COM
M==!1)YTE2-1%5]UTUT-/O?361U_]]#?`0(,,-L10PPPWPDBCC#;&6..,-\%$
MDTPVQ5333)=DAIEFF6V.N>:%9-$0&YD?BH22(82XF)10.3(@U(DDB$;F_/]%
M0_Y0(!0*A4-\R!5RQ]R*BX\,#'4CB?]];B3)`@LMLM@22RVSW`HKK;):LC76
M6F>]#3;:9+,MMMIFNQUVVF6W/?;:9[\##CKDL"-2''7,<2><=,II9YQUSGD7
M7'3)95=<=<UU-]QTRVUWW'7/?0\\],AC3SSUS',OO/3*:V^\]<Y['WSTR6=?
1?/7-=S_\],MO?_S]!Y==>0@`
EOT
);
#'

@ms_langids = ( [""],
    ['ar', ["-SA", "-IQ", "-EG", "-LY", "-DZ", "-MA", "-TN", 
            "-OM", "-YE", "-SY", "-JO", "-LB", "-KW", "-AE",
            "-BH", "-QA"]],
    ['bg-BG'],
    ['ca-ES'],
    ['zh', ['-TW', 'CN', '-HK', '-SG', '-MO']],
    ["cs-CZ"],
    ["da-DK"],
    ["de", ["-DE", "-CH", "-AT", "-LU", "-LI"]],
    ["el-GR"],
    ["en", ["-US", "-UK", "-AU", "-CA", "-NZ", "-IE", "-ZA",
            "-JM", "029", "-BZ", "-TT", "-ZW", "-PH", "-ID",
            "-HK", "-IN", "-MY", "-SG"]],
    ["es", ["-ES", "-MX", "-ES", "-GT", "-CR", "-PA", "-DO",
            "-VE", "-CO", "-PE", "-AR", "-EC", "-CL", "-UY",
            "-PY", "-BO", "-SV", "-HN", "-NI", "-PR", "-US"]],
    ["fi-FI"],
    ["fr", ["-FR", "-BE", "-CA", "-CH", "-LU", "-MC", "",
            "-RE", "-CG", "-SN", "-CM", "-CI", "-ML", "-MA",
            "-HT"]],
    ["he-IL"],
    ["hu-HU"],
    ["is-IS"],
# 0010
    ["it", ["-IT", "-CH"]],
    ["ja-JP"],
    ["ko-KR"],
    ["nl", ["-NL", "-BE"]],
    ["no", ["-bok-NO", "-nyn-NO"]],
    ["pl-PL"],
    ["pt", ["-BR", "-PT"]],
    ["rm-CH"],
    ["ro", ["-RO", "_MD"]],
    ["ru-RU"],
    ["hr", ["-HR", "-Latn-CS", "Cyrl-CS", "-BA", "", "-Latn-BA", "-Cyrl-BA"]],
    ["sk-SK"],
    ["sq-AL"],
    ["sv", ["-SE", "-FI"]],
    ["th-TH"],
    ["tr-TR"],
# 0020
    ["ur", ["-PK", "tr-IN"]],
    ["id-ID"],
    ["uk-UA"],
    ["be-BY"],
    ["sl-SL"],
    ["et-EE"],
    ["lv-LV"],
    ["lt-LT"],
    ["tg-Cyrl-TJ"],
    ["fa-IR"],
    ["vi-VN"],
    ["hy-AM"],
    ["az", ["-Latn-AZ", "-Cyrl-AZ"]],
    ["eu-ES"],
    ["wen". ["wen-DE", "dsb-DE"]],
    ["mk-MK"],
# 0030
    ["st"],
    ["ts"],
    ["tn-ZA"],
    ["ven"],
    ["xh-ZA"],
    ["zu-ZA"],
    ["af-ZA"],
    ["ka-GE"],
    ["fo-FO"],
    ["hi-IN"],
    ["mt"],
    ["se", ["-NO", "-SE", "-FI", "smj-NO", "smj-SE", "sma-NO", "sma-SE",
            "", "smn-FI"]],
    ["ga-IE"],
    ["yi"],
    ["ms", ["-MY", "-BN"]],
    ["kk-KZ"],
# 0040
    ["ky-KG"],
    ["sw-KE"],
    ["tk-TM"],
    ["uz", ["-Latn-UZ", "-Cyrl-UZ"]],
    ["tt-RU"],
    ["bn", ["-IN", "-BD"]],
    ["pa", ["-IN", "-Arab-PK"]],
    ["gu-IN"],
    ["or-IN"],
    ["ta-IN"],
    ["te-IN"],
    ["kn-IN"],
    ["ml-IN"],
    ["as-IN"],
    ["mr-IN"],
    ["sa-IN"],
# 0050
    ["mn", ["-Cyrl-MN", "-Mong-CN"]],
    ["bo", ["-CN", "-BT"]],
    ["cy-GB"],
    ["km-KH"],
    ["lo-LA"],
    ["my"],
    ["gl-ES"],
    ["kok-IN"],
    ["mni"],
    ["sd", ["-IN", "-PK"]],
    ["syr-SY"],
    ["si-LK"],
    ["chr"],
    ["iu", ["-Cans-CA", "-Latn-CA"]],
    ["am-ET"],
    ["tmz", ["-Arab", "tmz-Latn-DZ"]],
# 0060
    ["ks"],
    ["ne", ["-NP", "-IN"]],
    ["fy-NL"],
    ["ps-AF"],
    ["fil-PH"],
    ["dv-MV"],
    ["bin-NG"],
    ["fuv-NG"], 
    ["ha-Latn-NG"],
    ["ibb-NG"],
    ["yo-NG"],
    ["quz", ["-BO", "-EC", "-PE"]],
    ["ns-ZA"],
    ["ba-RU"],
    ["lb-LU"],
    ["kl-GL"],
# 0070
    ["ig-NG"],
    ["kau"],
    ["om"],
    ["ti", ["-ET". "-ER"]],
    ["gn"],
    ["haw"],
    ["la"],
    ["so"],
    ["ii-CN"],
    ["pap"],
    ["arn-CL"],
    [""],           # (unassigned)
    ["moh-CA"],
    [""],           # (unassigned)
    ["br-FR"],
    [""],           # (unassigned)
# 0080
    ["ug-CN"],
    [""],           # (unassigned)
    ["oc-FR"],
    ["gsw-FR"],
    [""],           # (unassigned)
    ["sah-RU"],
    ["qut-GT"],
    ["rw-RW"],
    ["wo-SN"],
    [""],           # (unassigned)
    [""],           # (unassigned)
    [""],           # (unassigned)
    ["gbz-AF"],
);

@mac_langs = (
    'en', 'fr', 'de', 'it', 'nl', 'sv', 'es', 'da', 'pt', 'no',
    'he', 'ja', 'ar', 'fi', 'el', 'is', 'mt', 'tr', 'hr', 'zh-Hant',
    'ur', 'hi', 'th', 'ko', 'lt', 'pl', 'hu', 'et', 'lv', 'se',
    'fo', 'ru' ,'zh-Hans', 'nl', 'ga', 'sq', 'ro', 'cs', 'sk',
    'sl', 'yi', 'sr', 'mk', 'bg', 'uk', 'be', 'uz', 'kk', 'az-Cyrl',
    'az-Latn', 'hy', 'ka', 'mo', 'ky', 'abh', 'tuk', 'mn-Mong', 'mn-Cyrl', 'pst',
    'ku', 'ks', 'sd', 'bo', 'ne', 'sa', 'mr', 'bn', 'as', 'gu',
    'pa', 'or', 'ml', 'kn', 'ta', 'te', 'si', 'my', 'km', 'lo',
    'vi', 'id', 'tl', 'ms-Latn', 'ms-Arab', 'am', 'ti', 'tga', 'so', 'sw',
    'rw', 'rn', 'ny', 'mg', 'eo', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', 'cy', 'eu',
    'la', 'qu', 'gn', 'ay', 'tt', 'ug', 'dz', 'jv-Latn', 'su-Latn',
    'gl', 'af', 'br', 'iu', 'gd', 'gv', 'gd-IR-x-dotabove', 'to', 'el-polyton', 'kl',
    'az-Latn'
);

}

1;

=head1 BUGS

=over 4

=item *

Unicode type strings will be stored in utf8 for all known platforms,
once Perl 5.6 has been released and I can find all the mapping tables, etc.

=back

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

