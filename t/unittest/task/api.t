#!/usr/bin/perl

=head1 NAME

unittest/task/api.t

=head1 DESCRIPTION

unit test for pf::task::api and pf::factory::task type validation

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 20;
use pf::factory::task;
use pf::task::api;
use pf::api::queue;

#This test will running last
use Test::NoWarnings;

ok(pf::factory::task->isValidType('api'), "api is a valid task type");
ok(pf::factory::task->isValidType('pfsnmp'), "pfsnmp is a valid task type");
ok(!pf::factory::task->isValidType('api::foo'), "nested package is not a valid task type");
ok(!pf::factory::task->isValidType('notatask'), "unknown task type is not valid");
ok(!pf::factory::task->isValidType(undef), "undef is not a valid task type");
ok(!pf::factory::task->isValidType(['api']), "reference is not a valid task type");

ok(pf::api->isAllowedInQueue('send_email'), "Queue method is allowed");
ok(pf::api->isAllowedInQueue('trigger_security_event'), "AllowedAsAction method is allowed");
ok(pf::api->isAllowedInQueue('process_dhcpv4'), "queued dhcp method is allowed");
ok(!pf::api->isAllowedInQueue('echo'), "Public method not tagged for the queue is refused");
ok(pf::api->isAllowedInQueue('cache_user_ntlm'), "queued ntlm cache method is allowed");
ok(!pf::api->isAllowedInQueue('rebless_switch'), "untagged method is refused");
ok(!pf::api->isAllowedInQueue('distant_download_configfile'), "NoQueue method is refused");
ok(!pf::api->isAllowedInQueue('copy_directory'), "NoQueue method is refused");
ok(pf::api->isAllowedInQueue('fingerbank_process'), "method queued by the captive portal is allowed");

my $task = pf::task::api->new;

my ($err) = $task->doTask(['notify_configfile_changed', conf_file => '/tmp/x', server => '127.0.0.1']);
is($err->{status}, 403, "doTask refuses a NoQueue method");

{
    package queue::client::test;
    sub new { bless { submitted => [] }, shift }
    sub submit { my ($self, @args) = @_; push @{$self->{submitted}}, \@args }
    sub submit_delayed { my ($self, @args) = @_; push @{$self->{submitted}}, \@args }
}

my $queue_client = queue::client::test->new;
my $queue = pf::api::queue->new(client => $queue_client);
$queue->notify('fingerbank_process', '00:11:22:33:44:55');
is(scalar @{$queue_client->{submitted}}, 1, "notify submits a Queue method");
ok(!eval { $queue->notify('echo'); 1 }, "notify refuses a method not allowed in the queue");
ok(!eval { $queue->notify_delayed(10, 'copy_directory'); 1 }, "notify_delayed refuses a NoQueue method");

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
