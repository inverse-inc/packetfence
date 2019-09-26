#!/usr/bin/perl

=head1 NAME

Config_AdminApiAuditLog

=head1 DESCRIPTION

unit test for Config_AdminApiAuditLog

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

use pf::ConfigStore::Firewall_SSO;
use Test::More tests => 4;
use Test::Mojo;
use JSON::MaybeXS;
use Utils;
use pf::dal::admin_api_audit_log;

my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::Firewall_SSO");

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');
my $test_id = "test_id_$$";
my $test_username = "USERNAME_$$";
my $collection_base_url = '/api/v1/config/firewalls';
my $base_url = '/api/v1/config/firewall';
my $password = "password";

$t->post_ok(
    $collection_base_url => { 'X-PacketFence-Username' => $test_username } =>
      json => {
        id       => $test_id,
        password => $password,
        username => "bob",
        type     => "JSONRPC"
      }
)->status_is(201);

my ($status, $iter) = pf::dal::admin_api_audit_log->search(
    -where => {
        user_name => $test_username,
    }, 
    -limit => 1,
    order_by => '-created_at',
);


my $log = $iter->next;
if (!defined ($log)) {
    BAIL_OUT("Cannot find log");
}

my $request = decode_json($log->{request});
isnt($request->{password}, $password, "Password not saved");

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

1;
