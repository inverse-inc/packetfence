package pf::Switch::Avaya::ERS2500;

=head1 NAME

pf::Switch::Avaya::ERS2500 - Object oriented module to access SNMP enabled Avaya ERS2500 switches

=head1 SYNOPSIS

The pf::Switch::Avaya::ERS2500 module implements an object 
oriented interface to access SNMP enabled Avaya::ERS2500 switches.

=head1 STATUS

This module is currently only a placeholder, see L<pf::Switch::Avaya>.

Recommended firmware 4.3

=head1 BUGS AND LIMITATIONS

=over

=item ERS 25xx firmware 4.1

We received reports saying that port authorization / de-authorization in port-security did not work.
At this point we do not know exactly which firmwares are affected by the issue.

Firmware series 4.3 is apparently fine.

=back

=cut

use strict;
use warnings;

use Net::SNMP;

use base ('pf::Switch::Avaya');

sub description { 'Avaya ERS 2500 Series' }

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
