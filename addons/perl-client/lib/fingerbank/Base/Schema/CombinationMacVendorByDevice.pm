package fingerbank::Base::Schema::CombinationMacVendorByDevice;

use Moose;
use namespace::autoclean;

extends 'fingerbank::Base::Schema';

=head1 NAME

fingerbank::Base::Schema::CombinationMacVendorByDevice - DB query

=head1 DESCRIPTION

DB query

=cut 

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');

__PACKAGE__->table('combinationmacvendorbydevice');

__PACKAGE__->add_columns(
    "device_id",
);

__PACKAGE__->set_primary_key('device_id');

__PACKAGE__->result_source_instance->is_virtual(1);

# $1 = mac_vendor
#
__PACKAGE__->view_with_named_params(q{
    SELECT device_id FROM combination
    WHERE mac_vendor_id = $1
    GROUP BY device_id
    HAVING COUNT(device_id) > 5
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
