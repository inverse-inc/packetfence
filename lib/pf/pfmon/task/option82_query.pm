package pf::pfmon::task::option82_query;

=head1 NAME

pf::pfmon::task::option82_query - class for pfmon task option82 query

=cut

=head1 DESCRIPTION

pf::pfmon::task::option82_query

=cut

use strict;
use warnings;
use Moose;
use pf::config qw(%Config);
use pf::option82 qw(search_switch);
use pf::util;
extends qw(pf::pfmon::task);


=head2 run

run the option82 query task

=cut

sub run {
    search_switch() if isenabled($Config{'network'}{'dhcpoption82logger'});
}

=head1 AUTHOR


Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
