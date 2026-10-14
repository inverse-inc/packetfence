#!/usr/bin/perl

=head1 NAME

rest

=head1 DESCRIPTION

unit test for pf::radius::rest::format_request

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

use Test::More tests => 10;
use MIME::Base64 qw(encode_base64);
use Test::NoWarnings;

use pf::radius::rest;

my $attr = sub { my @v = @_; return { attr_num => 0, type => 'string', value => \@v } };

# flat body (the default rlm_rest layout)
my $flat = pf::radius::rest::format_request({
    'User-Name'          => $attr->('bob'),
    'NAS-IP-Address'     => $attr->('192.168.40.22'),
    'Calling-Station-Id' => $attr->('02:44:45:4c:4c:01'),
    'Proxy-State'        => $attr->('a', 'b'),
    'Class'              => $attr->('base64:' . encode_base64("\x00\xffraw", '')),
});
is($flat->{'NAS-IP-Address'}, '192.168.40.22', 'flat body: attribute value');
is_deeply($flat->{'Proxy-State'}, ['a', 'b'], 'flat body: multi-valued attribute stays an array');
is($flat->{Class}, "\x00\xffraw", 'flat body: base64 value decoded');

# body_lists layout: {"request":{...},"proxy-reply":{...}}
my $nested = pf::radius::rest::format_request({
    'request' => {
        'User-Name'          => $attr->('02:44:45:4C:4C:01'),
        'NAS-IP-Address'     => $attr->('192.168.40.22'),
        'Calling-Station-Id' => $attr->('02:44:45:4c:4c:01'),
    },
    'proxy-reply' => {
        'Tunnel-Private-Group-Id' => $attr->('40'),
        'Cisco-AVPair'            => $attr->('ip:inacl#101=permit ip any any', 'ip:inacl#102=deny ip any any'),
    },
});
is($nested->{'NAS-IP-Address'}, '192.168.40.22', 'body_lists: request list flattened to the top level');
is($nested->{'Calling-Station-Id'}, '02:44:45:4c:4c:01', 'body_lists: request attributes kept');
ok(!exists $nested->{request}, 'body_lists: no leftover "request" key');
is($nested->{'proxy-reply'}{'Tunnel-Private-Group-Id'}, '40', 'body_lists: other lists kept under their name');
is_deeply($nested->{'proxy-reply'}{'Cisco-AVPair'}, ['ip:inacl#101=permit ip any any', 'ip:inacl#102=deny ip any any'], 'body_lists: multi-valued attribute in a proxy list');

# a flat body that happens to carry an attribute literally named "request" is not mistaken for body_lists
my $literal = pf::radius::rest::format_request({ 'request' => $attr->('x') });
is($literal->{request}, 'x', 'an attribute named "request" is still an attribute');

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
