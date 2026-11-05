#!/usr/bin/perl

=head1 NAME

ui_plugins

=head1 DESCRIPTION

unit test for pfconfig::namespaces::resource::ui_plugins, the admin UI plugins
registered in redis

Set UI_PLUGINS_TEST_REDIS=<host>:<port> to also build the namespace from a
real redis (the hash pf:ui_plugins of that redis is replaced).

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/lib);
    use test_paths;
}

use Test::More tests => 20;
use Test::NoWarnings;
use JSON::MaybeXS;

use pfconfig::namespaces::resource::ui_plugins;

my $validate = \&pfconfig::namespaces::resource::ui_plugins::validate;
my $valid = { id => 'acme', scheme => 'http', host => 'acme', port => 8080, manifest_path => '/pf-ui/manifest.json' };

is_deeply([$validate->('acme', encode_json($valid))], [$valid, undef], 'valid registration');

{
    my %no_scheme = %$valid;
    delete $no_scheme{scheme};
    my ($r) = $validate->('acme', encode_json(\%no_scheme));
    is($r->{scheme}, 'http', 'scheme defaults to http');
    my ($s) = $validate->('acme', encode_json({ %$valid, port => "8080" }));
    ok($s->{port} == 8080 && !ref($s->{port}), 'port as a string is normalized');
}

for my $case (
    [ 'Acme', $valid, 'invalid id' ],
    [ '-acme', $valid, 'invalid id' ],
    [ 'acme', { %$valid, id => 'other' }, 'id mismatch' ],
    [ 'acme', { %$valid, host => 'a b' }, 'invalid host' ],
    [ 'acme', { %$valid, host => undef }, 'invalid host' ],
    [ 'acme', { %$valid, port => 0 }, 'invalid port' ],
    [ 'acme', { %$valid, port => 65536 }, 'invalid port' ],
    [ 'acme', { %$valid, manifest_path => 'manifest.json' }, 'invalid manifest_path' ],
    [ 'acme', { %$valid, manifest_path => '/m?x=1' }, 'invalid manifest_path' ],
    [ 'acme', { %$valid, scheme => 'ftp' }, 'invalid scheme' ],
) {
    my ($id, $registration, $error) = @$case;
    my ($r, $e) = $validate->($id, encode_json($registration));
    ok(!defined $r && defined $e && $e eq $error, "refused: $error ($id)");
}

{
    my ($r, $e) = $validate->('acme', 'not json');
    ok(!defined $r && $e =~ /^invalid JSON/, 'refused: invalid JSON');
    ($r, $e) = $validate->('acme', '[1]');
    ok(!defined $r && $e =~ /^invalid JSON/, 'refused: not an object');
}

# a namespace with the redis of config::Pf
sub namespace {
    my ($host, $port) = @_;
    my $ns = bless { config => { services => { redis_cache_host => $host, redis_cache_port => $port } } }, 'pfconfig::namespaces::resource::ui_plugins';
    return $ns;
}

# an unreachable redis: no plugin, the admin UI works without them
is_deeply(namespace('127.0.0.1', 1)->build, {}, 'unreachable redis: no plugin');

SKIP: {
    skip 'UI_PLUGINS_TEST_REDIS not set', 3 unless $ENV{UI_PLUGINS_TEST_REDIS};
    my ($host, $port) = split /:/, $ENV{UI_PLUGINS_TEST_REDIS};
    my $ns = namespace($host, $port);
    my $redis = $ns->redis;
    $redis->del('pf:ui_plugins');
    is_deeply($ns->build, {}, 'no registration: no plugin');
    $redis->hset('pf:ui_plugins', 'acme', encode_json($valid));
    $redis->hset('pf:ui_plugins', 'Bad', encode_json($valid));
    $redis->hset('pf:ui_plugins', 'broken', '{');
    is_deeply($ns->build, { acme => $valid }, 'the valid registrations only');
    $redis->hdel('pf:ui_plugins', 'acme');
    is_deeply($ns->build, {}, 'deregistered');
    $redis->del('pf:ui_plugins');
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
