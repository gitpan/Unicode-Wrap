# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More;
BEGIN { plan tests => 6 };
use Unicode::Wrap;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $w = new Unicode::Wrap (line_length => 5);

if ($w) {
	ok(1);
} else {
	fail(1);
}

#             01234.78901
is($w->wrap(qq{abcd efgh}), "abcd \nefgh\n", "simple wrap");
is($w->wrap(qq{abcdefghi}), "abcdefghi\n", "long line");
is($w->wrap(qq{ab cdefgh}), "ab \ncdefgh\n", "another simple wrap");
is($w->wrap(qq{ab "ab" x}), "ab \n\"ab\" \nx\n", "quotation mark disambiguation");
