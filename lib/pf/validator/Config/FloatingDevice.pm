package pf::validator::Config::FloatingDevice;

=head1 NAME

pf::validator::Config::FloatingDevice -

=head1 DESCRIPTION

pf::validator::Config::FloatingDevice

=cut

use strict;
use warnings;
use pf::validator::Moose;
extends qw(pf::validator);

has_field id => (
    type => 'MACAddress',
    text => 'MAC Address',
    required => 1,
);

has_field 'ip' => (
   type => 'IPAddress',
   text => 'IP Address',
);

has_field 'pvid' => (
   type => 'PosInteger',
   text => 'Native VLAN',
   required => 1,
);

has_field 'trunkPort' => (
   type => 'Bool',
   label => 'Trunk Port',
   true_value => 'yes',
   false_value => 'no',
);

has_field 'taggedVlan' => (
   type => 'String',
   text => 'Tagged VLANs',
);


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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

