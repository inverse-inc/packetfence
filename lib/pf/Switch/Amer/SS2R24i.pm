package pf::Switch::Amer::SS2R24i;

=head1 NAME

pf::Switch::Amer::SS2R24i - Object oriented module to access SNMP enabled Amer SS2R24i switches

=head1 SYNOPSIS

The pf::Switch::Amer::SS2R24i module implements an object oriented interface
to access SNMP enabled Amer::SS2R24i switches.

=head1 STATUS

This module is currently only a placeholder, all the logic resides in Amer.pm

Currently only supports linkUp / linkDown mode

Developed and tested on SS2R24i running on firmware version 4.02-B15

=cut

use strict;
use warnings;
use Net::SNMP;
use base ('pf::Switch::Amer');

sub description { 'Amer SS2R24i' }

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
