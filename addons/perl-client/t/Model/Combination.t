#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib 'lib';
use lib 't';

use Test::More;

BEGIN {
    use setup_tests;
    use data::seed;
}

use fingerbank::Util qw(is_success);

use_ok('fingerbank::Model::Combination');

my ($status, $result);

($status, $result) = fingerbank::Model::Combination->create({});

ok(is_success($status), 
    "Can create a combination without specifying all parameters");

my $id = $result->{id};

($status, $result) = fingerbank::Model::Combination->read($id);

ok($result->{dhcp_vendor_id} eq "",
    "Created combination has right attribute when specified");

ok($result->{dhcp_fingerprint_id} eq "",
    "Default value is properly taken into account for dhcp_fingerprint_id");

ok($result->{user_agent_id} eq "",
    "Default value is properly taken into account for user_agent_id");

ok($result->{mac_vendor_id} eq "",
    "Default value is properly taken into account for mac_vendor_id");

ok($result->{dhcp6_enterprise_id} eq "",
    "Default value is properly taken into account for dhcp6_enterprise_id");

ok($result->{dhcp6_fingerprint_id} eq "",
    "Default value is properly taken into account for dhcp6_fingeprint_id");

ok(!defined($result->{device_id}),
    "Default value is properly taken into account for device_id");

my $args = {
    dhcp_fingerprint_id => "1",
    dhcp_vendor_id => "2",
    user_agent_id => "3",
    mac_vendor_id => "4",
    dhcp6_enterprise_id => "5",
    dhcp6_fingerprint_id => "6",
    device_id => "7",
    version => "69.69",
};

($status, $result) = fingerbank::Model::Combination->create($args);

ok(is_success($status),
    "Can create a combination with all arguments specified");

while(my ($attribute, $value) = each %$args){
    ok($value eq $result->{$attribute},
        "Attribute $attribute is properly set when creating a new combination");
}

done_testing();

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

