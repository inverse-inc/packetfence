package pf::SNMP::LG::ES4500G;

=head1 NAME

pf::SNMP::LG::ES4500G - Object oriented module to access and configure LG-Ericsson iPECS ES-4500G series.

=head1 STATUS

=over

=item Link UP / DOWN

- Supported using operating code version 1.2.3.2 with links UP/DOWN traps enabled.

=item Port-security

- Supported using operating code version 1.2.3.2 with authentication traps enabled.
- VoIP configuration not tested.

=item MAC-Authentication / 802.1X

- The hardware support it.

=back

=head1 BUGS AND LIMITATIONS

=over

=item Link UP / DOWN

- Seems to have a firmware bug that doesn't send traps on interfaces down.

=item Port-security

- The three port security statements (port security, port security max-mac-count, port security action) 
are required on each port security enabled ports for the switch to correctly handle the feature. Make sure that
the "port security" statement is correctly enabled using the recommandation in the "Network devices guide". If not
correctly enabled, the method isPortSecurityEnabled can't return a good value and the switch sets the device MAC address
to learn rather than static.

=item Stack

- Stack configuration not tested.

=back

=cut

use strict;
use warnings;
use diagnostics;

use POSIX;
use Log::Log4perl;
use Net::SNMP;

use pf::SNMP::constants;
use pf::config;
use pf::util;

use base ('pf::SNMP::LG');

# CAPABILITIES
# access technology supported
sub supportsSnmpTraps { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }
sub supportsWiredMacAuth { return $TRUE; }

=head1 SUBROUTINES

This list is incomplete.

This module act as a placeholder for future use.
         
=over   

=cut



=back

=head1 AUTHOR

Derek Wuelfrath <dwuelfrath@inverse.ca>

Francois Gaudreault <fgaudreault@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
