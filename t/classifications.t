use utf8;
use open qw/ :utf8 :std /;

my(%tests, %skip, $number);

BEGIN { 

%tests = (
	"\x{000A}",	=> 'LF',	# 2
	"\x{000C}",	=> 'BK',	# 3
	"\x{000D}",	=> 'CR',	# 4
	"\e",		=> 'CM',	# This is debatable	# 2
	' '		=> 'SP',	# 6
	'!'		=> 'EX',	# 7
	'"'		=> 'QU',	# 8
	'%'		=> 'PO',	# 9
	"(",		=> 'OP',	# 11
	")",		=> 'CL',	# 12
	'+'		=> 'PR',	# 13
	",",		=> 'IS',	# 14
	'-'		=> 'HY',	# 15
	".",		=> 'IS',	# 16
	'/'		=> 'SY',	# 17
	5		=> 'NU',	# 18
	'?'		=> 'EX',	# 19
	a		=> 'AL',	# 20
	"\x{00B4}",	=> 'BB',	# 21
	"\x{200B}",	=> 'ZW',	# 25
	"\x{2010}",	=> 'BA',	# 26
	"\x{2014}",	=> 'B2',	# 27
	"\x{2029}",	=> 'BK',	# 29
	"\x{3000}",	=> 'ID',	# 30
	"\x{301C}",	=> 'NS',	# 31
	"\x{FE50}",	=> 'CL',	# 32
	"\x{FEFF}",	=> 'GL',	# 33
	"\x{FF01}",	=> 'EX',	# 34
	"\x{FFFC}",	=> 'CB',	# 35
	"\x{1160}",	=> 'CM',	# 22
	"\x{1780}",	=> 'SA',	# 23
	"\x{2000}",	=> 'BA',	# 24
	"\x{2024}",	=> 'IN',	# 28
);

$number = (keys %tests) + (keys %skip);
}

use Test::More tests => $number + 1;

BEGIN {
	use_ok('Unicode::Wrap', qw/ lb_class /);
}

foreach (sort keys %tests, keys %skip) {
	SKIP: {
	skip("classification needs work", 1) if exists $skip{$_};
	is(lb_class($_), $tests{$_}, "\\x{".sprintf("%04X", ord($_))."} should be classified '$tests{$_}'");
	}
}
