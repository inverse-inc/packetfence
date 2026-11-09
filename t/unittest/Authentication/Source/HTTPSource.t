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

use Test::More tests => 19;
use URI;
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
    encode(username => 'bob', switch => bless({_id => '192.0.2.1'}, 'pf::Switch'), nested => {deep => {deeper => 1}}),
    [username => 'bob'],
    "objects and deeper structures are not sent"
);

{
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    pf::Authentication::Source::HTTPSource::encode_params(mac => undef, radius_request => {'Called-Station-Id' => undef});
    is_deeply(\@warnings, [], "undefined values do not warn");
}

# Run match with the given JSON reply from the authorization API and return the
# actions as type => value
sub match_actions {
    my ($reply) = @_;
    my $mock = Test::MockModule->new('pf::Authentication::Source::HTTPSource');
    $mock->mock('_post_curl', sub { return (0, 200, $reply, undef) });
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

{
    my $mock = Test::MockModule->new('pf::Authentication::Source::HTTPSource');
    $mock->mock('_post_curl', sub { return (0, 200, '{"trigger_portal_mfa":"mfa2"}', undef) });
    my $rule = $source->match({username => 'bob', rule_class => $Rules::AUTH});
    is_deeply([map { $_->class } @{$rule->{actions}}], [$Rules::AUTH], "MFA trigger action is in the authentication class");
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

