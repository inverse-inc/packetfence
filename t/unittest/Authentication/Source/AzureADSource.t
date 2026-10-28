#!/usr/bin/perl

=head1 NAME

AzureADSource

=head1 DESCRIPTION

unit test for pf::Authentication::Source::AzureADSource::get_memberOf:
Graph pages memberOf results, the lookup must follow @odata.nextLink and
never return a partial list

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
use Test::NoWarnings;
use Test::MockModule;
use HTTP::Response;
use JSON::MaybeXS qw(encode_json);

use pf::Authentication::Source::AzureADSource;

my $source = pf::Authentication::Source::AzureADSource->new({
    id            => 'AzureADPagination',
    client_id     => 'client-id',
    client_secret => 'client-secret',
    tenant_id     => 'tenant-id',
});

# Never talk to login.microsoftonline.com or touch the shared token cache
my $src_mock = Test::MockModule->new('pf::Authentication::Source::AzureADSource');
$src_mock->mock(get_admin_token => sub { 'admin-token' });
$src_mock->mock(cache => sub { FakeCache->new });

# Script the Graph responses: each get() consumes the next response
my (@calls, @script);
my $lwp = Test::MockModule->new('LWP::UserAgent');
$lwp->mock(get => sub {
    my ($ua, $url) = @_;
    push @calls, $url;
    my $r = shift @script;
    die "unexpected Graph call for $url" unless $r;
    return $r;
});

sub json_response {
    my ($data) = @_;
    my $r = HTTP::Response->new(200, 'OK', [ 'Content-Type' => 'application/json' ], encode_json($data));
    return $r;
}

sub page1 {
    return json_response({
        value => [ { id => 'g1', displayName => 'Group One' }, { id => 'r1' } ],
        '@odata.nextLink' => 'https://graph.microsoft.com/v1.0/users/u/memberOf?$skiptoken=page2',
    });
}

sub page2 {
    return json_response({
        value => [ { id => 'g2', displayName => 'App_Azure_PacketFenceSAML_Admins' } ],
    });
}

sub lookup {
    @calls = ();
    @script = @_;
    return [ $source->get_memberOf('user@example.com') ];
}

# 1. Both pages are fetched and merged; entries without a displayName are skipped
{
    my $groups = lookup(page1(), page2());
    is_deeply($groups, [ 'Group One', 'App_Azure_PacketFenceSAML_Admins' ], "groups from every page are returned, nameless entries skipped");
    is(scalar @calls, 2, "one request per page");
    like($calls[0], qr/\$top=999/, "the first request asks for the largest page");
    is($calls[1], 'https://graph.microsoft.com/v1.0/users/u/memberOf?$skiptoken=page2', "the nextLink is followed as-is");
}

# 2. A failure after the first page returns nothing, not a partial list
{
    my $groups = lookup(page1(), HTTP::Response->new(429, 'Too Many Requests'));
    is_deeply($groups, [], "a throttled second page returns an empty list");
    is(scalar @calls, 2, "no further request after the failure");
}

# 3. A 401 on a later page refreshes the token and restarts from the first page
{
    my $groups = lookup(page1(), HTTP::Response->new(401, 'Unauthorized'), page1(), page2());
    is_deeply($groups, [ 'Group One', 'App_Azure_PacketFenceSAML_Admins' ], "the lookup is retried from the first page after a 401");
    is(scalar @calls, 4, "two pages, a 401, then two pages again");
}

# 4. The retry happens only once
{
    my $groups = lookup(HTTP::Response->new(401, 'Unauthorized'), HTTP::Response->new(401, 'Unauthorized'));
    is_deeply($groups, [], "two 401s in a row return an empty list");
    is(scalar @calls, 2, "the admin token is refreshed once, not in a loop");
}

# 5. A malformed body is a failure, not a crash
{
    my $groups = lookup(HTTP::Response->new(200, 'OK', [ 'Content-Type' => 'text/html' ], '<html>'));
    is_deeply($groups, [], "a non-JSON body returns an empty list");
}

# 6. The page cap stops a lookup that never ends
{
    local $pf::Authentication::Source::AzureADSource::MAX_MEMBEROF_PAGES = 2;
    my $groups = lookup(page1(), page1(), page1());
    is_deeply($groups, [], "exceeding the page cap returns an empty list");
    is(scalar @calls, 2, "no request is made past the page cap");
}

package FakeCache;
sub new { bless {}, shift }
sub remove { }
sub compute { my ($self, $key, $opts, $cb) = @_; return $cb->() }

package main;

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
