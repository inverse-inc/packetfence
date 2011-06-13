package pf::SNMP::HP::Procurve_5400;

=head1 NAME

pf::SNMP::HP::Procurve_5400

=head1 SYNOPSIS

Module to manage HP Procurve 5400 switches

=head1 STATUS

=over

=item Supports 

=over

=item linkUp / linkDown mode

=item port-security

=back

=back

Has been reported to work on 5412zl by the community

=head1 BUGS AND LIMITATIONS

The code is the same as the 2500 but the configuration should be like the 4100 series.

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;

use base ('pf::SNMP::HP::Procurve_2500');

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

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
