use utf8;
use open qw/ :utf8 :std /;

use Test::More tests => 50;

BEGIN {
	use_ok('Unicode::Wrap', 'text_properties');
}

is((text_properties("abc"))[2], 3,				"LB 2: break at end of string");

is(join(":", text_properties("a\x{0A}b")), "0:3:3",		"LB 3a: always break after LF");
is(join(":", text_properties("a\x{0D}b")), "0:3:3",		"LB 3a: always break after CR");
is(join(":", text_properties("a\x{2028}b")), "0:3:3",		"LB 3a: always break after BK");

is(join(":", text_properties("a\x{0D}\x{0A}b")), "0:0:3:3",	"LB 3a: do not break between CR and LF");
is(join(":", text_properties("a \x{0D}b")), "0:0:3:3",		"LB 3b: do not break before hard line breaks");

is(join(":", text_properties("a ")), "0:3",			"LB 4: do not break before spaces");
is(join(":", text_properties("a\x{200B}")), "0:3",		"LB 4: do not break before zero-width space");

is(join(":", text_properties("a\x{200B}b")), "0:2:3",		"LB 5: break after zero-width space");
is(join(":", text_properties("a\x{200B} b")), "0:0:2:3",	"LB 5: break after zero-width space");

is(join(":", text_properties("a\x{1160}b")), "0:0:3",		"LB 6: do not break graphemes");
is(join(":", text_properties("a\x{1160}\x{1160}b")), "0:0:0:3",	"LB 6: do not break graphemes");
is(join(":", text_properties("a \x{1160}b")), "2:0:0:3",	"LB 6: do not break graphemes");
is(join(":", text_properties("a \x{1160} b")), "2:0:0:1:3",	"LB 6: do not break graphemes");

is(join(":", text_properties("a ]")), "0:0:3",			"LB 8: do not break before CL");
is(join(":", text_properties("a !")), "0:0:3",			"LB 8: do not break before EX");
is(join(":", text_properties("a ;")), "0:0:3",			"LB 8: do not break before IS");
is(join(":", text_properties("a /")), "0:0:3",			"LB 8: do not break before SY");

is(join(":", text_properties("[a")), "0:3",			"LB 9: do not break after [");
is(join(":", text_properties("[ a")), "0:0:3",			"LB 9: do not break after [, even after spaces");

is(join(":", text_properties('"[')),   "0:3",			"LB 10: do not break within \"[");
is(join(":", text_properties('" [')),  "0:0:3",			"LB 10: do not break within \"[, even with spaces");
is(join(":", text_properties('"  [')), "0:0:0:3",		"LB 10: do not break within \"[, even with spaces");

is(join(":", text_properties("]\x{301C}")),   "0:3",		"LB 11: do not break within ]h");
is(join(":", text_properties("] \x{301C}")),  "0:0:3",		"LB 11: do not break within ]h, even with spaces");
is(join(":", text_properties("]  \x{301C}")), "0:0:0:3",	"LB 11: do not break within ]h, even with spaces");

is(join(":", text_properties("\x{2014}\x{2014}")),   "0:3",	"LB 11a: do not break between EM DASH");

is(join(":", text_properties("a\x{00A0}a")), "0:0:3",		"LB 13: do not break before or after NBSP");

is(join(":", text_properties('a"a')), "0:0:3",			"LB 14: do not break before or after quotes");
is(join(":", text_properties('aa"aa')), "0:0:0:0:3",		"LB 14: do not break before or after quotes");

is(join(":", text_properties('a-')), "0:3",			"LB 15: do not break before hyphens");
is(join(":", text_properties(' -')), "0:3",			"LB 15: do not break before hyphens");
is(join(":", text_properties("\x{00B4}a")), "0:3",		"LB 15: do not break after accents");
is(join(":", text_properties('a-b')), "0:2:3",			"LB 15b: break after hyphens");
is(join(":", text_properties(' -b')), "0:2:3",			"LB 15b: break after hyphens");
is(join(":", text_properties("a\x{00B4}a")), "2:0:3",		"LB 15b: break before accents");

is(join(":", text_properties("a\x{2026}")), "0:3",		"LB 16: do not break between letters and ellipsis");
is(join(":", text_properties("5\x{2026}")), "0:3",		"LB 16: do not break between numbers and ellipsis");
is(join(":", text_properties("\x{2026}\x{2026}")), "0:3",	"LB 16: do not break between ellipsis");

is(join(":", text_properties("a5")), "0:3",			"LB 17: do not break between letters and numbers");
is(join(":", text_properties("5a")), "0:3",			"LB 17: do not break between letters and numbers");

is(join(":", text_properties("]%")), "0:3",			"LB 18: do not break");
is(join(":", text_properties('$9')), "0:3",			"LB 18: do not break");
is(join(":", text_properties(")\x{2103}")), "0:3",		"LB 18: do not break");
is(join(":", text_properties("-52")), "0:0:3",			"LB 18: do not break");
is(join(":", text_properties("\x{00B1}a")), "0:3",		"LB 18: do not break");
is(join(":", text_properties("\x{00B1}5")), "0:3",		"LB 18: do not break");
is(join(":", text_properties("\x{00B1}(")), "0:3",		"LB 18: do not break");

is(join(":", text_properties("abc")), "0:0:3",			"LB 19: do not break between alphabetics");
