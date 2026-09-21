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

use Test::More tests => 76;
use Test::NoWarnings;
use Test::MockModule;
use HTTP::Response;
use URI;
use File::Temp qw(tempdir);
# used to show what an unrestricted jq program can do, next to what the
# provisioner's own compile stops it doing
use JQ::XS;

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
    # the device is handed to the query as $mac and $node, the same two the
    # request templates get
    my $C = "pf::provisioner::generic_http";
    my $vars = $C->jq_vars($TEST_MAC, $TEST_NODE_INFO);

    my ($pass, $results, $err) = $C->evaluate_jq(qq[{"devices":[{"mac":"$TEST_MAC"}]}], '.devices | any(.mac == $mac)', $vars);
    is($err, undef, "a query using \$mac compiles");
    ok($pass, "\$mac holds the mac of the device");

    ($pass, $results, $err) = $C->evaluate_jq('{"owner":"bob"}', '.owner == $node.pid', $vars);
    ok($pass, "\$node holds the attributes of the node");

    (undef, $results) = $C->evaluate_jq('{"a":1}', '$node.category', $vars);
    is($results->[0], 'gaming', "an attribute of \$node is readable");

    # they are jq named arguments, as --arg passes them
    (undef, $results) = $C->evaluate_jq('{"a":1}', '$ARGS.named.mac', $vars);
    is($results->[0], $TEST_MAC, "the variables are passed as jq named arguments");

    # a query naming them still compiles when there is no device to give it,
    # which is what the form validating a query relies on
    (undef, $results, $err) = $C->evaluate_jq('{"a":1}', '[$mac, $node]');
    is($err, undef, "a query using the variables compiles without any");
    is_deeply($results->[0], [undef, undef], "both variables are null when no device is given");

    # jq binds named arguments while a program is compiled, so each device
    # gets its own compile rather than the values of whoever came first
    (undef, $results) = $C->evaluate_jq('{}', '$node.pid', $C->jq_vars($TEST_MAC, { pid => 'bob' }));
    is($results->[0], 'bob', "a query is compiled for the device it is run for");

    (undef, $results) = $C->evaluate_jq('{}', '$node.pid', $C->jq_vars('11:22:33:44:55:66', { pid => 'alice' }));
    is($results->[0], 'alice', "and for the next device rather than keeping the first");
}

{
    my $mock = Test::MockModule->new('LWP::UserAgent');
    my $response = HTTP::Response->new(200, 'OK', ['Content-Type' => 'application/json'],
        qq[{"devices":[{"mac":"$TEST_MAC","owner":"bob"}]}]);
    $mock->mock(request => sub { return $response });

    my $query = '.devices | any(.mac == $mac and .owner == $node.pid)';
    is(make_provisioner(jq_query => $query)->authorize($TEST_MAC, $TEST_NODE_INFO), $TRUE,
        "authorize gives the device to the query as \$mac and \$node");
    is(make_provisioner(jq_query => $query)->authorize('11:22:33:44:55:66', { pid => 'bob' }), $FALSE,
        "a device the response does not name does not pass");
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
    is($p->authorize($TEST_MAC, $TEST_NODE_INFO), $pf::provisioner::COMMUNICATION_FAILED, "authorize returns COMMUNICATION_FAILED when the response is not valid JSON");

    $response = HTTP::Response->new(200, 'OK', ['Content-Type' => 'application/json'], '{"status":"enrolled"}');
    my $bad_query = make_provisioner(jq_query => '.a | bad_func_xyz');
    is($bad_query->authorize($TEST_MAC, $TEST_NODE_INFO), $FALSE, "authorize returns false when the jq query does not compile");

    $response = HTTP::Response->new(500, 'Internal Server Error', [], '');
    is($p->authorize($TEST_MAC, $TEST_NODE_INFO), $pf::provisioner::COMMUNICATION_FAILED, "authorize returns COMMUNICATION_FAILED on a server error");

    $response = HTTP::Response->new(404, 'Not Found', [], '');
    is($p->authorize($TEST_MAC, $TEST_NODE_INFO), $pf::provisioner::COMMUNICATION_FAILED, "authorize returns COMMUNICATION_FAILED on a 404");

    my $bad_template = make_provisioner(url => 'https://mdm.example.com/${undefined_func()}');
    is($bad_template->authorize($TEST_MAC, $TEST_NODE_INFO), $pf::provisioner::COMMUNICATION_FAILED, "authorize returns COMMUNICATION_FAILED on a template error");
}

{
    # the ERR_* / MAX_RESPONSE_SIZE package variables are each named once here
    no warnings 'once';
    my (undef, undef, $err, $kind) = pf::provisioner::generic_http->evaluate_jq('not json', '.a');
    is($kind, $pf::provisioner::generic_http::ERR_JSON, "an unparseable payload is reported as a json error");

    (undef, undef, $err, $kind) = pf::provisioner::generic_http->evaluate_jq('{"a":1}', '.a | bad_func_xyz');
    is($kind, $pf::provisioner::generic_http::ERR_QUERY, "a query that does not compile is reported as a query error");

    (undef, undef, $err, $kind) = pf::provisioner::generic_http->evaluate_jq('{"a":"x"}', '.a | tonumber');
    is($kind, $pf::provisioner::generic_http::ERR_JQ, "a jq runtime error is reported as a jq error");

    local $pf::provisioner::generic_http::MAX_RESPONSE_SIZE = 10;
    (undef, undef, $err, $kind) = pf::provisioner::generic_http->evaluate_jq('{"a":"0123456789"}', '.a');
    is($kind, $pf::provisioner::generic_http::ERR_JSON, "a payload over MAX_RESPONSE_SIZE is refused");
}

{
    my $p = make_provisioner(headers => qq[Cookie: a=1\nCookie: b=2]);
    my ($req, $err) = $p->make_request($TEST_MAC, $TEST_NODE_INFO);
    my @cookies = $req->header('Cookie');
    is(scalar(@cookies), 2, "a repeated header is not collapsed");
    is(join('|', @cookies), 'a=1|b=2', "a repeated header keeps the configured order");
}

{
    is(
        pf::provisioner::generic_http::_log_uri(URI->new('https://mdm.example.com/api?mac=aa&api_key=SECRET')),
        'https://mdm.example.com/api?<redacted>',
        "the query string is redacted from the logged uri"
    );
    is(
        pf::provisioner::generic_http::_log_uri(URI->new('https://mdm.example.com/api')),
        'https://mdm.example.com/api',
        "a uri without a query string is logged as is"
    );
}

{
    my ($pass, $results, $err) = pf::provisioner::generic_http->evaluate_jq_guarded('{"status":"enrolled"}', '.status == "enrolled"');
    ok($pass, "the guarded evaluation passes a matching query");

    ($pass, $results, $err) = pf::provisioner::generic_http->evaluate_jq_guarded('{}', '[range(100000000)] | length', 1);
    like($err // '', qr/did not complete within/, "the guarded evaluation kills a query that does not terminate");
}

{
    # a query comes from the configuration, and the process evaluating it
    # holds the database and API credentials of the daemon
    local $ENV{PF_TEST_JQ_SECRET} = 'hunter2';

    my ($pass, $results, $err) = pf::provisioner::generic_http->evaluate_jq('{"a":1}', 'env.PF_TEST_JQ_SECRET');
    is($err, undef, "a query naming env still compiles");
    is($results->[0], undef, "env.<name> does not reach the process environment");
    ok(!$pass, "a query reaching for an environment variable does not pass");

    (undef, $results, $err) = pf::provisioner::generic_http->evaluate_jq('{"a":1}', '$ENV.PF_TEST_JQ_SECRET');
    is($results->[0], undef, "\$ENV.<name> does not reach the process environment");

    (undef, $results) = pf::provisioner::generic_http->evaluate_jq('{"a":1}', 'env');
    is_deeply($results->[0], {}, "env is an empty object");

    (undef, $results) = pf::provisioner::generic_http->evaluate_jq('{"a":1}', '$ENV');
    is_deeply($results->[0], {}, "\$ENV is an empty object");

    my @raw = JQ::XS->new('env.PF_TEST_JQ_SECRET')->process({});
    is($raw[0], 'hunter2', "control: a jq program compiled without care does read the environment");
}

{
    no warnings 'once';
    my (undef, undef, $err, $kind) = pf::provisioner::generic_http->evaluate_jq('{"a":1}', 'include "evil"; .a');
    is($kind, $pf::provisioner::generic_http::ERR_QUERY, "a query with an include does not compile");
    like($err, qr/not allowed/, "the include is refused rather than looked for on disk");

    (undef, undef, $err, $kind) = pf::provisioner::generic_http->evaluate_jq('{"a":1}', 'import "evil" as e {search:"/tmp"}; .a');
    is($kind, $pf::provisioner::generic_http::ERR_QUERY, "a query with an import does not compile");

    my ($pass) = pf::provisioner::generic_http->evaluate_jq('{"include":1}', '.include == 1');
    ok($pass, "a query merely using the word include still compiles");

    # that query is compiled once on its own to tell a directive from the word,
    # and that compile needs the variables as much as the real one does
    ($pass) = pf::provisioner::generic_http->evaluate_jq(
        qq[{"include":"$TEST_MAC"}], '.include == $mac',
        pf::provisioner::generic_http->jq_vars($TEST_MAC, $TEST_NODE_INFO),
    );
    ok($pass, "a query holding the word include and naming a variable still compiles");
}

{
    # jq imports ~/.jq into every program it compiles, whether or not the
    # program asks for it, so that file can redefine what a query means
    my $home = tempdir(CLEANUP => 1);
    open(my $fh, '>', "$home/.jq") or die "cannot write the test ~/.jq: $!";
    print {$fh} qq[def length: "PWNED";\n];
    close($fh);
    local $ENV{HOME} = $home;

    my ($pass, $results, $err) = pf::provisioner::generic_http->evaluate_jq('{"a":[1,2,3]}', '.a | length');
    is($err, undef, "a query compiles with a ~/.jq present");
    is($results->[0], 3, "~/.jq is not imported into the query");

    my @raw = JQ::XS->new('[1,2,3] | length')->process({});
    is($raw[0], 'PWNED', "control: jq does import ~/.jq into a program compiled without care");
}

{
    no warnings 'once';
    my (undef, undef, $err, $kind) = pf::provisioner::generic_http->evaluate_jq('{"a":1}', 'halt');
    is($kind, $pf::provisioner::generic_http::ERR_JQ, "a query that halts is reported as an error");
    like($err, qr/halted/, "the halt is named in the error rather than read as a failed check");

    (undef, undef, $err, $kind) = pf::provisioner::generic_http->evaluate_jq('{"a":1}', '"boom" | halt_error');
    is($kind, $pf::provisioner::generic_http::ERR_JQ, "a query that calls halt_error is reported as an error");
    like($err, qr/boom/, "the halt_error message is reported");
}

{
    my (undef, undef, $err) = pf::provisioner::generic_http->evaluate_jq('{"a":1}', ".a\n| bad_func_xyz");
    like($err, qr/line 2\b/, "a compile error points at the line of the query as it was written");
    unlike($err, qr/\$ENV/, "the error does not quote the prologue back at the admin");

    # this one is reported by the compile that checks for a directive, which
    # never saw the prologue, so its line numbers must be left alone
    (undef, undef, $err) = pf::provisioner::generic_http->evaluate_jq('{"a":1}', '.include | bad_func_xyz');
    like($err, qr/line 1\b/, "a query holding the word include keeps its line numbers");
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
