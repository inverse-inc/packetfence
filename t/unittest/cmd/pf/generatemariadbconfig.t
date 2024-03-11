#!/usr/bin/perl

=head1 NAME

generatemariadbconfig

=head1 DESCRIPTION

unit test for generatemariadbconfig

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 2;

#This test will running last
use Test::NoWarnings;
use pf::cmd::pf::generatemariadbconfig;
use pf::constants::eventLogger;

is_deeply(
    pf::cmd::pf::generatemariadbconfig::make_init_file_vars(),
    {
        db => 'pf_smoke_test',
        pf_logger => 1,
        namespaces => [
            {
                name => "admin_api_audit_log",
                trigger => 'CREATE DEFINER=`root`@`localhost` TRIGGER log_event_admin_api_audit_log AFTER INSERT ON `admin_api_audit_log` FOR EACH ROW BEGIN SET @k = pf_logger( "admin_api_audit_log", "created_at", NEW.created_at, "user_name", NEW.user_name, "action", NEW.action, "object_id", NEW.object_id, "url", NEW.url, "method", NEW.method, "request", NEW.request, "status", NEW.status); END;',
            },
            {
                name => "auth_log",
                trigger => 'CREATE DEFINER=`root`@`localhost` TRIGGER log_event_auth_log AFTER INSERT ON `auth_log` FOR EACH ROW BEGIN SET @k = pf_logger( "auth_log", "process_name", NEW.process_name, "mac", NEW.mac, "pid", NEW.pid, "status", NEW.status, "attempted_at", NEW.attempted_at, "completed_at", NEW.completed_at, "source", NEW.source, "profile", NEW.profile); END;',
            },
            {
                name => "dhcp_option82",
                trigger => undef,
            },
            {
               name => "dns_audit_log",
                trigger => undef,
            },
            {
                name => "radius_audit_log",
                trigger => undef,
            },
        ],
    },
);

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

