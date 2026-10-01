#!/usr/bin/perl -w

=head1 NAME

services.t

=head1 DESCRIPTION

Exercizing pf::services and sub modules components.

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 15;
use Log::Log4perl;
use File::Basename qw(basename);

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

subtest 'boot target promotion' => sub {
    my @cases = (
        { name => 'installer keeps base target', configurator => 'enabled', skip => 1 },
        { name => 'CLI promotes configured standalone', target => 'packetfence.target' },
        { name => 'CLI accepts disabled aliases', configurator => 'no', target => 'packetfence.target' },
        { name => 'wizard promotes before disabling configurator', configurator => 'enabled', finishing => 1, target => 'packetfence.target' },
        { name => 'CLI promotes configured cluster', cluster => 1, target => 'packetfence-cluster.target' },
        { name => 'wizard selects cluster target', configurator => 'enabled', finishing => 1, cluster => 1, target => 'packetfence-cluster.target' },
        { name => 'preserve standalone target', default => 'packetfence.target' },
        { name => 'preserve cluster target', default => 'packetfence-cluster.target' },
        { name => 'preserve administrator target', default => 'multi-user.target' },
        { name => 'report get-default failure', get_status => 256, error => qr/Unable to read/ },
        { name => 'reject missing get-default output', empty_output => 1, error => qr/Unable to read/ },
        { name => 'report set-default failure', target => 'packetfence.target', set_status => 256, error => qr/Unable to set/ },
    );
    for my $case (@cases) {
        subtest $case->{name} => sub {
            my %config = (advanced => { configurator => $case->{configurator} // 'disabled' });
            my $cluster = $case->{cluster} // 0;
            my @commands;
            no warnings qw(redefine once);
            local *pf::services::Config = \%config;
            local *pf::services::cluster_enabled = \$cluster;
            local *pf::services::safe_pf_run = sub {
                my $options = pop @_;
                push @commands, [@_];
                if ($_[1] eq 'get-default') {
                    ${$options->{status_ref}} = $case->{get_status} // 0;
                    return if $case->{get_status} || $case->{empty_output};
                    return ($case->{default} // 'packetfence-base.target') . "\n";
                }
                ${$options->{status_ref}} = $case->{set_status} // 0;
                return; # Successful set-default need not produce stdout.
            };

            my $result = eval {
                pf::services::promote_default_systemd_target(configurator_finishing => $case->{finishing});
            };
            my $error = $@;
            if ($case->{error}) {
                like($error, $case->{error}, 'command failure reaches caller');
            } else {
                is($error, '', 'no error');
                ok($result, 'promotion or deliberate no-op succeeds');
            }
            my @expected;
            push @expected, ['systemctl', 'get-default'] unless $case->{skip};
            push @expected, ['sudo', 'systemctl', 'set-default', $case->{target}] if $case->{target};
            is_deeply(\@commands, \@expected, 'only the intended boot target is changed');
        };
    }
};

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

