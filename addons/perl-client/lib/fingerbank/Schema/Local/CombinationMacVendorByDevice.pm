package fingerbank::Schema::Local::CombinationMacVendorByDevice;

use Moose;
use namespace::autoclean;

=head1 NAME

fingerbank::Schema::Local::CombinationMacVendorByDevice - DB query

=head1 DESCRIPTION

DB query
Query is rewritten to be able to use local combination if you need to add some specific MAC OUI to be allowed for device registration.

=cut

extends 'fingerbank::Base::Schema::CombinationMacVendorByDevice';

# $1 = mac_vendor
#
__PACKAGE__->view_with_named_params(q{
    SELECT device_id FROM combination
    WHERE mac_vendor_id = $1
    GROUP BY device_id
    ORDER BY COUNT(device_id)
    DESC LIMIT 1
});

=head1 AUTHOR
Inverse inc. <info@inverse.ca>
=head1 COPYRIGHT
Copyright (C) 2005-2017 Inverse inc.
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

__PACKAGE__->meta->make_immutable;

1;
