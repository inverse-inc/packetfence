#!/usr/bin/perl

=head1 NAME

Pfs

=cut

=head1 DESCRIPTION

unit test for Pfs

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use pf::ConfigStore::Pf;
use Test::More tests => 32;
use Test::Mojo;
use Utils;

my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::Pf");

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $collection_base_url = '/api/v1/config/bases';

my $base_url = '/api/v1/config/base';
my $false = bless( do { \( my $o = 0 ) }, 'JSON::PP::Boolean' );
$t->options_ok("$base_url/advanced")
  ->status_is(200)
  ->json_is(
    '/meta/openid_attributes',
    {
        default => [],
        item    => {
            default     => undef,
            placeholder => undef,
            required    => $false,
            type        => "string",
            implied     => undef,
        },
        implied     => ['email'],
        placeholder => undef,
        required    => $false,
        type        => "array"
    }
);

$t->options_ok("$base_url/fencing")
  ->status_is(200)
  ->json_is('/meta/proxy_passthroughs/placeholder', undef)
  ->json_is('/meta/proxy_passthroughs/implied', 'crl.geotrust.com,ocsp.geotrust.com,crl.thawte.com,ocsp.thawte.com,crl.comodoca.com,ocsp.comodoca.com,crl.incommon.org,ocsp.incommon.org,crl.usertrust.com,ocsp.usertrust.com,mscrl.microsoft.com,crl.microsoft.com,ocsp.apple.com,ocsp.digicert.com,ocsp.entrust.com,srvintl-crl.verisign.com,ocsp.verisign.com,ctldl.windowsupdate.com,crl.globalsign.net,pki.google.com,www.microsoft.com,crl.godaddy.com,ocsp.godaddy.com,certificates.godaddy.com,crl.globalsign.com,secure.globalsign.com,cacerts.digicert.com,crt.comodoca.com,crl.incommon-rsa.org,crl.quovadisglobal.com,cert.incommon.org,crt.usertrust.com,crl.verisign.com,crl.starfieldtech.com,developer.apple.com,ts-crl.ws.symantec.com,certificates.intel.com,ocsp.sectigo.com');

$t->get_ok($collection_base_url)
  ->status_is(200);

$t->post_ok($collection_base_url => json => {})
  ->status_is(422);

$t->post_ok($collection_base_url, {'Content-Type' => 'application/json'} => '{')
  ->status_is(400);

$t->options_ok("$base_url/advanced" => json => {})
  ->status_is(200)
  ->json_is('/meta/openid_attributes/type', "array");

$t->get_ok("$base_url/advanced")
  ->status_is(200)
  ->json_is('/item/openid_attributes', []);

$t->patch_ok("$base_url/advanced" => json => { openid_attributes => ['bob'] })
  ->status_is(200);

$t->get_ok("$base_url/advanced")
  ->status_is(200)
  ->json_is('/item/openid_attributes', ['bob']);

$t->patch_ok("$base_url/advanced" => json => { openid_attributes => 'bobby' })
  ->status_is(200);

$t->get_ok("$base_url/advanced")
  ->status_is(200)
  ->json_is('/item/openid_attributes', ['bobby']);

$t->patch_ok("$base_url/general" => json => { domain => 'bob.local'})
  ->status_is(422);

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
