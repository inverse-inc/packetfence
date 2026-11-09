#!/usr/bin/perl

=head1 NAME

HTTPSource

=head1 DESCRIPTION

unit test for HTTPSource

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 51;
use WWW::Curl::Easy;
use URI;
use JSON::MaybeXS qw(decode_json);
use Test::MockModule;
use pf::Authentication::constants;
use pf::Authentication::Source::HTTPSource;

#This test will running last
use Test::NoWarnings;
my $source = pf::Authentication::Source::HTTPSource->new({id => 'test'});

is_deeply([$source->handleResults('"{}"', "source")], [0, "Invalid response"]);
is_deeply([$source->handleResults("{}", "source")], [0, "Authentication failed"]);
is_deeply([$source->handleResults('{"result":1, "message": "Success"}', "source")], [1, "Success"]);

sub url_for_host {
    my ($host) = @_;
    return pf::Authentication::Source::HTTPSource->new({id => 'test', protocol => 'http', host => $host, port => 10000})->base_url('authentication');
}
is(url_for_host('192.0.2.10'), 'http://192.0.2.10:10000/authentication', "IPv4 host");
is(url_for_host('2001:db8::1'), 'http://[2001:db8::1]:10000/authentication', "IPv6 host enclosed in brackets");
is(url_for_host('[2001:db8::1]'), 'http://[2001:db8::1]:10000/authentication', "IPv6 host already in brackets");
is(url_for_host('auth.example.com'), 'http://auth.example.com:10000/authentication', "host name");

# Decode a URL-encoded body into an ordered list of key/value pairs
sub decode_params {
    my ($body) = @_;
    my $uri = URI->new('http://localhost/');
    $uri->query($body);
    return [$uri->query_form];
}

sub encode {
    return decode_params(pf::Authentication::Source::HTTPSource::encode_params(@_));
}

is_deeply(
    encode(username => 'bob', password => 'p@ss w&rd=1'),
    [password => 'p@ss w&rd=1', username => 'bob'],
    "scalar params are URL-encoded"
);

is_deeply(
    encode(username => 'bob', mac => undef),
    [mac => '', username => 'bob'],
    "undefined params are sent empty"
);

is_deeply(
    encode(
        username       => 'bob',
        radius_request => {
            'EAP-Type'                     => 13,
            'TLS-Client-Cert-Common-Name'  => 'bob.example.com',
            'TLS-Client-Cert-Serial'       => '01',
        },
    ),
    [
        'radius_request.EAP-Type'                    => 13,
        'radius_request.TLS-Client-Cert-Common-Name' => 'bob.example.com',
        'radius_request.TLS-Client-Cert-Serial'      => '01',
        username                                     => 'bob',
    ],
    "the attributes of the RADIUS request (EAP-TLS) are sent"
);

is_deeply(
    encode(radius_request => { 'Cisco-AVPair' => ['a=1', 'b=2'] }),
    ['radius_request.Cisco-AVPair' => 'a=1', 'radius_request.Cisco-AVPair' => 'b=2'],
    "multi-valued RADIUS attributes are sent once per value"
);

is_deeply(
    encode(username => 'bob', switch => bless({_id => '192.0.2.1'}, 'pf::Switch'), radius_request => {deep => {deeper => 1}}),
    [username => 'bob'],
    "objects and deeper structures are not sent"
);

is_deeply(
    encode(username => 'bob', owner => {pid => 'bob', psk => 'secret-psk', otp => 'secret-otp'}, node_info => {mac => '00:11:22:33:44:55'}),
    [username => 'bob'],
    "hashes other than the RADIUS request are not sent"
);

{
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    pf::Authentication::Source::HTTPSource::encode_params(mac => undef, radius_request => {'Called-Station-Id' => undef});
    is_deeply(\@warnings, [], "undefined values do not warn");
}

# Run match with the given JSON reply from the authorization API and return the
# actions as type => value
my %configured_mfa = (mfa1 => 1, mfa2 => 1);
sub match_actions {
    my ($reply) = @_;
    my $mock = Test::MockModule->new('pf::Authentication::Source::HTTPSource');
    $mock->mock('_post_curl', sub { return (0, 200, $reply, undef) });
    $mock->mock('mfa_exists', sub { exists $configured_mfa{$_[1]} });
    my $rule = $source->match({username => 'bob', rule_class => $Rules::AUTH});
    return $rule && { map { $_->type => $_->value } @{$rule->{actions}} };
}

is_deeply(
    match_actions('{"trigger_radius_mfa":"mfa1","trigger_portal_mfa":"mfa2"}'),
    {
        $Actions::TRIGGER_RADIUS_MFA => 'mfa1',
        $Actions::TRIGGER_PORTAL_MFA => 'mfa2',
    },
    "MFA triggers are returned as actions"
);

is_deeply(
    match_actions('{"access_duration":"1D","access_level":"ALL","sponsor":1,"category":"default","time_balance":"1h","bandwidth_balance":"1G"}'),
    {
        $Actions::SET_ACCESS_DURATION   => '1D',
        $Actions::SET_ACCESS_LEVEL      => 'ALL',
        $Actions::MARK_AS_SPONSOR       => 1,
        $Actions::SET_ROLE              => 'default',
        $Actions::SET_TIME_BALANCE      => '1h',
        $Actions::SET_BANDWIDTH_BALANCE => '1G',
    },
    "the other attributes are returned as actions"
);

is_deeply(
    match_actions('{"access_duration":"1D","unregdate":"2030-01-01"}'),
    { $Actions::SET_ACCESS_DURATION => '1D' },
    "unregdate is ignored when access_duration is set"
);

is_deeply(
    match_actions('{"unregdate":"2030-01-01","sponsor":0}'),
    { $Actions::SET_UNREG_DATE => '2030-01-01' },
    "unregdate alone is used, sponsor 0 is not an action"
);

is_deeply(
    match_actions('{"sponsor":true}'),
    { $Actions::MARK_AS_SPONSOR => 1 },
    "sponsor true marks the user as a sponsor"
);

is_deeply(
    match_actions('{"sponsor":false}'),
    {},
    "sponsor false is not an action"
);

is_deeply(
    match_actions('{"trigger_radius_mfa":"mfa_typo","trigger_portal_mfa":"mfa2"}'),
    { $Actions::TRIGGER_PORTAL_MFA => 'mfa2' },
    "an MFA trigger naming an unknown MFA is ignored"
);

is_deeply(
    match_actions('{"trigger_portal_mfa":true,"category":{"name":"x"},"access_level":["ALL"],"sponsor":"yes","access_duration":"1D"}'),
    { $Actions::SET_ACCESS_DURATION => '1D' },
    "attributes that are not strings or numbers are ignored"
);

for my $reply ('<html>Error</html>', '', '[]', '"ok"') {
    is(match_actions($reply), undef, "an authorization reply that is not a JSON object is a failure: '$reply'");
}

{
    my $body;
    my $mock = Test::MockModule->new('pf::Authentication::Source::HTTPSource');
    $mock->mock('_post_curl', sub { $body = $_[2]; return (0, 200, '{}', undef) });
    $source->match({
        username       => 'bob',
        password       => 'secret',
        rule_class     => $Rules::AUTH,
        radius_request => {
            'User-Name'                => 'bob',
            'User-Password'            => 'secret123456',
            'PacketFence-UserPassword' => 'c2VjcmV0',
            'CHAP-Password'            => 'x',
            'CHAP-Challenge'           => 'x',
            'MS-CHAP-Challenge'        => 'x',
            'MS-CHAP2-Response'        => 'x',
            'EAP-Message'              => 'x',
            'State'                    => 'x',
            'Message-Authenticator'    => 'x',
            'EAP-Type'                 => 13,
            'TLS-Client-Cert-Common-Name' => 'bob.example.com',
        },
    });
    is_deeply(
        decode_params($body),
        [
            'radius_request.EAP-Type'                    => 13,
            'radius_request.TLS-Client-Cert-Common-Name' => 'bob.example.com',
            'radius_request.User-Name'                   => 'bob',
            rule_class                                   => $Rules::AUTH,
            username                                     => 'bob',
        ],
        "secrets of the RADIUS request are not sent to the authorization API"
    );
}

{
    my $mock = Test::MockModule->new('pf::Authentication::Source::HTTPSource');
    $mock->mock('_post_curl', sub { return (0, 200, '{"trigger_portal_mfa":"mfa2"}', undef) });
    $mock->mock('mfa_exists', sub { 1 });
    my $rule = $source->match({username => 'bob', rule_class => $Rules::AUTH});
    is_deeply([map { $_->class } @{$rule->{actions}}], [$Rules::AUTH], "MFA trigger action is in the authentication class");
}

# Return the curl options set by _post_curl for a source with the given attributes
sub curl_options {
    my (%attrs) = @_;
    my %options;
    my $curl = Test::MockModule->new('WWW::Curl::Easy');
    $curl->mock('setopt', sub { my (undef, $option, $value) = @_; $options{$option} = $value; return 0 });
    $curl->mock('perform', sub { 0 });
    $curl->mock('getinfo', sub { 200 });
    my $http_source = pf::Authentication::Source::HTTPSource->new({id => 'test', protocol => 'https', %attrs});
    $http_source->_post_curl('authorization', 'username=bob');
    return \%options;
}

my $options = curl_options();
is_deeply([@$options{CURLOPT_SSL_VERIFYPEER, CURLOPT_SSL_VERIFYHOST}], [0, 0], "TLS is not verified when the option is not set, like before the option existed");

$options = curl_options(verify_tls => 'disabled');
is_deeply([@$options{CURLOPT_SSL_VERIFYPEER, CURLOPT_SSL_VERIFYHOST}], [0, 0], "TLS is not verified when disabled");

$options = curl_options(verify_tls => 'enabled');
is_deeply([@$options{CURLOPT_SSL_VERIFYPEER, CURLOPT_SSL_VERIFYHOST}], [1, 2], "the certificate and the hostname are verified when enabled");

{
    require pfappserver::Form::Config::Source::HTTP;
    # Process the form like the admin API does to return an existing source (cleanup_item)
    my $verify_tls_shown = sub {
        my (%item) = @_;
        my $form = pfappserver::Form::Config::Source::HTTP->new;
        $form->process(init_object => {id => 'test', type => 'HTTP', authentication_url => 'a', authorization_url => 'b', %item}, posted => 0);
        return $form->value->{verify_tls};
    };
    isnt($verify_tls_shown->(), 'enabled', "a source without verify_tls is not shown as verifying TLS, it does not");
    is($verify_tls_shown->(verify_tls => 'enabled'), 'enabled', "a source with verify_tls enabled is shown as enabled");
}

# Request content type

is($source->content_type, 'application/x-www-form-urlencoded', "requests are URL-encoded by default, like before the option existed");

my $json_source = pf::Authentication::Source::HTTPSource->new({id => 'test', content_type => 'application/json'});

sub encode_json_body {
    return decode_json(pf::Authentication::Source::HTTPSource::encode_json_params(@_));
}

is_deeply(
    encode_json_body(username => 'bob', password => 'p@ss w&rd=1', mac => undef),
    {username => 'bob', password => 'p@ss w&rd=1', mac => undef},
    "JSON: plain values are sent as is, undefined values as null"
);

is_deeply(
    encode_json_body(
        username       => 'bob',
        radius_request => {
            'EAP-Type'                    => 13,
            'TLS-Client-Cert-Common-Name' => 'bob.example.com',
            'Cisco-AVPair'                => ['a=1', 'b=2'],
            'Called-Station-Id'           => undef,
        },
    ),
    {
        username       => 'bob',
        radius_request => {
            'EAP-Type'                    => 13,
            'TLS-Client-Cert-Common-Name' => 'bob.example.com',
            'Cisco-AVPair'                => ['a=1', 'b=2'],
            'Called-Station-Id'           => undef,
        },
    },
    "JSON: the RADIUS request is an object, multi-valued attributes are arrays"
);

is_deeply(
    encode_json_body(username => 'bob', switch => bless({_id => '192.0.2.1'}, 'pf::Switch'), radius_request => {deep => {deeper => 1}, kept => 1}, list => ['a', {b => 1}]),
    {username => 'bob', radius_request => {kept => 1}, list => ['a']},
    "JSON: objects and deeper structures are not sent"
);

is_deeply(
    encode_json_body(username => 'bob', owner => {pid => 'bob', psk => 'secret-psk', otp => 'secret-otp'}, node_info => {mac => '00:11:22:33:44:55'}),
    {username => 'bob'},
    "JSON: hashes other than the RADIUS request are not sent"
);

like(
    pf::Authentication::Source::HTTPSource::encode_json_params(port => 1812, name => '1812'),
    qr/"name":"1812".*"port":1812/,
    "JSON: numbers stay numbers and strings stay strings"
);

is(
    pf::Authentication::Source::HTTPSource::encode_json_params(bytes => "caf\xc3\xa9", chars => "caf\x{e9}", wide => "\x{263a}", latin1 => "caf\xe9"),
    qq({"bytes":"caf\xc3\xa9","chars":"caf\xc3\xa9","latin1":"caf\xc3\xa9","wide":"\xe2\x98\xba"}),
    "JSON: the body is UTF-8, UTF-8 byte strings are not encoded twice"
);

# Return the body sent by authenticate and match for a source
sub sent_bodies {
    my ($http_source, $params) = @_;
    my @bodies;
    my $mock = Test::MockModule->new('pf::Authentication::Source::HTTPSource');
    $mock->mock('_post_curl', sub { push @bodies, $_[2]; return (0, 200, '{"result":1}', undef) });
    $http_source->authenticate('bob', 'secret');
    $http_source->match($params);
    return @bodies;
}

my $match_params = {
    username       => 'bob',
    password       => 'secret',
    rule_class     => $Rules::AUTH,
    radius_request => {
        'User-Name'                   => 'bob',
        'User-Password'               => 'secret123456',
        'MS-CHAP2-Response'           => 'x',
        'EAP-Type'                    => 13,
        'TLS-Client-Cert-Common-Name' => 'bob.example.com',
    },
};

{
    my ($authentication, $authorization) = sent_bodies($json_source, $match_params);
    is_deeply(decode_json($authentication), {username => 'bob', password => 'secret'}, "JSON: authentication sends the username and the password");
    is_deeply(
        decode_json($authorization),
        {
            username       => 'bob',
            rule_class     => $Rules::AUTH,
            radius_request => {
                'User-Name'                   => 'bob',
                'EAP-Type'                    => 13,
                'TLS-Client-Cert-Common-Name' => 'bob.example.com',
            },
        },
        "JSON: authorization sends the match params without the secrets"
    );
}

{
    my ($authentication, $authorization) = sent_bodies($source, $match_params);
    is_deeply(decode_params($authentication), [password => 'secret', username => 'bob'], "form: authentication is URL-encoded");
    is_deeply(
        decode_params($authorization),
        [
            'radius_request.EAP-Type'                    => 13,
            'radius_request.TLS-Client-Cert-Common-Name' => 'bob.example.com',
            'radius_request.User-Name'                   => 'bob',
            rule_class                                   => $Rules::AUTH,
            username                                     => 'bob',
        ],
        "form: authorization is URL-encoded"
    );
}

$options = curl_options(content_type => 'application/json');
is_deeply($options->{+CURLOPT_HTTPHEADER}, ['Content-Type: application/json'], "JSON: the Content-Type header is application/json");

$options = curl_options();
ok(!exists $options->{+CURLOPT_HTTPHEADER}, "form: curl sends its default application/x-www-form-urlencoded Content-Type");

{
    my $form = pfappserver::Form::Config::Source::HTTP->new;
    my $field = $form->field('content_type');
    is($field->default, 'application/x-www-form-urlencoded', "new HTTP sources are URL-encoded by default");
    is_deeply([sort map { $_->{value} } @{$field->options}], ['application/json', 'application/x-www-form-urlencoded'], "the content type can be URL-encoded or JSON");
}

# The RADIUS path passes the owner (person record with its PSK and OTP secret) in the match params
for my $http_source ($source, $json_source) {
    my (undef, $authorization) = sent_bodies($http_source, {
        username       => 'bob',
        rule_class     => $Rules::AUTH,
        owner          => {pid => 'bob', psk => 'secret-psk', otp => 'secret-otp'},
        radius_request => {'User-Name' => 'bob'},
    });
    unlike($authorization, qr/secret-psk|secret-otp|owner/, $http_source->content_type . ": the owner record is not sent to the authorization API");
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

