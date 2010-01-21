package pf::SNMP::Cisco::ISR_1800;

=head1 NAME

pf::SNMP::Cisco::ISR_1800 - Object oriented module to access SNMP enabled Cisco 1800 routers

=head1 SYNOPSIS

The pf::SNMP::Cisco::ISR_1800 module implements an object oriented interface
to access SNMP enabled Cisco 1800 routers.

No documented minimum required firmware version.

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP::Cisco');
use Log::Log4perl;
use Carp;
use Net::SNMP;

#sub getMinOSVersion {
#    my $this   = shift;
#    my $logger = Log::Log4perl::get_logger( ref($this) );
#    return '';
#}

# return the list of managed ports
#sub getManagedPorts {
#}

#obtain hashref from result of getMacAddr
#sub _getIfDescMacVlan {
#}

#sub clearMacAddressTable {
#}

#sub getMaxMacAddresses {
#}


=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

