package pf::profile::filter::day_of_week;
=head1 NAME

pf::profile::filter::day_of_week - Day of week filter for profiles

=cut

=head1 DESCRIPTION

pf::profile::filter::day_of_week

=cut

use strict;
use warnings;
use Date::Format;
use Moo;
extends 'pf::profile::filter';

=head1 ATTRIBUTES

=head2 allowed_days

The allowed days of the week

=cut

has allowed_days => ( is => 'rw' );

=head2 value

add a trigger to the value to create/update allowed_days

=cut

has '+value' => ( trigger => 1, isa => sub { $_[0] =~ /^[1-7](\s*,\s*[1-7])*$/ || die "value is not a comma separated list of number 1-7" } );

=head1 METHODS

=head2 match

    Return true if the current day of week matches the values provided
    The value is expected to be in the following format
    1,3,5
    Where the number is the day of the week
    1 - Monday
    2 - Tuesday
    3 - Wednesday
    4 - Thursday
    5 - Friday
    6 - Saturday
    7 - Sunday

=cut

sub match {
    my ($self) = @_;
    my $current = time2str("%W",time);
    return ${$self->allowed_days}{$current};
}

=head2 _trigger_value

Set allowed_days from the value

=cut

sub _trigger_value {
    my ($self) = @_;
    my %allowed_days = map { $_ => 1 } split /\s*,\s*/ ,$self->value;
    $self->allowed_days(\%allowed_days);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
