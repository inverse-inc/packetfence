package pf::condition::date_compare;

=head1 NAME

pf::condition::date_compare

=cut

=head1 DESCRIPTION

Base class to compare a given date with the actual (or supplied) date

Date format is YYYY-MM-DD HH:MM:SS, YYYY-MM-DD HH:MM or YYYY-MM-DD.
An empty value or 'now' means the date at the moment of the evaluation.
Any other value that isn't a valid date makes the construction fail.
A compared date that can't be parsed (e.g. an unset 0000-00-00 00:00:00 date)
never matches, also when the comparison is negated.

=cut

use strict;
use warnings;

use Moose;
use Time::Piece;
use pf::log;

extends 'pf::condition';

has value => (
    is => 'rw',
    isa => 'Maybe[Str]',
    required => 0,
);

=head2 negate

Negate the comparison (not_date_is_before, not_date_is_after). Unlike wrapping
the condition in pf::condition::not, a date that can't be parsed still doesn't match.

=cut

has negate => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

has _control_date => (
    is => 'rw',
);

our $DATE_FORMAT = "%Y-%m-%d %H:%M:%S";

our @FORMATS = (
    [qr/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\z/, $DATE_FORMAT],
    [qr/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}\z/, "%Y-%m-%d %H:%M"],
    [qr/\A\d{4}-\d{2}-\d{2}\z/, "%Y-%m-%d"],
);

=head2 BUILD

Parse a fixed control date once, die when it isn't valid

=cut

sub BUILD {
    my ($self) = @_;
    return if $self->is_now;
    my $date = parse_date($self->value);
    die "Invalid date '" . $self->value . "', the format is YYYY-MM-DD HH:MM:SS, YYYY-MM-DD HH:MM, YYYY-MM-DD or now\n" if !defined $date;
    $self->_control_date($date);
}

=head2 is_now

Whether the control date is the time of the evaluation (empty value or 'now')

=cut

sub is_now {
    my ($self) = @_;
    my $value = $self->value;
    return !defined $value || $value =~ /^\s*(now)?\s*$/i;
}

=head2 match

Parse both dates and compare them with compare_dates

=cut

sub match {
    my ($self, $arg, $args) = @_;

    my $date_to_compare = parse_date($arg);
    if (!defined $date_to_compare) {
        get_logger->debug(sub { "Unable to parse the date '" . ($arg // '') . "', not matching" });
        return 0;
    }

    my $result = $self->compare_dates($date_to_compare, $self->control_date) ? 1 : 0;
    return $self->negate ? !$result || 0 : $result;
}

=head2 control_date

The date to compare with, the current time when the value is empty or 'now'

=cut

sub control_date {
    my ($self) = @_;
    if ($self->is_now) {
        # Parsed back like the given dates so both are compared the same way
        return Time::Piece->strptime(localtime->strftime($DATE_FORMAT), $DATE_FORMAT);
    }
    return $self->_control_date;
}

=head2 parse_date

Parse a YYYY-MM-DD HH:MM:SS, YYYY-MM-DD HH:MM or YYYY-MM-DD date, returns undef if it can't

=cut

sub parse_date {
    my ($date) = @_;
    return undef if !defined $date;
    $date =~ s/^\s+|\s+$//g;
    return undef if $date eq '' || $date =~ /^0000-00-00/;
    for my $format (@FORMATS) {
        my ($re, $strptime_format) = @$format;
        next if $date !~ $re;
        return scalar eval { Time::Piece->strptime($date, $strptime_format) };
    }
    return undef;
}

=head2 compare_dates

Implemented by the subclasses

=cut

sub compare_dates {
    die "compare_dates must be implemented";
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;
