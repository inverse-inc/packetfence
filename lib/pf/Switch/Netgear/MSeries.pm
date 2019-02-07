package pf::Switch::Netgear::MSeries;

=head1 NAME

pf::Switch::Netgear::MSeries - Object oriented module to access and configure Netgear M series switches.

head1 STATUS

Tested on a Netgear M4100 on firmware 10.0.1.27

=cut

use strict;
use warnings;

use pf::constants;

use base ('pf::Switch::Netgear');

sub supportsWiredMacAuth { return $TRUE }
sub supportsRadiusDynamicVlanAssignment { return $TRUE; }
sub description { return 'Netgear M series' }


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
