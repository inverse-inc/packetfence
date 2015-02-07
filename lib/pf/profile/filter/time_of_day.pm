package pf::profile::filter::time_of_day;
=head1 NAME

pf::profile::filter::time_of_day - Time of day filter for profiles

=cut

=head1 DESCRIPTION

pf::profile::filter::time_of_day

=cut

use strict;
use warnings;
use Date::Format;
use Moo;
extends 'pf::profile::filter';

=head1 ATTRIBUTES

=head2 start_time/end_time

The start and end time

=cut

has [qw(start_time end_time)] => ( is => 'rw' );

=head2 value

add a trigger to the value to create/update start_time and end_time

=cut

has '+value' => ( trigger => 1, isa => sub { $_[0] =~ /^\d{2}:\d{2}-\d{2}:\d{2}$/ || die "value is not in the form HH:MM-HH:MM" } );

=head1 METHODS

=head2 match

    Matches the time of day against the value
    The value is expected to be in the following format
    Start-End
    From midnight to 6am
    00:00-06:00
    All time must be in the format HH::MM

=cut

sub match {
    my ($self) = @_;
    my $current = time2str("%H:%M",time);
    return ($self->start_time le $current) && ($current le $self->end_time);
}

=head2 _trigger_value

Set start_time and end_time from the value

=cut

sub _trigger_value {
    my ($self) = @_;
    my ($start,$end) = split(/-/,$self->value);
    $self->start_time($start);
    $self->end_time($end);
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

