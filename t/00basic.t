use utf8;
use open qw/ :utf8 :std /;

use Test::More tests => 5;

BEGIN {
	use_ok('Unicode::Wrap', 'break_lines');
}

my $w = new Unicode::Wrap (line_length => 4);

ok($w, "new object");

is(join(":", $w->break_lines("abc abc abc")), "abc :abc :abc",		"simple line breaking");
is(join(":", $w->break_lines("abcde abc abc")), "abcde :abc :abc",	"can't emergency break");
is(join(":", $w->break_lines("ab abcde abc abc")), "ab :abcde :abc :abc","more complex");
