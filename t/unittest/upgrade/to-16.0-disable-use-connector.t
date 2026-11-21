#!/usr/bin/perl

=head1 NAME

to-16.0-disable-use-connector

=head1 DESCRIPTION

unit test for addons/upgrade/to-16.0-disable-use-connector.pl

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}
use pf::file_paths qw($install_dir);
use pf::IniFiles;
require "$install_dir/addons/upgrade/to-16.0-disable-use-connector.pl";
use Test::More tests => 25;

#This test will running last
use Test::NoWarnings;

my $data_dir = "$install_dir/t/data/disable-use-connector";

sub load_ini {
    my ($file) = @_;
    return pf::IniFiles->new(-file => "$data_dir/$file", -allowempty => 1);
}

sub silently {
    my ($sub, $ini) = @_;
    open(my $out, '>', \my $output);
    my $old = select($out);
    my $updated = $sub->($ini);
    select($old);
    return $updated;
}

my $ini = load_ini('switches.conf');
is(silently(\&disable_switches_use_connector, $ini), 4, "the enabled parameters of the switches are disabled");
is($ini->val('default', 'SNMPUseConnector'), 'N', "SNMPUseConnector is disabled in the default switch");
is($ini->val('default', 'radiusDeauthUseConnector'), 'N', "radiusDeauthUseConnector is disabled in the default switch");
is($ini->val('192.0.2.1', 'SNMPUseConnector'), 'N', "SNMPUseConnector is disabled in a switch that enabled it");
is($ini->val('192.0.2.1', 'radiusDeauthUseConnector'), 'N', "a disabled radiusDeauthUseConnector keeps its value");
is($ini->val('192.0.2.2', 'SNMPUseConnector'), 'N', "a disabled SNMPUseConnector keeps its value");
ok(
    !$ini->exists('192.0.2.3', 'SNMPUseConnector') && !$ini->exists('192.0.2.3', 'radiusDeauthUseConnector'),
    "a switch inheriting the parameters is not changed",
);
is($ini->val('group example', 'radiusDeauthUseConnector'), 'N', "radiusDeauthUseConnector is disabled in a switch group that enabled it");
ok(!$ini->exists('group example', 'SNMPUseConnector'), "a switch group inheriting SNMPUseConnector is not changed");
is(silently(\&disable_switches_use_connector, $ini), 0, "running it again on the switches changes nothing");

$ini = load_ini('authentication.conf');
is(silently(\&disable_sources_use_connector, $ini), 4, "the sources using the connector are disabled");
is($ini->val('ldap_default', 'use_connector'), 0, "an LDAP source without use_connector doesn't use the connector");
is($ini->val('ad_enabled', 'use_connector'), 0, "use_connector is disabled in an Active Directory source that enabled it");
is($ini->val('edir_disabled', 'use_connector'), 0, "a disabled use_connector keeps its value");
is($ini->val('google_ldap', 'use_connector'), 0, "a Google Workspace LDAP source without use_connector doesn't use the connector");
is($ini->val('radius_enabled', 'use_connector'), 0, "use_connector is disabled in a RADIUS source that enabled it");
ok(!$ini->exists('ad_enabled rule catchall', 'use_connector'), "the rules of the sources are not changed");
ok(!$ini->exists('sql', 'use_connector'), "the other sources are not changed");
is(silently(\&disable_sources_use_connector, $ini), 0, "running it again on the sources changes nothing");

$ini = load_ini('firewall_sso.conf');
is(silently(\&disable_firewalls_use_connector, $ini), 1, "the firewalls using the connector are disabled");
is($ini->val('192.0.2.20', 'use_connector'), 0, "use_connector is disabled in a firewall that enabled it");
is($ini->val('192.0.2.21', 'use_connector'), 0, "a disabled use_connector keeps its value");
ok(!$ini->exists('192.0.2.22', 'use_connector'), "a firewall without use_connector is not changed");
is(silently(\&disable_firewalls_use_connector, $ini), 0, "running it again on the firewalls changes nothing");

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
