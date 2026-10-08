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

use Test::More tests => 14;
use pf::factory::task;
use pf::task::api;

#This test will running last
use Test::NoWarnings;

ok(pf::factory::task->isValidType('api'), "api is a valid task type");
ok(pf::factory::task->isValidType('pfsnmp'), "pfsnmp is a valid task type");
ok(!pf::factory::task->isValidType('api::foo'), "nested package is not a valid task type");
ok(!pf::factory::task->isValidType('notatask'), "unknown task type is not valid");
ok(!pf::factory::task->isValidType(undef), "undef is not a valid task type");
ok(!pf::factory::task->isValidType(['api']), "reference is not a valid task type");

my $task = pf::task::api->new;
ok($task->isAllowedMethod('send_email'), "Queue method is allowed");
ok($task->isAllowedMethod('trigger_security_event'), "Public method is allowed");
ok($task->isAllowedMethod('cache_user_ntlm'), "queued ntlm cache method is allowed");
ok(!$task->isAllowedMethod('rebless_switch'), "untagged method is refused");
ok(!$task->isAllowedMethod('distant_download_configfile'), "denied method is refused");
ok(!$task->isAllowedMethod('copy_directory'), "denied method is refused");

my ($err) = $task->doTask(['notify_configfile_changed', conf_file => '/tmp/x', server => '127.0.0.1']);
is($err->{status}, 403, "doTask refuses a denied method");

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
