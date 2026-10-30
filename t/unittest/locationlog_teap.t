#!/usr/bin/perl

=head1 NAME

locationlog_teap

=cut

=head1 DESCRIPTION

unit test for the TEAP identities carried by the locationlog

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 7;
use Utils;
use pf::constants::config qw($WIRELESS_802_1X $WIRELESS_MAC_AUTH);
use pf::locationlog qw(locationlog_synchronize locationlog_view_open_mac);
use pf::node qw(node_modify);

#This test will running last
use Test::NoWarnings;

my $mac = Utils::test_mac();
node_modify($mac);

sub sync {
    my ($connection_type, $user_name, $role, $teap_username, $teap_machinename) = @_;
    locationlog_synchronize(
        "192.168.0.1", "192.168.0.1", "00:22:33:44:55:66", "12", "12", $mac,
        "no", $connection_type, "", $user_name, "SSID", $user_name, "NULL",
        $role, "", "192.168.0.1", 0, $teap_username, $teap_machinename,
    );
    return locationlog_view_open_mac($mac);
}

my $row = sync($WIRELESS_802_1X, 'alice', 'default', 'alice', 'host/pc1');
is($row->{teap_username}, 'alice', "TEAP user name recorded");

# Re-insert caused by a role change by a caller that does not carry the TEAP attributes
$row = sync($WIRELESS_802_1X, 'alice', 'guest', undef, undef);
is($row->{role}, 'guest', "new row for the role change");
is($row->{teap_username}, 'alice', "TEAP user name kept for the same session");
is($row->{teap_machinename}, 'host/pc1', "TEAP machine name kept for the same session");

# Another user authenticates without TEAP
$row = sync($WIRELESS_802_1X, 'bob', 'guest', '', '');
is($row->{teap_username}, '', "TEAP user name cleared for another user");

# MAB on the same device
sync($WIRELESS_802_1X, 'alice', 'default', 'alice', 'host/pc1');
$row = sync($WIRELESS_MAC_AUTH, $mac, 'default', '', '');
is($row->{teap_machinename}, '', "TEAP machine name cleared for MAB");

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
