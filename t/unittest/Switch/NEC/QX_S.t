#!/usr/bin/perl

=head1 NAME

QX_S

=cut

=head1 DESCRIPTION

unit test for pf::Switch::NEC::QX_S

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 6;
use pf::constants;
use pf::config qw($WIRED_802_1X $WIRED_MAC_AUTH);
use pf::Switch::constants;
use pf::Switch::NEC::QX_S;

#This test will running last
use Test::NoWarnings;

my $switch = pf::Switch::NEC::QX_S->new({ id => 'test', ip => '1.1.1.1', SNMPUseConnector => "N", radiusDeauthUseConnector => "N" });

# wiredeauthTechniques: RADIUS deauthentication resolves to a real method

for my $type ([$WIRED_MAC_AUTH, 'MAC authentication'], [$WIRED_802_1X, '802.1X']) {
    my ($method, $sub) = $switch->wiredeauthTechniques($SNMP::RADIUS, $type->[0]);
    is($sub, 'deauthenticateMacRadius', "$type->[1] deauthenticates with a RADIUS Disconnect-Request");
}

ok($switch->can('deauthenticateMacRadius'), "the deauthentication method is implemented");

# deauthenticateMacRadius: the Disconnect-Request is sent for the endpoint MAC

{
    my @disconnect;
    no warnings qw(redefine once);
    local *pf::Switch::NEC::QX_S::radiusDisconnect = sub { my ($self, @args) = @_; @disconnect = @args; return 1 };
    ok($switch->deauthenticateMacRadius(1, '02:4e:45:43:44:01'), "deauthentication reports the Disconnect-Request result");
    is_deeply(\@disconnect, ['02:4e:45:43:44:01'], "the Disconnect-Request is for the endpoint MAC");
}

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
