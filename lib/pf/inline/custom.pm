package pf::inline::custom;

=head1 NAME

pf::inline - Object oriented module for inline enforcement related operations

=head1 SYNOPSIS

The pf::inline::custom module implements inline enforcement operations that are custom to a particular setup.

This module extends pf::inline

=cut

use strict;
use warnings;


use base ('pf::inline');
use pf::config;
use pf::iptables;
use pf::node qw(node_attributes);
use pf::security_event qw(security_event_count_reevaluate_access);

our $VERSION = 1.01;

=head1 SUBROUTINES

=over

=cut

=back

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
