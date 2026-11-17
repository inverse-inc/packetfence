#!/usr/bin/perl

=head1 NAME

server_downloadable_acl

=head1 DESCRIPTION

A downloadable ACL defined by a RADIUS server (Cisco ISE or ACS,
#ACSACL#-IP-<name>-<version>) goes through the RADIUS filters, which can proxy
it to that server, and the answer of the server is sent as is. A downloadable
ACL of PacketFence is still answered by the switch module.

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

use Test::More tests => 12;
use pf::radius;
use pf::radius::constants;
use pf::SwitchFactory;
use pf::Switch::Cisco::Cisco_IOS_15_5;
use pf::access_filter::radius;
use Test::NoWarnings;

my (@advanced, @filter_tests);
{
    no warnings qw(redefine once);
    *pf::SwitchFactory::instantiate = sub {
        return pf::Switch::Cisco::Cisco_IOS_15_5->new({ id => '192.0.2.24', ip => '192.0.2.24' });
    };
    *pf::radius::advancedAccess = sub {
        my ($self, $args) = @_;
        push @advanced, $args->{user_name};
        return [ $RADIUS::RLM_MODULE_OK, 'control:Proxy-To-Realm' => 'LOCAL' ];
    };
    *pf::access_filter::radius::test = sub {
        my ($self, $scope, $args) = @_;
        push @filter_tests, $args->{user_name};
        return { _rule => 'proxy_dacl' };
    };
    *pf::access_filter::radius::handleAnswerInRule = sub {
        return ({ 'control:Proxy-To-Realm' => 'ise.lab' }, $RADIUS::RLM_MODULE_UPDATED);
    };
}

ok(pf::radius::is_server_downloadable_acl('#ACSACL#-IP-PERMIT_ALL-5f7e1a0b'), 'IPv4 downloadable ACL of a RADIUS server');
ok(pf::radius::is_server_downloadable_acl('#ACSACL#-IPV6-PERMIT_ALL-5f7e1a0b'), 'IPv6 downloadable ACL of a RADIUS server');
ok(!pf::radius::is_server_downloadable_acl('#ACSACL#guest-1a2b3c'), 'downloadable ACL of PacketFence (role-session)');
ok(!pf::radius::is_server_downloadable_acl(undef), 'no User-Name');

sub acl_download {
    my ($user_name) = @_;
    return {
        'NAS-IP-Address' => '192.0.2.24',
        'User-Name'      => $user_name,
        'Cisco-AVPair'   => [ 'aaa:service=ip_admission', 'aaa:event=acl-download' ],
    };
}

my $radius = pf::radius->new;

@advanced = (); @filter_tests = ();
my $reply = $radius->radius_filter('packetfence.authorize', acl_download('#ACSACL#-IP-PERMIT_ALL-5f7e1a0b'));
is_deeply(\@filter_tests, ['#ACSACL#-IP-PERMIT_ALL-5f7e1a0b'], 'authorize: the filters are tested for a downloadable ACL of a RADIUS server');
is({ @{$reply}[1 .. $#$reply] }->{'control:Proxy-To-Realm'}, 'ise.lab', 'authorize: the answer of the matching filter is used');
is(scalar @advanced, 0, 'authorize: the switch module does not answer it');

@advanced = (); @filter_tests = ();
$reply = $radius->radius_filter('packetfence.authorize', acl_download('guest-1a2b3c'));
is(scalar @filter_tests, 0, 'authorize: the filters are not tested for a downloadable ACL of PacketFence');
is_deeply(\@advanced, ['guest-1a2b3c'], 'authorize: the switch module answers it');

@advanced = ();
$reply = $radius->switch_access(acl_download('#ACSACL#-IP-PERMIT_ALL-5f7e1a0b'));
is_deeply($reply, [ $RADIUS::RLM_MODULE_OK ], 'post-auth: the answer of the RADIUS server is sent as is');

@advanced = ();
$radius->switch_access(acl_download('guest-1a2b3c'));
is_deeply(\@advanced, ['guest-1a2b3c'], 'post-auth: the switch module answers a downloadable ACL of PacketFence');

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
