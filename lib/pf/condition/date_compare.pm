package pf::condition::date_compare;

=head1 NAME

pf::condition::date_compare

=cut

=head1 DESCRIPTION

Base class to compare a given date with the actual (or supplied) date

Date format is YYYY-MM-DD HH:MM:SS or YYYY-MM-DD.
An empty value or 'now' means the date at the moment of the evaluation.
A date that can't be parsed (e.g. an unset 0000-00-00 00:00:00 date) never matches.

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

our $DATE_FORMAT = "%Y-%m-%d %H:%M:%S";

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

    my $date_control = $self->control_date;
    if (!defined $date_control) {
        get_logger->warn("Unable to parse the control date '" . $self->value . "', not matching");
        return 0;
    }

    return $self->compare_dates($date_to_compare, $date_control) ? 1 : 0;
}

=head2 control_date

The date to compare with, the current time when the value is empty or 'now'

=cut

sub control_date {
    my ($self) = @_;
    my $value = $self->value;
    if (!defined $value || $value =~ /^\s*(now)?\s*$/i) {
        # Parsed back like the given dates so both are compared the same way
        return Time::Piece->strptime(localtime->strftime($DATE_FORMAT), $DATE_FORMAT);
    }
    return parse_date($value);
}

=head2 parse_date

Parse a YYYY-MM-DD HH:MM:SS or YYYY-MM-DD date, returns undef if it can't

=cut

sub parse_date {
    my ($date) = @_;
    return undef if !defined $date;
    $date =~ s/^\s+|\s+$//g;
    return undef if $date eq '' || $date =~ /^0000-00-00/;
    # strptime warns about trailing characters it doesn't parse
    local $SIG{__WARN__} = sub {};
    for my $format ($DATE_FORMAT, "%Y-%m-%d") {
        my $parsed = eval { Time::Piece->strptime($date, $format) };
        return $parsed if defined $parsed;
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
