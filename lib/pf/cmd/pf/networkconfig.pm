package pf::cmd::pf::networkconfig;
=head1 NAME

pf::cmd::pf::networkconfig add documentation

=head1 SYNOPSIS

 pfcmd networkconfig get <all|network>
       pfcmd networkconfig add <network> [assignments]
       pfcmd networkconfig edit <network> [assignments]
       pfcmd networkconfig delete <network>

query/modify networks.conf configuration file

=head1 DESCRIPTION

pf::cmd::pf::networkconfig

=cut

use strict;
use warnings;
use pf::ConfigStore::Network;
use base qw(pf::base::cmd::config_store);

sub configStoreName { "pf::ConfigStore::Network" }

sub display_fields { qw(network type named dhcpd netmask gateway next_hop domain-name dns dhcp_start dhcp_end dhcp_default_lease_time dhcp_max_lease_time) }

sub idKey { 'network' }

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

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

