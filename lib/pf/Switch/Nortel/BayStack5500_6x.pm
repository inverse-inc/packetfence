package pf::Switch::Nortel::BayStack5500_6x;

=head1 NAME

pf::Switch::Nortel::BayStack5500_6x

=head1 DESCRIPTION

Object oriented module to access SNMP enabled Nortel BayStack5500 switches running software code >= 6.x.

Starting with firmware 6.x ifIndex handling changed and this module takes care of this change.

=head1 STATUS

Aside from ifIndex handling this module is identical to pf::Switch::Nortel.

=cut

use strict;
use warnings;

use Net::SNMP;

use base ('pf::Switch::Nortel');

sub description { 'Nortel BayStack 5500 w/ firmware 6.x' }

=head1 METHODS

TODO: This list is incomplete

=over

=item getBoardIndexWidth

How many ifIndex there is per board.
It changed with a firmware upgrade so it is encapsulated per switch module.

This module has 128.

=cut

sub getBoardIndexWidth {
    return 128;
}

=back

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
