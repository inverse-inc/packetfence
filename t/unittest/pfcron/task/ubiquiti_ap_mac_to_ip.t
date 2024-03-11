#!/usr/bin/perl

=head1 NAME

ubiquiti_ap_mac_to_ip

=head1 DESCRIPTION

unit test for ubiquiti_ap_mac_to_ip

=cut

use strict;
use warnings;

our %macIp;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
    %macIp = (
        '47:11:f7:d7:d6:a1' => '1.2.3.4',
        '47:11:f7:d7:d6:a2' => '1.2.3.4',
        '47:11:f7:d7:d6:a3' => '1.2.3.4',
        '47:11:f7:d7:d6:a4' => '1.2.3.4',
        '47:11:f7:d7:d6:a5' => '1.2.3.4',
        '47:11:f7:d7:d6:a6' => '1.2.3.5',
        '47:11:f7:d7:d6:a7' => '1.2.3.5',
        '47:11:f7:d7:d6:a8' => '1.2.3.5',
        '47:11:f7:d7:d6:a9' => '1.2.3.5',
        '47:11:f7:d7:d6:aa' => '1.2.3.5',
    );
}

use Test::More tests => 2 + (scalar keys %macIp) * 2;

#This test will running last
use Test::NoWarnings;
use pf::pfcron::task::ubiquiti_ap_mac_to_ip;
use pf::Switch::Ubiquiti::Unifi;
use Symbol 'gensym';
use IPC::Open3;
use pf::defer;
use pf::SwitchFactory;

my $child_err = gensym;
my $pid = open3(my $chld_out, my $chld_in, $child_err, "/usr/local/pf/t/mock_servers/ubiquiti_ap_mac_to_ip.pl", "daemon", "-l", "http://127.0.0.1:8443");
sleep(1);
my $defer = pf::defer::defer(
    sub {
        kill( 'INT', $pid );
        waitpid( $pid, 0 );
    }
);


my $switch = pf::SwitchFactory->instantiate('172.16.8.32');
ok($switch, 'Switch created');
for my $m (keys %macIp) {
    is( $switch->getAccessPointMACIP($m), 0, "Mac $m is not defined");
}

my $task = pf::pfcron::task::ubiquiti_ap_mac_to_ip->new(
     {
         status   => "enabled",
         id       => 'test',
         interval  => 0,
         type     => 'ubiquiti_ap_mac_to_ip',
     }
 );

$task->run();

while( my ($m, $ip) = each %macIp) {
    is(
        $switch->getAccessPointMACIP($m),
        $ip,
        "Mac $m ip is $ip",
    )
}

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

1;

