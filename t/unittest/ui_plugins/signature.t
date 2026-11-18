#!/usr/bin/perl

=head1 NAME

signature

=head1 DESCRIPTION

The key and the signature of the requests of the plugin proxy: the shared
vector of go/uiplugins/testdata/signature.json, the same in Go and Perl.

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More;
use File::Slurp qw(read_file);
use JSON::MaybeXS qw(decode_json);
use pf::ui_plugins;

my $v = decode_json(scalar read_file('/usr/local/pf/go/uiplugins/testdata/signature.json'));
local $ENV{PF_SYSTEM_INIT_KEY} = $v->{system_init_key};
my $key = pf::ui_plugins::proxy_key($v->{name});
is(unpack('H*', $key), $v->{proxy_key}, 'the key of the plugin');
is(pf::ui_plugins::proxy_signature($key, @{$v}{qw(timestamp method path query username roles actions body_sha256)}), $v->{signature}, 'the signature');

my %request = (%$v{qw(method path query username roles actions body timestamp signature)});
my ($ok, $error) = pf::ui_plugins::check_signature($key, \%request, $v->{timestamp} + 10);
ok($ok, 'a signed request') or diag($error);
($ok) = pf::ui_plugins::check_signature($key, { %request, actions => 'PLUGIN_READ,PLUGIN_WRITE,ALL' }, $v->{timestamp});
ok(!$ok, 'changed actions');
($ok) = pf::ui_plugins::check_signature($key, { %request, username => 'other' }, $v->{timestamp});
ok(!$ok, 'another admin');
($ok) = pf::ui_plugins::check_signature($key, { %request, roles => 'admin' }, $v->{timestamp});
ok(!$ok, 'other roles');
($ok) = pf::ui_plugins::check_signature($key, { %request, body => '{"thread_id":4}' }, $v->{timestamp});
ok(!$ok, 'another body');
($ok) = pf::ui_plugins::check_signature($key, { %request, body => undef }, $v->{timestamp});
ok(!$ok, 'no body');
($ok, $error) = pf::ui_plugins::check_signature($key, \%request, $v->{timestamp} + 600);
ok(!$ok, 'expired');
($ok) = pf::ui_plugins::check_signature($key, { %request, signature => undef }, $v->{timestamp});
ok(!$ok, 'no signature');
($ok) = pf::ui_plugins::check_signature(pf::ui_plugins::proxy_key('other'), \%request, $v->{timestamp});
ok(!$ok, 'the key of another plugin');

done_testing();

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
