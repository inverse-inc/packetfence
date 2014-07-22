package pf::profile::filter::time_of_day;
=head1 NAME

pf::profile::filter::time_of_day add documentation

=cut

=head1 DESCRIPTION

pf::profile::filter::time_of_day

=cut

use strict;
use warnings;
use Date::Format;
use Moo;
extends 'pf::profile::filter';


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
    my ($start,$end) = split(/-/,$self->value);
    my $current = time2str("%H:%M",time);
    return ($start le $current) && ($current le $end);
}
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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

