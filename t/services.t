#!/usr/bin/perl -w

=head1 NAME

services.t

=head1 DESCRIPTION

Exercizing pf::services and sub modules components.

=cut

use strict;
use warnings;

use Test::More tests => 14;
use Log::Log4perl;
use File::Basename qw(basename);
use lib '/usr/local/pf/lib';

Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

BEGIN { use lib qw(/usr/local/pf/t); }
BEGIN { use setup_test_config; }
BEGIN { use_ok('pf::services') }
BEGIN { use_ok('pf::services::manager::httpd') }
BEGIN { use_ok('pf::services::manager::pfdhcp') }
BEGIN { use_ok('pf::services::manager::snmptrapd') }

use pf::constants;
use pf::config;

=head1 CONFIGURATION VALIDATION

=head2 pf::services::manager::httpd

=cut

# performance config tests for a couple of RAM values
my $max_clients = pf::services::manager::httpd::calculate_max_clients(2048 * 1024);
ok(10 < $max_clients && $max_clients < 30, "MaxClients for 2Gb RAM");

$max_clients = pf::services::manager::httpd::calculate_max_clients(4096 * 1024);
ok(40 < $max_clients && $max_clients < 60, "MaxClients for 4Gb RAM");

$max_clients = pf::services::manager::httpd::calculate_max_clients(8192 * 1024);
ok(100 < $max_clients && $max_clients < 120, "MaxClients for 8Gb RAM");

$max_clients = pf::services::manager::httpd::calculate_max_clients(16384 * 1024);
ok(200 < $max_clients && $max_clients < 250, "MaxClients for 16Gb RAM");

$max_clients = pf::services::manager::httpd::calculate_max_clients(24576 * 1024);
ok(250 < $max_clients && $max_clients < 513, "MaxClients for 24Gb RAM");


=head2 pf::services::manager::snmptrapd

=cut


# This tests proper config creation and also covers regression test #1354
my ($snmpv3_users, $snmp_communities) = pf::services::manager::snmptrapd::_fetch_trap_users_and_communities();
is_deeply(
    [ $snmpv3_users, $snmp_communities ],
    [
        {
            "0123456 readUser" => '-e 0123456 readUser MD5 authpwdread DES privpwdread',
            "6543210 readUser" => '-e 6543210 readUser MD5 authpwdread DES privpwdread'
        },
        { 'trapCommunity' => $TRUE, 'public' => $TRUE },
    ],
    "snmptrapd configuration file generation"
);

my @engine_ids = ("0123456", "6543210");
foreach my $user_key (sort keys %$snmpv3_users) {
    my ($engine_id, $username) = split(/ /, $user_key);
    is($engine_id, shift(@engine_ids), "Engine ID parsed correctly");
    is($username, "readUser", "Username parsed correctly");
}

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

