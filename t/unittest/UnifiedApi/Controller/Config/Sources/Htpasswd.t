#!/usr/bin/perl

=head1 NAME

Htpasswd

=head1 DESCRIPTION

unit test for Htpasswd

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

use Test::More tests => 75;

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
my $id1 = "id_$$";
my $id2 = "id2_$$";

#This is the second test
$t->post_ok("$collection_base_url/test" =>
    json => {
        type => 'Htpasswd',
        id   => 'test',
        path => '/usr/local/pf/t/data/htpasswd.conf',
        description => "Test",
    }
  )
  ->status_is(405)
  ->json_has('/errors');

my $content = 'authtest:$apr1$gpI/g6In$SEMJI9kxmLBTzLjM46Ws9.';

my $file = "/usr/local/pf/conf/uploads/sources/${id1}_path_upload.conf";

$t->post_ok("$collection_base_url" =>
    json => {
        type => 'Htpasswd',
        id   => $id1,
        path => undef,
        path_upload => encode_base64($content),
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
  ->json_is("/path", $file);
  ;

$t->get_ok("$base_url/$id1")
  ->status_is(200)
  ->json_is('/item/path', $file);
;

ok(-e $file, "$file was saved");
if (-e $file) {
    is($content, read_file($file), "File is saved $file properly");
} else {
    fail("File is saved $file properly");
}

$t->post_ok("$collection_base_url" =>
    json => {
        type => 'Htpasswd',
        id   => $id2,
        path => '/usr/local/pf/t/data/htpasswd.conf',
        path_upload => undef,
        description => "Test",
    }
  )
  ->status_is(201)
  ->json_is('/path', '/usr/local/pf/t/data/htpasswd.conf');


$t->get_ok("$base_url/htpasswd1")
  ->status_is(200)
  ->json_is('/item/class' => 'internal');

$t->options_ok("$collection_base_url?type=Htpasswd" )
  ->status_is(200)
  ->json_is(
      '/meta/path_upload',
      {
      default => undef,
      implied => undef,
      placeholder => undef,
      required => 0,
      type => 'file',
      accept => {
            type => 'String',
            default => '*/*',
          },
      }
  );

my $id3 = "id3_$$";
$t->post_ok("$collection_base_url" =>
    json => {
		"id" =>  $id3,
		"isClone" =>  $true,
		"isNew" =>  $false,
		"sourceType" =>  "Htpasswd",
		"administration_rules" =>  [{
			"actions" =>  [{
				"type" =>  "set_access_level",
				"value" =>  ["ALL"]
			}],
			"conditions" =>  [],
			"description" =>  "All admins",
			"id" =>  "admins",
			"match" =>  "all",
			"status" =>  "enabled"
		}],
		"authentication_rules" =>  [],
		"description" =>  "Legacy Source",
		"ldapfilter_operator" =>  undef,
        path => '/usr/local/pf/t/data/htpasswd.conf',
		"path_upload" =>  undef,
		"realms" =>  ["null"],
		"set_access_durations_action" =>  [],
		"set_role_from_source_action" =>  undef,
		"trigger_portal_mfa_action" =>  undef,
		"trigger_radius_mfa_action" =>  undef,
		"type" =>  "Htpasswd",
		"class" =>  "internal",
		"not_deletable" =>  $false,
		"not_sortable" =>  $false,
		"allowed_domains" =>  "",
		"banned_domains" =>  ""
	}
  )
  ->status_is(201);

$t->patch_ok("$base_url/$id3" =>
    json => {
		"id" =>  $id3,
		"isClone" =>  $true,
		"isNew" =>  $false,
		"sourceType" =>  "Htpasswd",
		"administration_rules" =>  [{
			"actions" =>  [{
				"type" =>  "set_access_level",
				"value" =>  ["ALL"]
			}],
			"conditions" =>  [],
			"description" =>  "All admins",
			"id" =>  "admins",
			"match" =>  "all",
			"status" =>  "enabled"
		}],
		"authentication_rules" =>  [],
		"description" =>  "Legacy Source",
		"ldapfilter_operator" =>  undef,
        path => undef,
		"path_upload" =>  $content,
		"realms" =>  ["null"],
		"set_access_durations_action" =>  [],
		"set_role_from_source_action" =>  undef,
		"trigger_portal_mfa_action" =>  undef,
		"trigger_radius_mfa_action" =>  undef,
		"type" =>  "Htpasswd",
		"class" =>  "internal",
		"not_deletable" =>  $false,
		"not_sortable" =>  $false,
		"allowed_domains" =>  "",
		"banned_domains" =>  ""
	}
  )
  ->status_is(200)
  ->json_is("/path", "/usr/local/pf/conf/uploads/sources/${id3}_path_upload.conf");

# htpasswd_users sub-resource (GUI-driven user management) ====================

# the source created above via path_upload already has one user 'authtest'
$t->get_ok("$base_url/$id1/htpasswd_users")
  ->status_is(200)
  ->json_is('/items', ['authtest']);

# add a new user
$t->post_ok("$base_url/$id1/htpasswd_users" =>
    json => { username => 'alice', password => 's3cret' }
  )
  ->status_is(201)
  ->json_is('/username', 'alice');

# listing now shows both, sorted
$t->get_ok("$base_url/$id1/htpasswd_users")
  ->status_is(200)
  ->json_is('/items', ['alice', 'authtest']);

# update an existing user's password
$t->patch_ok("$base_url/$id1/htpasswd_users/alice" =>
    json => { password => 'new-s3cret' }
  )
  ->status_is(200)
  ->json_is('/username', 'alice');

# rejecting invalid input
$t->post_ok("$base_url/$id1/htpasswd_users" =>
    json => { username => 'bob', password => '' }
  )
  ->status_is(422);

$t->post_ok("$base_url/$id1/htpasswd_users" =>
    json => { username => 'has:colon', password => 'whatever' }
  )
  ->status_is(422);

# delete the user
$t->delete_ok("$base_url/$id1/htpasswd_users/alice")
  ->status_is(204);

$t->get_ok("$base_url/$id1/htpasswd_users")
  ->status_is(200)
  ->json_is('/items', ['authtest']);

# deleting an unknown user is a no-op (still 204)
$t->delete_ok("$base_url/$id1/htpasswd_users/nobody")
  ->status_is(204);

# the sub-resource is only available on Htpasswd sources
# create a non-Htpasswd source for negative testing
my $null_id = "null_$$";
$t->post_ok("$collection_base_url" =>
    json => {
        type => 'Null',
        id => $null_id,
        description => "negative test",
    }
  )
  ->status_is(201);

$t->get_ok("$base_url/$null_id/htpasswd_users")
  ->status_is(405);

# htpasswd_file sub-resource (create file on demand) =========================

# list response carries file_exists for an existing source
$t->get_ok("$base_url/$id1/htpasswd_users")
  ->status_is(200)
  ->json_is('/file_exists', $true);

# create a fresh source that points at a path which does not exist yet
my $missing_id = "missing_$$";
my $missing_path = "/tmp/pf-test-htpasswd-${missing_id}.conf";
unlink $missing_path;
$t->post_ok("$collection_base_url" =>
    json => {
        type => 'Htpasswd',
        id   => $missing_id,
        path => $missing_path,
        path_upload => undef,
        description => "missing-file test",
    }
  )
  ->status_is(201);

# list now reports file_exists: false
$t->get_ok("$base_url/$missing_id/htpasswd_users")
  ->status_is(200)
  ->json_is('/items', [])
  ->json_is('/file_exists', $false);

# create the file via the new endpoint
$t->post_ok("$base_url/$missing_id/htpasswd_file")
  ->status_is(201)
  ->json_is('/created', 1);
ok(-e $missing_path, "$missing_path was created on disk");

# second call is a no-op (200, created => 0)
$t->post_ok("$base_url/$missing_id/htpasswd_file")
  ->status_is(200)
  ->json_is('/created', 0);

# list now reports file_exists: true and an empty list
$t->get_ok("$base_url/$missing_id/htpasswd_users")
  ->status_is(200)
  ->json_is('/items', [])
  ->json_is('/file_exists', $true);

# create endpoint is only available on Htpasswd sources
$t->post_ok("$base_url/$null_id/htpasswd_file")
  ->status_is(405);

unlink $missing_path;

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

