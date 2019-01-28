package pf::roles::custom;

=head1 NAME

pf::roles::custom - OO module that performs the roles lookups for nodes

=head1 SYNOPSIS

The pf::roles::custom implements roles lookups for nodes that are custom to a particular setup. 

This module extends pf::roles

=head1 EXPERIMENTAL

This module is considered experimental. For example not a lot of information
is provided to make the role decisions. This is expected to change in the
future at the cost of API changes.

You have been warned!

=cut

use strict;
use warnings;


use base ('pf::roles');
use pf::config;
use pf::node qw(node_attributes);
use pf::security_event qw(security_event_count_reevaluate_access);

our $VERSION = 0.90;

=head1 SUBROUTINES

=over

=cut

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
