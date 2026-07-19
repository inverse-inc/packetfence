#!/usr/bin/perl

=head1 NAME

generic_http

=cut

=head1 DESCRIPTION

unit tests for pf::provisioner::generic_http

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 32;
use Test::NoWarnings;
use Test::MockModule;
use HTTP::Response;

use pf::constants;
# Do not `use pf::provisioner;` here: loading the base class before the
# subclass prevents Moo from inheriting the base attribute defaults
# (access_filter, ...) in the subclass constructor.

our $TEST_MAC = 'aa:bb:cc:dd:ee:ff';
our $TEST_NODE_INFO = { category => 'gaming', pid => 'bob' };

use_ok("pf::provisioner::generic_http");

sub make_provisioner {
    my (%args) = @_;
    return pf::provisioner::generic_http->new({
        id       => 'test_generic_http',
        type     => 'generic_http',
        url      => 'https://mdm.example.com/api/v1/devices?mac=$mac',
        jq_query => '.status == "enrolled"',
        %args,
    });
}

my $provisioner = new_ok(
    "pf::provisioner::generic_http",
    [{
        id       => 'test_generic_http',
        type     => 'generic_http',
        url      => 'https://mdm.example.com/api/v1/devices?mac=$mac',
        jq_query => '.status == "enrolled"',
    }]
);

{
    my $p = make_provisioner(
        method   => 'POST',
        url      => 'https://mdm.example.com/devices?mac=$mac&cat=$node.category',
        headers  => qq[Authorization: Bearer abc123\nX-Pid: \$node.pid],
        body     => '{"mac": "$mac"}',
    );
    my ($req, $err) = $p->make_request($TEST_MAC, $TEST_NODE_INFO);
    is($err, undef, "no error when building the request");
    is($req->method, 'POST', "method is templated into the request");
    is($req->uri, "https://mdm.example.com/devices?mac=$TEST_MAC&cat=gaming", "url template is rendered with mac and node attributes");
    is($req->header('Authorization'), 'Bearer abc123', "static header is set");
    is($req->header('X-Pid'), 'bob', "templated header value is rendered");
    is($req->content, qq[{"mac": "$TEST_MAC"}], "body template is rendered");
    is($req->content_type, 'application/json', "default content type is applied to the body");
}

{
    my $p = make_provisioner(username => 'user', password => 'pass');
    my ($req, $err) = $p->make_request($TEST_MAC, $TEST_NODE_INFO);
    my ($user, $pass) = $req->authorization_basic;
    is($user, 'user', "basic auth credentials are set");

    my $p2 = make_provisioner(
        username => 'user',
        password => 'pass',
        headers  => 'Authorization: Bearer abc123',
    );
    ($req, $err) = $p2->make_request($TEST_MAC, $TEST_NODE_INFO);
    is($req->header('Authorization'), 'Bearer abc123', "an explicit Authorization header wins over basic auth");
}

{
    my $p = make_provisioner(url => 'https://mdm.example.com/${undefined_func()}');
    my ($req, $err) = $p->make_request($TEST_MAC, $TEST_NODE_INFO);
    is($req, undef, "no request on a template error");
    ok(defined $err, "template errors are reported");
}

{
    my ($pass, $results, $err) = pf::provisioner::generic_http->evaluate_jq('{"status":"enrolled"}', '.status == "enrolled"');
    is($err, undef, "no error on a valid query");
    ok($pass, "matching query passes");

    ($pass, $results, $err) = pf::provisioner::generic_http->evaluate_jq('{"status":"removed"}', '.status == "enrolled"');
    ok(!$pass, "non matching query fails");

    ($pass, $results, $err) = pf::provisioner::generic_http->evaluate_jq('{"a":null}', '.a');
    ok(!$pass, "null result fails");

    ($pass, $results, $err) = pf::provisioner::generic_http->evaluate_jq('{"a":1}', '.missing');
    ok(!$pass, "a missing key yields null and fails");

    ($pass, $results, $err) = pf::provisioner::generic_http->evaluate_jq('{"a":1}', 'empty');
    ok(!$pass, "an empty result set fails");

    ($pass, $results, $err) = pf::provisioner::generic_http->evaluate_jq('{"a":0}', '.a');
    ok($pass, "0 is truthy under jq semantics");

    ($pass, $results, $err) = pf::provisioner::generic_http->evaluate_jq('{"a":{"b":1}}', '.a');
    ok($pass, "an object result passes");

    ($pass, $results, $err) = pf::provisioner::generic_http->evaluate_jq('{"devices":[{"mac":"aa"}]}', '.devices | length > 0');
    ok($pass, "a comparison on a piped length passes");

    ($pass, $results, $err) = pf::provisioner::generic_http->evaluate_jq('{"a":1}', '.a |bad_func_xyz');
    ok(defined $err, "an invalid query reports an error");

    ($pass, $results, $err) = pf::provisioner::generic_http->evaluate_jq('not json', '.a');
    ok(defined $err, "malformed JSON reports an error");
    is($pass, undef, "no pass/fail on error");
}

{
    my $mock = Test::MockModule->new('LWP::UserAgent');

    my $response = HTTP::Response->new(200, 'OK', ['Content-Type' => 'application/json'], '{"status":"enrolled"}');
    $mock->mock(request => sub { return $response });
    my $p = make_provisioner();
    is($p->authorize($TEST_MAC, $TEST_NODE_INFO), $TRUE, "authorize returns true when the jq query passes");

    $response = HTTP::Response->new(200, 'OK', ['Content-Type' => 'application/json'], '{"status":"removed"}');
    is($p->authorize($TEST_MAC, $TEST_NODE_INFO), $FALSE, "authorize returns false when the jq query does not pass");

    $response = HTTP::Response->new(200, 'OK', ['Content-Type' => 'text/plain'], 'oops not json');
    is($p->authorize($TEST_MAC, $TEST_NODE_INFO), $FALSE, "authorize returns false when the response is not valid JSON");

    $response = HTTP::Response->new(500, 'Internal Server Error', [], '');
    is($p->authorize($TEST_MAC, $TEST_NODE_INFO), $pf::provisioner::COMMUNICATION_FAILED, "authorize returns COMMUNICATION_FAILED on a server error");

    $response = HTTP::Response->new(404, 'Not Found', [], '');
    is($p->authorize($TEST_MAC, $TEST_NODE_INFO), $pf::provisioner::COMMUNICATION_FAILED, "authorize returns COMMUNICATION_FAILED on a 404");

    my $bad_template = make_provisioner(url => 'https://mdm.example.com/${undefined_func()}');
    is($bad_template->authorize($TEST_MAC, $TEST_NODE_INFO), $pf::provisioner::COMMUNICATION_FAILED, "authorize returns COMMUNICATION_FAILED on a template error");
}

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
