package Unicode::Wrap;

# Implements UAX#14: Line Breaking Properties
# David Nesting <david@fastolfe.net>

use 5.008;
use strict;
use warnings;
use base 'Exporter';

use Unicode::UCD;
use Carp;
use Clone 'clone';

our $VERSION = '0.03';

our @EXPORT_OK = qw/ break_lines lb_class text_properties class_properties 
	PROHIBITED INDIRECT DIRECT REQUIRED /;
our %EXPORT_TAGS = (
	'constants' => [qw/ PROHIBITED INDIRECT DIRECT REQUIRED /],
);

our $DEBUG = 0;
our $columns = 75;

my %classified;
my $procedural_self;
my $txt;

use constant PROHIBITED => 0;
use constant INDIRECT   => 1;
use constant DIRECT     => 2;
use constant REQUIRED   => 3;

my @CLASSES =  qw{ OP CL QU GL NS EX SY IS PR PO NU AL ID IN HY BA BB B2 ZW CM };
my %BREAK_TABLE = (
	OP => [qw[ 0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  1  ]],
	CL => [qw[ 2  0  1  1  0  0  0  0  2  1  2  2  2  2  1  1  2  2  0  1  ]],
	QU => [qw[ 0  0  1  1  1  0  0  0  1  1  1  1  1  1  1  1  1  1  0  1  ]],
	GL => [qw[ 1  0  1  1  1  0  0  0  1  1  1  1  1  1  1  1  1  1  0  1  ]],
	NS => [qw[ 2  0  1  1  1  0  0  0  2  2  2  2  2  2  1  1  2  2  0  1  ]],
	EX => [qw[ 2  0  1  1  1  0  0  0  2  2  2  2  2  2  1  1  2  2  0  1  ]],
	SY => [qw[ 2  0  1  1  1  0  0  0  2  2  1  2  2  2  1  1  2  2  0  1  ]],
	IS => [qw[ 2  0  1  1  1  0  0  0  2  2  1  2  2  2  1  1  2  2  0  1  ]],
	PR => [qw[ 1  0  1  1  1  0  0  0  2  2  1  1  1  2  1  1  2  2  0  1  ]],
	PO => [qw[ 2  0  1  1  1  0  0  0  2  2  2  2  2  2  1  1  2  2  0  1  ]],
	NU => [qw[ 2  0  1  1  1  0  0  0  2  1  1  1  2  1  1  1  2  2  0  1  ]],
	AL => [qw[ 2  0  1  1  1  0  0  0  2  2  1  1  2  1  1  1  2  2  0  1  ]],
	ID => [qw[ 2  0  1  1  1  0  0  0  2  1  2  2  2  1  1  1  2  2  0  1  ]],
	IN => [qw[ 2  0  1  1  1  0  0  0  2  2  2  2  2  1  1  1  2  2  0  1  ]],
	HY => [qw[ 2  0  1  1  1  0  0  0  2  2  0  2  2  2  1  1  2  2  0  1  ]],
	BA => [qw[ 2  0  1  1  1  0  0  0  2  2  2  2  2  2  1  1  2  2  0  1  ]],
	BB => [qw[ 1  0  1  1  1  0  0  0  1  1  1  1  1  1  1  1  1  1  0  1  ]],
	B2 => [qw[ 2  0  1  1  1  0  0  0  2  2  2  2  2  2  1  1  2  0  0  1  ]],
	ZW => [qw[ 2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  0  1  ]],
	CM => [qw[ 2  0  1  1  1  0  0  0  2  2  1  1  2  1  1  1  2  2  0  1  ]],
);

# Convert the table above into a hash that we can use for speedier lookups

foreach (keys %BREAK_TABLE) {
	my @t = @CLASSES;
	$BREAK_TABLE{$_} = { map { shift(@t) => $_ } @{$BREAK_TABLE{$_}} };
}

sub new {
	my $pkg = shift;
	my $self = { @_ };
	$self->{line_length} ||= $columns;
	$self->{break_table} ||= clone(\%BREAK_TABLE);
	
	bless($self, ref($pkg) || $pkg);
}

sub self {
#	unless ($procedural_self) {
#		$procedural_self = __PACKAGE__->new(
#			line_length => $columns,
#			emergency_break => $columns,
#		);
#	}
#	$procedural_self;
	__PACKAGE__->new(
		line_length => $columns,
		emergency_break => $columns,
	);
}

# This attempts to identify the on-screen length of a given character.
# For normal displays, you can generally assume the character has a
# length of 1, but some terminals may expand the width of certain
# characters, so that extra space needs to be taken into consideration
# here so the wrapping occurs at the proper place.

sub char_length {
	shift if ref($_[0]);
	my ($c) = @_;

	if ($c eq 'CM' || $c eq 'ZW') {
		return 0;
	}

	return 1;
}

sub lb_class {
	my $self = ref($_[0]) ? shift() : self();
	my $code = Unicode::UCD::_getcode(ord $_[0]);
	my $hex;

	if (defined $code) {
		$hex = sprintf "%04X", $code;
	} else {
		carp("unexpected arg \"$_[1]\" to Text::Wrap::lb_class()");
		return;
	}

	return $classified{$hex} if $classified{$hex};

	$txt = do "unicore/Lbrk.pl" unless $txt;

	if ($txt =~ m/^$hex\t\t(.+)/m) {
		print STDERR "< found direct match for $hex = $1 >\n" if $DEBUG > 1;
		return $classified{$hex} = $1;
	} else {
		print STDERR "< no direct match $hex >\n" if $DEBUG > 1;
		pos($txt) = 0;

		while ($txt =~ m/^([0-9A-F]+)\t([0-9A-F]+)\t(.+)/mg) {
			print STDERR "< examining $1 -> $2 >\n" if $DEBUG > 1;
			if (hex($1) <= $code && hex($2) >= $code) {
				print STDERR "< found range match for $hex = $3 between $1 and $2 >\n" if $DEBUG > 1;
				return $classified{$hex} = $3;
			}
		}
		return 'XX';
	}
}

# Returns a list of breaking properties for the given text
sub text_properties {
	my $self = ref($_[0]) ? shift() : self();
	my ($text) = @_;

	my @characters = split(//, $text);
	my @classifications = map { $self->lb_class($_) } @characters;

	class_properties(@classifications);
}

# Returns a list of breaking properties for the provided breaking classes
sub class_properties {
	my $self = ref($_[0]) ? shift() : self();
	no warnings 'uninitialized';

	my @breaks;
	my $last_class = $_[0];

	$last_class = 'ID' if $last_class eq 'CM';	# broken combining mark

	print STDERR "find_breaks: first class=$last_class\n" if $DEBUG;

	for (my $i = 1; $i <= $#_; $i++) {
		print STDERR "find_breaks: i=$i class=$_[$i] prev=$last_class breaks[i-1]=$breaks[$i-1]\n" if $DEBUG;
		$breaks[$i-1] ||= 0;

		$_[$i] = 'ID' if $_[$i] eq 'XX';	# we want as few of these as possible!

		if ($_[$i] eq 'SA') {
			# TODO: Need a classifiation system for complex characters
		}

		elsif ($_[$i] eq 'CR') {
			$breaks[$i] = REQUIRED;
		}

		elsif ($_[$i] eq 'LF') {
			if ($_[$i-1] eq 'CR') {
				$breaks[$i-1] = PROHIBITED;
			}
			$breaks[$i] = REQUIRED;
		}

		elsif ($_[$i] eq 'BK') {
			$breaks[$i] = REQUIRED;
		}

		elsif ($_[$i] eq 'SP') {
			$breaks[$i-1] = PROHIBITED;
			next;
		}

		elsif ($_[$i] eq 'CM') {
			if ($_[$i-1] eq 'SP') {
				$last_class = 'ID';
				if ($i > 1) {
					$breaks[$i-2] = $self->{break_table}->{$_[$i-2]}->{ID} == 
						DIRECT ? DIRECT : PROHIBITED;
				}
			}
		}

		elsif ($last_class ne 'SP') {
			if ($breaks[$i-1] != REQUIRED) {
				my $this_break = $self->{break_table}->{$last_class}->{$_[$i]};

				if ($this_break == INDIRECT) {
					$breaks[$i-1] = $_[$i-1] eq 'SP' ? INDIRECT : PROHIBITED;
				} else {
					die "internal error: no table mapping between '$last_class' and '$_[$i]'\n"
						unless defined $this_break;
					$breaks[$i-1] = $this_break;
				}
			}
		}

		$last_class = $_[$i];
	}

	# $breaks[$#breaks] = DIRECT;
	push(@breaks, REQUIRED);

	print STDERR "find_breaks: returning " . join(":", @breaks) . "\n" if $DEBUG;
	return @breaks;
}

# Returns a list of break points in the provided text, based on
# the line length
sub find_breaks {
	my $self = ref($_[0]) ? shift() : self();
	my $text = shift;

	no warnings 'uninitialized';	# since we do a lot of subscript +/- 1 checks

	my @characters = split //, $text;

	my @classifications = map { $self->lb_class($_) } @characters;
	my @lengths = map { $self->char_length($_) } @characters;

	my @breaks  = $self->class_properties(@classifications);
	my @breakpoints;

	my $last_start = 0;
	my $last_break;
	my $last_length;
	my $pos = 0;

	for (my $i = 0; $i <= $#lengths; $i++) {

		print STDERR "[i=$i '$characters[$i]' $classifications[$i] $breaks[$i]] " if $DEBUG;
		if ($breaks[$i] == REQUIRED) {
			print STDERR "required breakpoint\n" if $DEBUG;
			push(@breakpoints, $i+1);
			$last_start = $i+1;
			$pos = 0;
			next;
		}

		my $c = $pos + $lengths[$i];

		if ($c > $self->{line_length}) {
			print STDERR "want to break " if $DEBUG;
			if (defined $last_break) {
				print STDERR "at $last_break\n" if $DEBUG;
				push(@breakpoints, $last_break + 1);
				$last_start = $last_break + 1;
				undef $last_break;
				$pos -= $last_length - 1;
				print STDERR "[pos now $pos]\n" if $DEBUG;
				next;
			} elsif (defined $self->{emergency_break} && $c > $self->{emergency_break}) {
				print STDERR "NOW\n" if $DEBUG;
				push(@breakpoints, $i+1);
				$pos = 0;
			} else {
				print STDERR "but can't" if $DEBUG;
			}
		}
		print STDERR "\n" if $DEBUG;

		$last_break = $i if $breaks[$i];
		$last_length = $pos if $breaks[$i];

		$pos += $lengths[$i];
	}

	push(@breakpoints, $#lengths) if $breakpoints[$#breakpoints] < $#lengths;

	print STDERR "find_breaks: returning breakpoints " . join(":", @breakpoints) . "\n" if $DEBUG;

	return @breakpoints;
}

# Returns a list of lines, broken up with find_breaks
sub break_lines {
	my $self = ref($_[0]) ? shift() : self();
	my $text = shift;

	my @breaks = $self->find_breaks($text);
	my @lines;

	my $last = 0;
	foreach (@breaks) {
		push(@lines, substr($text, $last, $_-$last));
		$last = $_;
	}

	return @lines;
}

1;
		
__END__

=head1 NAME

Unicode::Wrap - Unicode Line Breaking

=head1 SYNOPSIS

  use Unicode::Wrap;

  $wrapper = new Unicode::Wrap( line_length => 75 );
  @lines = $wrapper->break_lines($long_string);

  use Unicode::Wrap qw/ text_properties lb_class class_properties /;

  @break_classes = map { lb_class $_ } split //, $long_string;
  @break_properties = class_properties(@break_classes);
  @break_properties = text_properties($long_string);
  @best_breaks = find_breaks($long_string);

=head1 ABSTRACT

This module implements UAX#14: Line Breaking Properties.  It goes
through a text string, classifies each character and computes a
length for each.  When the line gets too long, it's separated.

=head1 DESCRIPTION

All of the functions described here can be called procedurally or
as an object method.

=over 4

=item new(parameters)

This constructs a new wrapping object.  Parameters:

=over 4

=item line_length

Specifies the length of a line (in whatever units you want to use)

=item emergency_break

If set, and there are no breaking opportunities before the line_length
is reached, an 'emergency' break will be inserted at this position.  
Generally this should be set to line_length (or 1, since it won't be
used until line_length is reached anyway).

If emergency_break is not set, no emergency breaks will be inserted,
which could result in some really long lines if no line-breaking
opportunity exists.

=back

=item break_lines($text)

This will break C<$text> up into individual lines.  Newlines are preserved
but none will be added.  Use this if you need an implementation of UAX#14
that just breaks lines up without re-assembling them into a text string.

=back

=head2 LOW-LEVEL FUNCTIONS

If you need finer control over your own line-breaking, there's a few other
functions that can be used to obtain character classifications and breaking
properties for a set of characters.

Feel free to override some of these functions in descendent classes to
fine-tune the behavior of this module.  Some classifications and breaking
properties require language-specific input and presently that's the only
way to provide it.

=over 4

=item lb_class($character)

Returns the Line Breaking classification of the character passed.

  print lb_class("a");		# AL
  print $self->lb_class("5");	# NU

=item class_properties(@character_classes)

Accepts a list of character classes (e.g. 'AL' or 'NU') and returns
an identically-sized array of breaking properties (for the location
immediately following the character at that index; no break is permitted
at the start of a line).  The value of each property is a number from
0 to 3 (with constants defined in the Unicode::Wrap namespace):

  0  FORBIDDEN  No break is permitted after this position
  1   INDIRECT  A break is permitted after this position
  2     DIRECT  A break is permitted after this position
  3   REQUIRED  A break is required after this position

The values INDIRECT and DIRECT are the same for all intents and purposes,
but actually have a subtle difference in that an indirect break is
allowed simply because there's a space in that position.  A direct break
opportunity allows a break under any circumstances.  But you don't need
to worry about the difference by this point.

Required breaks occur primarily after newlines.

=item text_properties($text)

This behaves like class_properties, but instead of working with a list
of pre-determined classes, it classifies your C<$text>.  It will return
a list (one element for each character) representing where breaks can
and cannot occur.

This might be the most useful function for someone wanting to build a
more intelligent line-wrapping algorithm on top of this.  You could scan
through the returned list of break opportunities and figure out how you
want to do your own wrapping.

=item find_breaks($text)

This is similar to text_properties, but actually attempts to apply
line lengths to find the best breaks for each line.  It will return
a list of indexes to the start of each new line (minus the first).
Use C<break_lines> to go the rest of the way and actually break the
string up into lines.

=back

=head1 BUGS

=over 4

=item This module can be slow.  It's a pure-Perl implementation that
goes through an expensive classification process per character.

=item Some language-specific processing is needed in some areas to better
classify characters or to identify where breaking opportunities exist.
A notable example arises around quotation marks.  UAX#14 forbids breaks
before and after quotation marks, since they require cues from the
language to determine if it's OK to break there.  There is no extensible
facility to add these cues aside from subclassing.

=back

=head1 SEE ALSO

=over 4

=item http://www.unicode.org/reports/tr14/

Unicode Standard Annex #14: Line Breaking Properties

=item L<Text::Wrap>, L<perlunicode>

=back

=head1 AUTHOR

David NESTING E<lt>david@fastolfe.netE<gt>

Copyright (c) 2003 David Nesting.  All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
