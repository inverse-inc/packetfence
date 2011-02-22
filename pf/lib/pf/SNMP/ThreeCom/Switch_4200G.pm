package pf::SNMP::ThreeCom::Switch_4200G;

=head1 NAME

pf::SNMP::ThreeCom::Switch_4200G - Object oriented module to access SNMP
enabled 3COM 4200G Switch

=head1 STATUS

This module is currently only a placeholder, see pf::SNMP::ThreeCom::SS4500.

=cut

use strict;
use warnings;
use diagnostics;

use Log::Log4perl;
use Net::SNMP;

# FIXME whenever we have a breaking change opportunity, rename to SS4200G.
use base ('pf::SNMP::ThreeCom::SS4500');

=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009-2011 Inverse inc.

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
