#!/usr/bin/perl

=head1 NAME

Authentication

=head1 DESCRIPTION

unit test for Authentication

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

use Test::More tests => 4;

#This test will running last
use Test::NoWarnings;
use Test::Mojo;
use JSON::MaybeXS;
use pf::dal::admin_api_audit_log;

my $t = Test::Mojo->new('pf::UnifiedApi');
my ($status, $rows) = pf::dal::admin_api_audit_log->remove_items(
    -where => {
        action => 'api.v1.Authentication.adminAuthentication',
    }, 
);

$t->post_ok( "/api/v1/authentication/admin_authentication" => json =>
      { username => 'authtest', password => 'authtest' } )->status_is(200);

($status, my $iter) = pf::dal::admin_api_audit_log->search(
    -where => {
        action => 'api.v1.Authentication.adminAuthentication',
    }, 
    -limit => 1,
    order_by => '-created_at',
);

my $log = $iter->next;
if (!defined ($log)) {
    BAIL_OUT("Cannot find log");
}

my $request = decode_json($log->{request});
isnt($request->{password}, 'authtest', "Password not saved");

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

