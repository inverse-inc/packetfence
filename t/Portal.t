#!/usr/bin/perl
=head1 NAME

Portal.t

=head1 DESCRIPTION

Tests for our pf::Portal... and friends modules.

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use File::Basename qw(basename);
use Test::More tests => 8;
use Test::NoWarnings;
use Test::MockObject::Extends;

Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

BEGIN {
    use_ok('pf::Connection::ProfileFactory');
    use_ok('pf::Portal::Session');
}

use pf::config qw($management_network);
use pf::util;

=head1 SETUP

Creating stub portalSession for tests with a mockable CGI component.

=cut

my $portalSession = pf::Portal::Session->new('testing' => 1);
my $mocked_cgi = Test::MockObject::Extends->new( CGI->new );
$portalSession->{'_cgi'} = $mocked_cgi;

=head1 SETUP

=head1 TESTS

=head2 Portal::ProfileFactory

=head2 valid type

=cut

isa_ok($portalSession, "pf::Portal::Session");
can_ok($portalSession, qw(_resolveIp cgi stash));

=head2 _resolveIp

=cut

my $remote_ip = '192.168.1.1';
# emulate the source IP
$mocked_cgi->mock('remote_addr', sub { return ($remote_ip); });
is($portalSession->_resolveIp(), $remote_ip, 'fetch a conventional remote IP');

# emulate a loopback source
$mocked_cgi->mock('remote_addr', sub { return ($pf::Portal::Session::LOOPBACK_IPV4); });
$ENV{'HTTP_X_FORWARDED_FOR'} = $remote_ip;
is($portalSession->_resolveIp(), $remote_ip, 'fetch IP through HTTP_X_FORWARDED_FOR for loopback source');

# emulate a virtual IP source
my $fake_virtual_ip = '10.10.10.100';
$management_network->tag("vip", $fake_virtual_ip);
$mocked_cgi->mock('remote_addr', sub { return ($fake_virtual_ip); });
$ENV{'HTTP_X_FORWARDED_FOR'} = $remote_ip;
is($portalSession->_resolveIp(), $remote_ip, 'fetch IP through HTTP_X_FORWARDED_FOR for virtual IP source');

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

