use strict;

use Test::Simple tests => 3;
use Font::TTF::OTTags qw( %tttags %ttnames readtagsfile);

ok($tttags{'SCRIPT'}{'Cypriot Syllabary'} eq 'cprt', 'tttags{SCRIPT}');

ok($ttnames{'LANGUAGE'}{'AFK '} eq 'Afrikaans', 'ttnames{LANGUAGE}');

ok($ttnames{'LANGUAGE'}{'DHV '} eq 'Dhivehi (OBSOLETE)' && $ttnames{'LANGUAGE'}{'DIV '} eq 'Dhivehi', 'ttnames{LANGUAGE} Dhivehi');

