#!/usr/bin/perl

=head1 NAME

SAML

=head1 DESCRIPTION

unit test for SAML

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 4;

#This test will running last
use Test::NoWarnings;
use Test::Mojo;
use MIME::Base64;
use File::Slurp qw(read_file);

my $t = Test::Mojo->new('pf::UnifiedApi');
use pf::ConfigStore::Source;
use Utils;
my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::Source");

my $true = bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' );
my $false = bless( do { \( my $o = 0 ) }, 'JSON::PP::Boolean' );

my $collection_base_url = '/api/v1/config/sources';

my $base_url = '/api/v1/config/source';
my $id1 = "id_saml_$$";
my $id2 = "id_saml_$$";
my $content1 = 'asasaasa';
my $content2 = 'asasaasa';
$t->post_ok("$collection_base_url" =>
    json => {
        type => 'SAML',
        id   => $id1,
        sp_entity_id => 1,
        idp_entity_id => 2,
        authorization_source_id => 'htpasswd1',
        sp_key_path => undef,
        sp_key_path_upload => encode_base64($content1),
        sp_cert_path => undef,
        sp_cert_path_upload => encode_base64($content1),
        idp_cert_path => undef,
        idp_cert_path_upload => encode_base64($content1),
        idp_ca_cert_path => undef,
        idp_ca_cert_path_upload => encode_base64($content1),
        idp_metadata_path => undef,
        idp_metadata_path_upload => encode_base64($content1),
        description => "Test",
        authentication_rules =>  [
            {
                "actions" =>  [
                    {
                        "type" =>  "set_role",
                        "value" =>  "default"
                    },
                    {
                        "type" =>  "set_access_duration",
                        "value" =>  "1h"
                    }
                ],
                "conditions" =>  [],
                "description" =>  "Heelo",
                "id" =>  "qwqw",
                "match" =>  "all",
                "status" =>  "enabled"
            }
        ],
    }
  )
  ->status_is(201)
  ->json_is("/sp_key_path", "/usr/local/pf/conf/uploads/sources/${id1}_sp_key_path_upload.key");
  ;

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

