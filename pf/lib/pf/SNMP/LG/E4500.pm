package pf::SNMP::LG::E4500;

=head1 NAME

pf::SNMP::LG::E4500 - Object oriented module to access and configure LG-Ericsson iPecs 4500

=head1 STATUS

=over

=item port-security

This is not yet supported.

=item MAC-Authentication / 802.1X

The hardware support it.

=back

=cut
use strict;
use warnings;
use diagnostics;

use Log::Log4perl;
use Net::SNMP;

use pf::config;

use base ('pf::SNMP::LG');

# CAPABILITIES
# access technology supported
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }
sub supportsSnmpTraps { return $FALSE; }

=head1 AUTHOR

Francois Gaudreault <fgaudreault@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2006-2011 Inverse inc.

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
