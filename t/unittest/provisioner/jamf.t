#!/usr/bin/perl

=head1 NAME

jamf

=head1 DESCRIPTION

unit test for the API token of pf::provisioner::jamf (GitHub #8442)

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 18;
use Test::NoWarnings;
use HTTP::Response;
use POSIX qw(strftime);

use_ok("pf::provisioner::jamf");

# Canned Jamf answers, in order; @calls records the requests.
my (@calls, @answers);
no warnings 'redefine';
*LWP::UserAgent::request = sub {
    my ($ua, $req) = @_;
    push @calls, [ $req->method, $req->uri->path, $req->header('Authorization') ];
    my ($code, $body) = @{ shift @answers };
    my $r = HTTP::Response->new($code, 'x'); $r->content($body); return $r;
};
sub iso { strftime('%Y-%m-%dT%H:%M:%S.123Z', gmtime(time + shift)) }
sub tok { my ($t, $in) = @_; [200, qq({"token":"$t","expires":") . iso($in) . '"}'] }

my $p = pf::provisioner::jamf->new(id => 'jamf9626', type => 'jamf', api_username => 'u', api_password => 'p', host => 'jamf.example.com', sync_pid => 0);

# TTL from expires
my $data = do { @answers = (tok('A', 600)); $p->get_access_token };
ok(abs($data->{expires_in} - 600) <= 2, "expires_in from expires ($data->{expires_in})");
@answers = ([200, '{"token":"B","expires":"garbage"}']);
is($p->get_access_token->{expires_in}, 1800, 'unparsable expires falls back to 30 min');
@answers = ([200, '{"token":"B"}']);
is($p->get_access_token->{expires_in}, 1800, 'missing expires falls back to 30 min');

# cache honours the TTL
@calls = (); $pf::provisioner::jamf::CHI_CACHE->remove('jamf9626');
@answers = (tok('T1', 600), [200, '{}']);
my ($code) = $p->execute_request('00:11:22:33:44:55', 'computers');
is($code, 200, 'first request ok');
is_deeply([map { $_->[2] } @calls], [ 'Basic dTpw', 'Bearer T1' ], 'token fetched then used');

# 401 with a cached token: clear, new token, retry once
@calls = ();
@answers = ([401, ''], tok('T2', 600), [200, '{}']);
($code) = $p->execute_request('00:11:22:33:44:55', 'computers');
is($code, 200, 'retried after 401');
is_deeply([map { "$_->[0] $_->[1] " . ($_->[2] // '') } @calls],
  [ 'GET /JSSResource/computers/macaddress/00%3A11%3A22%3A33%3A44%3A55 Bearer T1', 'POST /api/v1/auth/token Basic dTpw', 'GET /JSSResource/computers/macaddress/00%3A11%3A22%3A33%3A44%3A55 Bearer T2' ], 'stale token replaced');
is($pf::provisioner::jamf::CHI_CACHE->get('jamf9626')->{token}, 'T2', 'new token cached');

# a second 401 is not retried again
@calls = ();
@answers = ([401, ''], tok('T3', 600), [401, '']);
($code) = $p->execute_request('00:11:22:33:44:55', 'computers');
is($code, 401, 'only one retry');
is(scalar @calls, 3, 'three requests');

# no token (old Jamf): basic auth, a 401 isn't retried
$pf::provisioner::jamf::CHI_CACHE->remove('jamf9626'); @calls = ();
@answers = ([404, ''], [401, '']);
($code) = $p->execute_request('00:11:22:33:44:55', 'computers');
is($code, 401, 'basic auth 401 returned');
is_deeply([map { $_->[2] } @calls], [ 'Basic dTpw', 'Basic dTpw' ], 'token attempt then basic, no retry');

# token already expired: not cached
$pf::provisioner::jamf::CHI_CACHE->remove('jamf9626');
@answers = ([200, qq({"token":"E","expires":") . iso(5) . '"}']);
is($p->access_token, 'E', 'short-lived token returned');
ok(!defined $pf::provisioner::jamf::CHI_CACHE->get('jamf9626'), 'but not cached (ttl <= jitter)');

# the configured port is used for both the token and the JSSResource requests (GitHub #9740)
my $p8443 = pf::provisioner::jamf->new(id => 'jamf9740', type => 'jamf', api_username => 'u', api_password => 'p', host => 'jamf.example.com', port => 8443, sync_pid => 0);
is($p8443->build_request_uri('00:11:22:33:44:55', 'computers'), 'https://jamf.example.com:8443/JSSResource/computers/macaddress/00%3A11%3A22%3A33%3A44%3A55', 'JSSResource URI uses the port');
my @ports;
{
    local *LWP::UserAgent::request = sub { push @ports, $_[1]->uri->port; my $r = HTTP::Response->new(200, 'x'); $r->content('{"token":"P"}'); return $r };
    $p8443->get_access_token;
}
is_deeply(\@ports, [8443], 'token request uses the port');

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
