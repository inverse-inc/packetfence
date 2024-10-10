#!/usr/bin/perl -w
use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use JSON;
use pf::constants qw($TRUE $FALSE);
use Test::More tests => 11;
use pf::config qw(%Config);
use Test::NoWarnings;

# we set dummy values in pfconfig-test so it can pass the parameter validation.
$Config{fleetdm}->{host} = 'https://dummy.org';
$Config{fleetdm}->{token} = 'TEST_TOKEN==';

my $mock_policy = '{
    "timestamp": "2024-05-27T20:27:40.274362577Z",
    "policy": {
        "id": 12,
        "name": "test_policy_regex__",
        "query": "SELECT (total_seconds / 86400) AS uptime_in_days FROM uptime WHERE uptime_in_days \u003c 5;",
        "critical": false,
        "description": "aaa",
        "author_id": 1,
        "author_name": "admin",
        "author_email": "stgmsa@gmail.com",
        "team_id": null,
        "resolution": "aaa",
        "platform": "darwin,windows,linux",
        "calendar_events_enabled": false,
        "created_at": "2024-05-27T20:27:07Z",
        "updated_at": "2024-05-27T20:27:07Z",
        "passing_host_count": 0,
        "failing_host_count": 0,
        "host_count_updated_at": null
    },
    "hosts": [
        {
            "id": 3,
            "hostname": "localhost",
            "display_name": "",
            "url": "https://fleet.example.com/hosts/1"
        }
    ]
}';

my $mock_cve = '{
  "timestamp": "0000-00-00T00:00:00Z",
  "vulnerability": {
    "cve": "CVE-2014-9471",
    "details_link": "https://nvd.nist.gov/vuln/detail/CVE-2014-9471",
    "cve_published": "2014-10-10T00:00:00Z",
    "cvss_score" : 9,
    "hosts_affected": [
      {
        "id": 1,
        "display_name": "macbook-1",
        "url": "https://fleet.example.com/hosts/1",
        "software_installed_paths": [
          "/usr/lib/some-path"
        ]
      },
      {
        "id": 3,
        "display_name": "macbook-2",
        "url": "https://fleet.example.com/hosts/2"
      }
    ]
  }
}';

use pf::CHI;
our $cache = pf::CHI->new(namespace => 'fleetdm');
$cache->clear();

# set up FleetDM host_id <-> mac association in order to bypass a FleetDM API call.
$cache->set('fleetdm_host_id:1', '00:0c:29:73:09:5f');
$cache->set('fleetdm_host_id:2', '00:0C:29:E0:46:07');
$cache->set('fleetdm_host_id:3', 'A0:99:9B:0F:EE:FB');

use_ok('pf::task::fleetdm');

is(pf::task::fleetdm::refreshToken(), 0, 'refresh token');

is(pf::task::fleetdm::cachedGetHostMac(4), '', 'cached get host mac');
is(pf::task::fleetdm::cachedGetHostMac(1), '00:0c:29:73:09:5f', 'cached get host mac');

my $mock_policy_json = decode_json($mock_policy);
my $mock_cve_json = decode_json($mock_cve);

my $TRIGGERED_EVENT_COUNT_ONE = 1;
my $TRIGGERED_EVENT_COUNT_FOUR = 4;

is(pf::task::fleetdm::triggerPolicy('A0:99:9B:0F:EE:FB', 'fleetdm_policy', $mock_policy_json->{policy}->{name}, $mock_policy), 1, 'trigger policy violation');
is(pf::task::fleetdm::triggerPolicy('A0:99:9B:0F:EE:FB', 'fleetdm_cve', $mock_cve_json->{vulnerability}->{cve}, $mock_cve), 1, 'trigger CVE');

is(pf::task::fleetdm::handlePolicy($mock_policy), $TRIGGERED_EVENT_COUNT_ONE, 'handle policy');
is(pf::task::fleetdm::handleCVE($mock_cve), $TRIGGERED_EVENT_COUNT_FOUR, 'handle CVE');

my $taskPolicy = {
    'type'    => 'fleetdm_policy',
    'payload' => $mock_policy
};

my $taskCVE = {
    'type'    => 'fleetdm_cve',
    'payload' => $mock_cve
};

my $RETURN_CODE_SUCCESSFUL = 0;
my $RETURN_CODE_UNSUCCESSFUL = 1;
is(pf::task::fleetdm::doTask("fleetdm_policy", $taskPolicy), $RETURN_CODE_SUCCESSFUL, 'doTask - fleetdm policy');
is(pf::task::fleetdm::doTask("fleetdm_cve", $taskCVE), $RETURN_CODE_SUCCESSFUL, 'doTask - fleetdm cve');


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

