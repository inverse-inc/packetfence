package pf::SNMP::Dlink::DES_3550;

=head1 NAME

pf::SNMP::Dlink::DES_3550

=head1 SYNOPSIS

Object oriented module to access and manage Dlink DES 3550 switches

=head1 STATUS

Might support link-up link-down

Supports MAC Notification

This module is currently only a placeholder, see pf::SNMP::Dlink

Tested by the community on the 5.01.B65 firmware.

=cut

use strict;
use warnings;
use diagnostics;

use Log::Log4perl;
use Net::SNMP;

use base ('pf::SNMP::Nortel');

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

Module contributed by Olivier Roch Vilato <olivier.rochvilato@chilbp.fr> 
but his parseTrap was integrated into Dlink instead for less code duplication and easier maintenance.

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
