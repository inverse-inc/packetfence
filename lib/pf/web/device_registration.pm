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

use fingerbank::Model::Endpoint;
use pf::constants;
use pf::config qw(%Config);
use pf::enforcement qw(reevaluate_access);
use pf::node qw(node_register is_max_reg_nodes_reached);
use pf::util;
use pf::db;
use pf::log;
use pf::web;
use pf::web::custom;    # called last to allow redefinitions

use pf::authentication;
use pf::Authentication::constants;
use List::MoreUtils qw(any);
use constant DEVICE_REGISTRATION => 'web::device_registration';

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $device_registration_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $device_registration_statements = {};

=head1 SUBROUTINES

=cut

=head1 device_registration_db_prepare

Queries to fetch mac_vendor_id and device_id matching

=cut

sub device_registration_db_prepare {
    my $logger = get_logger(); 
    $logger->debug("Preparing pf::web::device_registration database queries");
    
    $device_registration_statements->{'device_registration_mac_vendor_id_sql'} = get_db_handle()->prepare(qq[ 
        SELECT id 
        FROM mac_vendor 
        WHERE mac= ?
    ]);

    $device_registration_statements->{'device_registration_device_id_sql'} = get_db_handle()->prepare(qq[ 
        SELECT device_id, device_name 
        FROM combination 
        WHERE mac_vendor_id= ?
        GROUP BY device_id 
        ORDER BY count(device_id) desc LIMIT 1
    ]);

    $device_registration_db_prepared = 1;
}

=item mac_vendor_id

Get the matching mac_vendor_id from Fingerbank

=cut

sub mac_vendor_id {
    my ($mac) = @_; 

    return(db_query_execute(DEVICE_REGISTRATION, $device_registration_statements, 'device_registration_mac_vendor_id_sql', $mac));
}

=item device_id

Get the matching device_id from Fingerbank

=cut

sub device_id {
    my ($mac_vendor_id) = @_; 
    
    return(db_query_execute(DEVICE_REGISTRATION, $device_registration_statements, 'device_registration_device_id_sql', $mac_vendor_id));
}

=item is_allowed 

Verify 

=cut 

sub is_allowed {
    my ($mac) = @_;
    my @oses = $Config{'device_registration'}{'oses'};

    #if no oses are defined then it will not match any oses
    return $FALSE if @oses == 0;

    $mac =~ s/://g;
    my $mac_vendor = substr($mac, 0,6);
    my $mac_vendor_id = mac_vendor_id($mac_vendor);
    my ($device_id, $device_name) = device_id($mac_vendor_id);

    # We are loading the fingerbank endpoint model to verify if the device id is matching as a parent or child

    my $endpoint = fingerbank::Model::Endpoint->new(name => $device_name, version => undef, score => undef);
    my $endpoint_id = $endpoint->is_a_by_id($device_id);

    if (grep {$endpoint_id eq $_} @oses) {
        return $TRUE
    } else {
        return $FALSE
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
