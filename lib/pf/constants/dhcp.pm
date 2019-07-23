package pf::constants::dhcp;

=head1 NAME

pf::constants::dhcp - constants for dhcp

=cut

=head1 DESCRIPTION

pf::constants::dhcp

=cut

use strict;
use warnings;
use base qw(Exporter);
use Readonly;

our @EXPORT_OK = qw($DEFAULT_LEASE_LENGTH);

Readonly our $DEFAULT_LEASE_LENGTH => 86400;

# The default timeouts for calling the DHCP API
Readonly our $DHCP_API_DEFAULT_TIMEOUT => 500;
Readonly our $DHCP_API_DEFAULT_CONNECT_TIMEOUT => 500;

# DHCP server select ip algorithm
Readonly our $RANDOM_ALGORITHM => 1;
Readonly our $OLDEST_RELEASED_ALGORITHM => 2;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

