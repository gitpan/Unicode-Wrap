package Unicode::Wrap;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.01';

# Implements UAX#14: Line Breaking Properties
# David Nesting <david@fastolfe.net>

our $DEBUG = 0;

sub new {
	my $pkg = shift;
	my $self = { @_ };
	bless($self, ref($pkg) || $pkg);
}

sub wrap {
	my $self = shift;

	if (wantarray) {
		map { $self->_wrap($self->prepare($_, "\n")) } @_;
	} else {
		$self->_wrap($self->prepare(shift(), "\n"));
	}
}

sub rewrap {
	my $self = shift;

	if (wantarray) {
		map { $self->_wrap($self->prepare($_, " ")) } @_;
	} else {
		$self->_wrap($self->prepare(shift(), " "));
	}
}

# Normalize newlines
sub prepare {
	my ($self, $text, $to_what) = @_;

	$to_what = "\n" unless defined $to_what;

	$text =~ s/\012\010|\012|\010|\N{U+2028}/$to_what/g;

	return $text;
}

use constant      AFTER => 1;
use constant  NOT_AFTER => 2;
use constant     BEFORE => 4;
use constant NOT_BEFORE => 8;
use constant     PAIRED => 16;
use constant NOT_PAIRED => 32;

use constant REQUIRED   => 64;

my %BREAK_RULE = (
	AL => NOT_PAIRED,
	BA => AFTER,
	BB => BEFORE,
	B2 => BEFORE | AFTER | NOT_PAIRED,
	BK => AFTER | REQUIRED,
	CB => BEFORE | AFTER,
	CL => NOT_BEFORE,
	CM => NOT_BEFORE,
	CR => AFTER | REQUIRED,
	EX => NOT_BEFORE,
	GL => NOT_BEFORE | NOT_AFTER,
	HY => NOT_AFTER,
	ID => BEFORE | AFTER,
	IN => NOT_PAIRED,
	IS => NOT_BEFORE,
	LF => AFTER | REQUIRED,
	NS => NOT_BEFORE,
	NU => NOT_PAIRED,
	OP => NOT_AFTER,
	PO => NOT_BEFORE,
	PR => NOT_AFTER,
	QU => NOT_BEFORE | NOT_AFTER,
	SA => PAIRED,
	SG => NOT_PAIRED,
	SP => AFTER,
	SY => AFTER,
	XX => NOT_PAIRED,
	ZW => AFTER,
);

# This attempts to identify the on-screen length of a given character.
# For normal displays, you can generally assume the character has a
# length of 1, but some terminals may expand the width of certain
# characters, so that extra space needs to be taken into consideration
# here so the wrapping occurs at the proper place.
#
# You can define your own 'length' function by storing your own coderef
# in $self->{length_lookup}.  Otherwise $self->{length_lookup} can contain
# a hashref cache of lengths.

sub length_of {
	my $self = shift;
	my $c = shift;

	if (ref($self->{length_lookup}) eq 'CODE') {
		return $self->{length_lookup}->($c, @_);
	} elsif ($self->{length_lookup}) {
		return $self->{length_lookup}->{$c} if defined $self->{length_lookup}->{$c};
	}

	if ($_[0] eq 'CM' || $_[0] eq 'ZW') {
		return 0;
	}

	return 1;
}

sub _wrap {
	my ($self, $text) = @_;

	no warnings 'uninitialized';	# since we do a lot of subscript +/- 1 checks

	my @break_at;

	my @characters = split(//, $text);
	my @classifications = map { classify_character($_) } @characters;

	# Fix up the classifications so that a HY (hyphen) class becomes a BA
	# class if it occurs between two alphabetic characters, since this usually
	# implies a hyphenation point in this situation.

	for (my $i = 0; $i <= $#classifications; $i++) {
		if ($classifications[$i] eq 'HY') {
			if ($classifications[$i-1] eq 'AL' && $classifications[$i+1] eq 'AL') {
				$classifications[$i] = 'BA';
			}
		}
	}

	my @rules = map { $BREAK_RULE{$_} } @classifications;
	my $last_break;
	my $pos = 0;

	for (my $i = 0; $i <= $#rules; $i++) {
		print STDERR "[char '$characters[$i]'=$classifications[$i]=$i" if $DEBUG;
		if ($pos) {	# Can't be first on the line
			if ($classifications[$i] eq $classifications[$i-1] && ($rules[$i] & (PAIRED | NOT_PAIRED))) {
				# We're a pair, and we have a pairing rule
				if ($rules[$i] & PAIRED) {
					$last_break = $i;
					print STDERR ", can break with paired" if $DEBUG;
				}
			} else {	# we're not paired, or we're paired but we have no rule yet
				if ($rules[$i] & BEFORE && !($rules[$i-1] & NOT_AFTER)) {
					$last_break = $i;
					print STDERR ", can break with previous" if $DEBUG;
				}

				# Quotation marks are ambiguous.  By default we forbid breaks before and
				# after.  Here we override that if there's a space before the quote and
				# allow a break to occur between the space and the quote.

				# This would allow:  He said, "She said."  to break only before the first
				# quote and only after the second quote.

				if ($classifications[$i] eq 'QU' && $classifications[$i-1] eq 'SP') {
					print STDERR ", dis-ambiguated quote can break with previous" if $DEBUG;
					$last_break = $i;
				}
			}
		}

		$last_break = $i if $rules[$i] & REQUIRED;

		my $length = $self->length_of($characters[$i], $classifications[$i]);

		if ($pos + $length >= $self->{line_length} || $rules[$i] & REQUIRED) {
			if ($classifications[$i] ne 'SP') {
				print STDERR ", want to break at $i" if $DEBUG;
				if ($last_break) {
					print STDERR ", choosing $last_break" if $DEBUG;
					push(@break_at, $last_break);
					$pos = $i - $last_break;
					undef $last_break;
				} elsif ($self->{emergency_break} && $pos + $length >= $self->{emergency_break}) {
					print STDERR ", emergency break" if $DEBUG;
					push(@break_at, $i);	# "emergency" break
					$pos = 0;
				}
			}
		}
		$pos += $length;

		if ($classifications[$i] ne $classifications[$i+1] || !($rules[$i] & (PAIRED | NOT_PAIRED))) {
			if ($rules[$i] & AFTER && !($rules[$i+1] & NOT_BEFORE)) {
				print STDERR ", can break before next" if $DEBUG;
				$last_break = $i + 1;
			} elsif ($classifications[$i] eq 'QU' && $classifications[$i+1] eq 'SP') {
				print STDERR ", dis-ambiguated quote can break before next" if $DEBUG;
				$last_break = $i + 1;
			}
		}
		print STDERR "\n" if $DEBUG;
	}

	push(@break_at, length($text)) unless $break_at[$#break_at] == length($text);

	$pos = 0;
	foreach (@break_at) {
		substr($text, $_ + $pos, 0) = "\n";
		$pos++;
	}

	return $text;
}

# Here is where a character gets classified into a UNICODE character
# class.  This method is fairly inefficient.
	
sub classify_character {
	local($_) = $_[0];
	my $ord = ord($_);

	# AI - Ambiguous (Alphabetic or Ideograph)
	# TODO

	# BA - Break Opportunity After
	return 'BA' if
		# Breaking spaces
		$ord >= 0x2000 && $ord <= 0x200a && $ord != 0x2007 ||
		# Tabs
		$ord == 0x0009 ||
		# Breaking Hyphens
		$ord == 0x058a || $ord == 0x2010 || $ord == 0x2012 || 
		$ord == 0x2013 || $ord == 0x00ad || $ord == 0x0f0b ||
		$ord == 0x1361 || $ord == 0x1680 || $ord == 0x17d5 ||
		$ord == 0x2027 || $ord == 0x007c;

	# BB - Break opportunities before characters
	return 'BB' if
		$ord == 0x00b4 || $ord == 0x02c8 || $ord == 0x02cc ||
		$ord == 0x1806;

	# B2 - Break Opportunity Before and After
	return 'B2' if
		$ord == 0x2014;

	# BK - Mandatory Break
	return 'BK' if
		$ord == 0x000c || $ord == 0x2028 || $ord == 0x2029;

	# CB - Contingent Break Opportunity
	return 'CB' if
		$ord == 0xfffc;
	
	# CL - Closing Punctuation
	return 'CL' if
		$ord == 0x3001 || $ord == 0x3002 || $ord == 0xfe50 ||
		$ord == 0xfe52 || $ord == 0xff0c || $ord == 0xff0e ||
		$ord == 0xff61 || $ord == 0xff64 ||
		/^\p{Pe}$/;

	# CR - Carriage Return
	return 'CR' if
		$ord == 0x000d;

	# EX - Exclamation / Interrogation
	return 'EX' if
		$ord == 0x0021 || $ord == 0x003f || $ord == 0x2762 ||
		$ord == 0x2763 || $ord == 0xfe56 || $ord == 0xfe57 ||
		$ord == 0xff01 || $ord == 0xff1f;

	# GL - Non-breaking ("Glue")
	return 'GL' if
		$ord == 0x2060 || $ord == 0xfeff || $ord == 0x00a0 ||
		$ord == 0x202f || $ord == 0x034f || $ord == 0x2007 ||
		$ord == 0x2011 || $ord == 0x0f0c;

	# HY - Hyphen
	return 'HY' if 
		$ord == 0x002d;

	# ID - Ideographic
	return 'ID' if
		$ord >= 0x1100 && $ord <= 0x115f ||
		$ord >= 0x2e80 && $ord <= 0x2fff ||
		$ord == 0x3000 ||
		$ord >= 0x3130 && $ord <= 0x318f ||
		$ord >= 0x3400 && $ord <= 0x4dbf ||
		$ord >= 0x4e00 && $ord <= 0x9faf ||
		$ord >= 0xf900 && $ord <= 0xfaff ||
		$ord >= 0xac00 && $ord <= 0xd7af ||
		$ord >= 0xa000 && $ord <= 0xa48f ||
		$ord >= 0xa490 && $ord <= 0xa4cf ||
		$ord >= 0xfe62 && $ord <= 0xfe66 ||
		$ord >= 0xff10 && $ord <= 0xff19 ||
		$ord >= 0x20000 && $ord <= 0x2a6d6 ||
		$ord >= 0x2f800 && $ord <= 0x2fa1d;

	# IN - Inseparable characters
	return 'IN' if
		$ord >= 0x2024 && $ord <= 0x2026;

	# IS - Numeric Separator (Infix)
	return 'IS' if
		$ord == 0x002c || $ord == 0x002e || $ord == 0x003a ||
		$ord == 0x003b || $ord == 0x0589;

	# LF - Line Feed
	return 'LF' if $ord == 0x000a;

	# NS - Non-starters
	return 'NS' if 
		$ord == 0x0e5a || $ord == 0x0e5b || $ord == 0x17d4 ||
		$ord >= 0x17d6 && $ord <= 0x17da || $ord == 0x203c || 
		$ord == 0x2044 || $ord == 0x3005 || $ord == 0x301c || 
		$ord >= 0x309b && $ord <= 0x309e || $ord == 0x30fb || 
		$ord == 0x30fd || $ord == 0xfe54 || $ord == 0xfe55 || 
		$ord == 0xff1a || $ord == 0xff1b || $ord == 0xff65 || 
		$ord == 0xff70 || $ord == 0xff9e || $ord == 0xff9f ||
		/^[\p{Lm}\p{Sk}]$/;
		# TODO: East Asian Width type W or H
		# TODO: Hiragana, Katakana and Halfwidth Katakana "small" characters

	# NU - Numeric
	return 'NU' if
		/^\p{Nd}$/;
		# TODO: No 'FULL WIDTH', whatever that is

	# OP - Opening Punctuation
	return 'OP' if
		/^\p{Ps}$/;

	# PO - Postfix
	return 'PO' if
		$ord == 0x0025 || $ord == 0x00a2 || $ord == 0x00b0 ||
		$ord == 0x2030 || $ord == 0x2031 ||
		$ord >= 0x2032 && $ord <= 0x2037 ||
		$ord == 0x20a7 || $ord == 0x2103 || $ord == 0x2109 ||
		$ord == 0x2126 || $ord == 0xfe6a || $ord == 0xff05 ||
		$ord == 0xffe0;

	# PR - Prefix
	return 'PR' if
		/^\p{Sc}$/ ||
		$ord == 0x002b || $ord == 0x005c || $ord == 0x00b1 ||
		$ord == 0x2116 || $ord == 0x2212 || $ord == 0x2213;

	# QU - Ambiguous Quotation
	return 'QU' if
		$ord == 0x0022 || $ord == 0x0027 || $ord == 0x23b6 ||
		$ord == 0x23b6 || $ord >= 0x275b && $ord <= 0x275e;

	# SA - Complex-context Dependent Characters
	return 'SA' if
		$ord >= 0x0e00 && $ord <= 0x0eff ||
		$ord >= 0x1000 && $ord <= 0x109f ||
		$ord >= 0x1780 && $ord <= 0x17ff;

	# SG - Surrogates
	return 'SG' if
		/^\p{Cs}$/;

	# SP - Space
	return 'SP' if $ord == 0x0020;

	# SY - Symbols Allowing Break After
	return 'SY' if $ord == 0x002f;

	# XX - Unknown
	return 'XX' if
		/^[\p{Co}\p{Cn}]$/;

	# ZW - Zero Width Space
	return 'ZW' if $ord == 0x200b;
	
	# CM - Attached Characters and Combining Marks
	return 'CM' if
		# Combining characters
		/^\p{M}$/ ||
		# Conjoining Jamos (non-initial)
		$ord >= 0x1160 && $ord <= 0x11f9 ||
		# Control and formatting characters
		/^\p{Cc}$/ || /^\p{Cf}/;

	# ID (part 2)
	return 'ID' if 
		$ord >= 0x3000 && $ord <= 0x33ff ||
		$ord >= 0xff21 && $ord <= 0xff5a;

	# AL - Ordinary Alphabetic and Symbol Characters	
	return 'AL' if /^\p{L}$/ || /^[\p{Sm}\p{Sk}\p{So}]/;

	return 'XX';  # fall back?
}

__END__

=head1 NAME

Unicode::Wrap - Unicode Line Breaking

=head1 SYNOPSIS

  use Unicode::Wrap;

  my $wrapper = new Unicode::Wrap( line_length => 75 );
  my $text = $wrapper->wrap($long_string);	# Unwrapped string
  my $text = $wrapper->rewrap($long_string);	# Remove newlines first

=head1 ABSTRACT

This module implements UAX#14: Line Breaking Properties.  It goes
through a text string, classifies each character and computes a
length for each.  When the line gets too long, a break is inserted
where appropriate.

=head1 DESCRIPTION

The following methods are available:

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

=item length_lookup

This should contain a coderef to your own 'length' implementation.  It
will be passed the character in question and the classification of that
character.  It should return the length of the character in your chosen
unit.

This may also contain a simple hashref, keyed on the character, with
values consisting of the length of that character.

=back

=item wrap($text, ...)

This will take a chunk of text, normalize the newlines (but preserve them)
and attempt to wrap it per UAX#14.  More than one block of text can be
wrapped, but each block is wrapped independently from the previous.

=item rewrap($text, ...)

This does the same thing as C<wrap>, except that newlines are normalized
to spaces before wrapping.  This might be used if you already have a
paragraph of text that you want to re-wrap.

=back

=head1 BUGS

=over 4

=item This module is slow.  It's a pure-Perl implementation that goes through
an expensive classification process per character.

=item Some classification rules may not be complete.  These are noted with
'TODO' in the code.

=item Combining Marks should "inherit" the breaking properties of the character
they're being combined with, so that if a character normally allows a break
after, the opportunity needs to be translated to the combining mark, so that
the break can occur after the combined result.

=item Tests are not very complete.

=back

=head1 SEE ALSO

=over 4

=item http://www.unicode.org/reports/tr14/

Unicode Standard Annex #14: Line Breaking Properties

=back

=head1 AUTHOR

David NESTING E<lt>david@fastolfe.netE<gt>

Copyright (c) 2003 David Nesting.  All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
