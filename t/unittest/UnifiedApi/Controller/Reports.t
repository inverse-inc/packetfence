#!/usr/bin/perl

=head1 NAME

Reports

=cut

=head1 DESCRIPTION

unit test for Reports

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 188;
use Test::Mojo;

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

$t->get_ok('/api/v1/reports/os' => json => { })
  ->json_has('/items/0/count')
  ->json_has('/items/0/description')
  ->json_has('/items/0/percent')
  ->status_is(200);

$t->get_ok('/api/v1/reports/os/1000-01-01/9999-01-01' => json => { })
  ->json_has('/items/0/count')
  ->json_has('/items/0/description')
  ->json_has('/items/0/percent')
  ->status_is(200);

$t->get_ok('/api/v1/reports/os/active' => json => {  })
  ->json_has('/items/0/count')
  ->json_has('/items/0/description')
  ->json_has('/items/0/percent')
  ->status_is(200);

$t->get_ok('/api/v1/reports/osclass' => json => {  })
  ->json_has('/items/0/count')
  ->json_has('/items/0/description')
  ->json_has('/items/0/percent')
  ->status_is(200);

$t->get_ok('/api/v1/reports/osclass/active' => json => {  })
  ->json_has('/items')
  ->status_is(200);

$t->get_ok('/api/v1/reports/inactive' => json => {  })
  ->json_has('/items')
  ->status_is(200);

$t->get_ok('/api/v1/reports/active' => json => {  })
  ->json_has('/items')
  ->status_is(200);

$t->get_ok('/api/v1/reports/unregistered' => json => {  })
  ->json_has('/items')
  ->status_is(200);

$t->get_ok('/api/v1/reports/unregistered/active' => json => {  })
  ->json_has('/items')
  ->status_is(200);

$t->get_ok('/api/v1/reports/registered' => json => {  })
  ->json_has('/items')
  ->status_is(200);

$t->get_ok('/api/v1/reports/registered/active' => json => {  })
  ->json_has('/items')
  ->status_is(200);

$t->get_ok('/api/v1/reports/unknownprints' => json => {  })
  ->json_has('/items')
  ->status_is(200);

$t->get_ok('/api/v1/reports/unknownprints/active' => json => {  })
  ->json_has('/items')
  ->status_is(200);

$t->get_ok('/api/v1/reports/statics' => json => {  })
  ->json_has('/items')
  ->status_is(200);

$t->get_ok('/api/v1/reports/statics/active' => json => {  })
  ->json_has('/items')
  ->status_is(200);

$t->get_ok('/api/v1/reports/opensecurity_events' => json => {  })
  ->json_has('/items')
  ->status_is(200);

$t->get_ok('/api/v1/reports/opensecurity_events/active' => json => {  })
  ->json_has('/items')
  ->status_is(200);

$t->get_ok('/api/v1/reports/connectiontype' => json => {  })
  ->json_has('/items/0/connection_type')
  ->json_has('/items/0/connections')
  ->json_has('/items/0/percent')
  ->status_is(200);

$t->get_ok('/api/v1/reports/connectiontype/1000-01-01/9999-01-01' => json => {  })
  ->json_has('/items/0/connection_type')
  ->json_has('/items/0/connections')
  ->json_has('/items/0/percent')
  ->status_is(200);

$t->get_ok('/api/v1/reports/connectiontype/active' => json => {  })
  ->json_has('/items/0/connection_type')
  ->json_has('/items/0/connections')
  ->json_has('/items/0/percent')
  ->status_is(200);

$t->get_ok('/api/v1/reports/connectiontypereg' => json => {  })
  ->json_has('/items/0/connection_type')
  ->json_has('/items/0/connections')
  ->json_has('/items/0/percent')
  ->status_is(200);

$t->get_ok('/api/v1/reports/connectiontypereg/active' => json => {  })
  ->json_has('/items/0/connection_type')
  ->json_has('/items/0/connections')
  ->json_has('/items/0/percent')
  ->status_is(200);

$t->get_ok('/api/v1/reports/ssid' => json => {  })
  ->json_has('/items/0/nodes')
  ->json_has('/items/0/percent')
  ->json_has('/items/0/ssid')
  ->status_is(200);

$t->get_ok('/api/v1/reports/ssid/1000-01-01/9999-01-01' => json => {  })
  ->json_has('/items/0/nodes')
  ->json_has('/items/0/percent')
  ->json_has('/items/0/ssid')
  ->status_is(200);

$t->get_ok('/api/v1/reports/ssid/active' => json => {  })
  ->json_has('/items/0/nodes')
  ->json_has('/items/0/percent')
  ->json_has('/items/0/ssid')
  ->status_is(200);

$t->get_ok('/api/v1/reports/osclassbandwidth' => json => {  })
  ->json_has('/items/0/accttotal')
  ->json_has('/items/0/accttotaloctets')
  ->json_has('/items/0/dhcp_fingerprint')
  ->json_has('/items/0/percent')
  ->status_is(200);

$t->get_ok('/api/v1/reports/osclassbandwidth/1000-01-01/9999-01-01' => json => {  })
  ->json_has('/items/0/accttotal')
  ->json_has('/items/0/accttotaloctets')
  ->json_has('/items/0/dhcp_fingerprint')
  ->json_has('/items/0/percent')
  ->status_is(200);

$t->get_ok('/api/v1/reports/osclassbandwidth/day' => json => {  })
  ->json_has('/items/0/accttotal')
  ->json_has('/items/0/accttotaloctets')
  ->json_has('/items/0/dhcp_fingerprint')
  ->json_has('/items/0/percent')
  ->status_is(200);

$t->get_ok('/api/v1/reports/osclassbandwidth/week' => json => {  })
  ->json_has('/items/0/accttotal')
  ->json_has('/items/0/accttotaloctets')
  ->json_has('/items/0/dhcp_fingerprint')
  ->json_has('/items/0/percent')
  ->status_is(200);

$t->get_ok('/api/v1/reports/osclassbandwidth/month' => json => {  })
  ->json_has('/items/0/accttotal')
  ->json_has('/items/0/accttotaloctets')
  ->json_has('/items/0/dhcp_fingerprint')
  ->json_has('/items/0/percent')
  ->status_is(200);

$t->get_ok('/api/v1/reports/osclassbandwidth/year' => json => {  })
  ->json_has('/items/0/accttotal')
  ->json_has('/items/0/accttotaloctets')
  ->json_has('/items/0/dhcp_fingerprint')
  ->json_has('/items/0/percent')
  ->status_is(200);

$t->get_ok('/api/v1/reports/nodebandwidth' => json => {  })
  ->json_has('/items/0/acctinput')
  ->json_has('/items/0/acctinputoctets')
  ->json_has('/items/0/acctoutput')
  ->json_has('/items/0/acctoutputoctets')
  ->json_has('/items/0/accttotal')
  ->json_has('/items/0/accttotaloctets')
  ->json_has('/items/0/callingstationid')
  ->json_has('/items/0/percent')
  ->status_is(200);

$t->get_ok('/api/v1/reports/topauthenticationfailures/mac/1000-01-01/9999-01-01' => json => {  })
  ->json_has('/items/0/mac')
  ->json_has('/items/0/count')
  ->json_has('/items/0/percent')
  ->json_has('/items/0/total')
  ->status_is(200);

$t->get_ok('/api/v1/reports/topauthenticationfailures/ssid/1000-01-01/9999-01-01' => json => {  })
  ->json_has('/items/0/ssid')
  ->json_has('/items/0/count')
  ->json_has('/items/0/percent')
  ->json_has('/items/0/total')
  ->status_is(200);

$t->get_ok('/api/v1/reports/topauthenticationfailures/username/1000-01-01/9999-01-01' => json => {  })
  ->json_has('/items/0/user_name')
  ->json_has('/items/0/count')
  ->json_has('/items/0/percent')
  ->json_has('/items/0/total')
  ->status_is(200);

$t->get_ok('/api/v1/reports/topauthenticationsuccesses/mac/1000-01-01/9999-01-01' => json => {  })
  ->json_has('/items/0/mac')
  ->json_has('/items/0/count')
  ->json_has('/items/0/percent')
  ->json_has('/items/0/total')
  ->status_is(200);

$t->get_ok('/api/v1/reports/topauthenticationsuccesses/ssid/1000-01-01/9999-01-01' => json => {  })
  ->json_has('/items/0/ssid')
  ->json_has('/items/0/count')
  ->json_has('/items/0/percent')
  ->json_has('/items/0/total')
  ->status_is(200);

$t->get_ok('/api/v1/reports/topauthenticationsuccesses/username/1000-01-01/9999-01-01' => json => {  })
  ->json_has('/items/0/user_name')
  ->json_has('/items/0/count')
  ->json_has('/items/0/percent')
  ->json_has('/items/0/total')
  ->status_is(200);

$t->get_ok('/api/v1/reports/topauthenticationsuccesses/computername/1000-01-01/9999-01-01' => json => {  })
  ->json_has('/items/0/computer_name')
  ->json_has('/items/0/count')
  ->json_has('/items/0/percent')
  ->json_has('/items/0/total')
  ->status_is(200);

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

