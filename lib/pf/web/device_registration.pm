package pf::web::device_registration;

=head1 NAME

pf::web::device

=cut

=head1 DESCRIPTION

Library for the device registration page

=cut

use strict;
use warnings;

use HTML::Entities;
use Readonly;

use pf::constants;
use pf::config qw(%Config);
use pf::enforcement qw(reevaluate_access);
use pf::node qw(node_register is_max_reg_nodes_reached);
use pf::util;
use pf::error qw(is_success);
use pf::log;
use pf::web;
use pf::web::custom;    # called last to allow redefinitions

use pf::authentication;
use pf::Authentication::constants;
use List::MoreUtils qw(any);

=head1 SUBROUTINES

=cut

=item mac_vendor_id

Get the matching mac_vendor_id from Fingerbank

=cut

sub mac_vendor_id {
    my ($mac) = @_; 
    my $logger = get_logger();

    my ($status, $result) = fingerbank::Model::MAC_Vendor->find([{ mac => $mac }, {columns => ['id']}]);

    if(is_success($status)){
        return $result->id;
    }else {
        $logger->debug("Cannot find mac vendor ".$mac." in the database");
    }
}

=item device_from_mac_vendor

Get the matching device infos by mac vendor from Fingerbank

=cut

sub device_from_mac_vendor {
    my ($mac_vendor_id) = @_; 
    my $logger = get_logger();

    my ($status, $result) = fingerbank::Model::Combination->find([{ mac_vendor_id => $mac_vendor_id }, {columns => ['device_id']}]);

    if(is_success($status)){
        return $result;#->device_id;
    }else {
        $logger->debug("Cannot find matching device id ".$result->device_id." for this mac vendor id ".$mac_vendor_id." in the database");
    }
}

=item is_allowed 

Verify 

=cut 

sub is_allowed {
    my ($mac) = @_;
    $mac =~ s/O/0/i;
    my $logger = get_logger();
    my @oses = @{$Config{'device_registration'}{'allowed_devices'}};

    #if no oses are defined then it will not match any oses
    return $FALSE if @oses == 0;

    $mac =~ s/://g;
    my $mac_vendor = substr($mac, 0,6);
    my $mac_vendor_id = mac_vendor_id($mac_vendor);
    my $device = device_from_mac_vendor($mac_vendor_id);
    my $device_id = $device->device_id;
    my ($status, $result) = fingerbank::Model::Device->find([{ id => $device_id}, {columns => ['name']}]);

    # We are loading the fingerbank endpoint model to verify if the device id is matching as a parent or child
    if (is_success($status)){
        my $device_name = $result->name;
        my $endpoint = fingerbank::Model::Endpoint->new(name => $device_name, version => undef, score => undef);

        for my $id (@oses) {
            $logger->debug("The devices type ".$device_name." is authorized to be registered via the device-registration module");
            return $TRUE if($endpoint->is_a_by_id($id));
        }
    } else {
        $logger->debug("Cannot find a matching device name for this device id ".$device_id." .");
        return $FALSE;
    }
}

=back

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

1;
