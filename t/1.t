# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More;
BEGIN { plan tests => 10 };
use Unicode::Wrap;
ok(1); # If we made it this far, we're ok.

#########################

my $w = new Unicode::Wrap (line_length => 5);

if ($w) {
	ok(1);
} else {
	fail(1);
}

is($w->classify("A"), "AL", "AL classifications");
is($w->classify(" "), "SP", "SP classifications");
is($w->classify('"'), "QU", "QU classifications");

#             01234.78901
is($w->wrap("","",qq{abcd efgh}), "abcd\nefgh\n", "simple wrap");
is($w->wrap("","",qq{abcdefghi}), "abcdefghi\n", "long line");
is($w->wrap("","",qq{ab cdefgh}), "ab\ncdefgh\n", "another simple wrap");
is($w->wrap("","",qq{ab "ab" x}), "ab\n\"ab\"\nx\n", "quotation mark disambiguation");

use Unicode::Wrap 'wrap';
$Unicode::Wrap::columns = 5;

is(wrap("  ", " ", qq{abc defghi}), "  abc\n defg\n hi\n", "procedural wrap()");
