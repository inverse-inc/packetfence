#!/usr/bin/perl

=head1 NAME

auth_log

=cut

=head1 DESCRIPTION

unit test for pf::auth_log

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

use Test::More tests => 15;

# This test will run last
use Test::NoWarnings;
use pf::authentication;
use pf::auth_log;
use pf::dal::auth_log;
use pf::db;

my $dbh = eval { db_connect() };
BAIL_OUT("Cannot connect to dbh") unless $dbh;

my $MAC = "de:ad:be:ef:00:01";

my $sql     = pf::authentication::getAuthenticationSource('local');
my $email   = pf::authentication::getAuthenticationSource('email');
my $sms     = pf::authentication::getAuthenticationSource('sms');
my $sponsor = pf::authentication::getAuthenticationSource('sponsor_uppercase_allowed');

sub cleanup {
    pf::dal::auth_log->remove_items(-where => { mac => $MAC });
}

sub latest {
    my ($status, $iter) = pf::dal::auth_log->search(
        -where    => { mac => $MAC },
        -order_by => { -desc => 'id' },
        -limit    => 1,
    );
    return $iter->next;
}

=head2 record_auth

=cut

cleanup();
pf::auth_log::record_auth($sql->id, $sql->type, $MAC, 'bob', $pf::auth_log::COMPLETED, 'default');
my $row = latest();
is($row->{source},      'local', "record_auth records the source id");
is($row->{source_type}, 'SQL',   "record_auth records the source type");

# the paths that record a failure against every source they tried pass comma
# joined lists of both
cleanup();
my @sources = ($sql, $email, $sms);
pf::auth_log::record_auth(
    join(',', map { $_->id } @sources),
    join(',', map { $_->type } @sources),
    $MAC, 'bob', $pf::auth_log::FAILED, 'default',
);
$row = latest();
is($row->{source},      'local,email,sms', "record_auth records every tried source id on failure");
is($row->{source_type}, 'SQL,Email,SMS',   "record_auth records every tried source type on failure");
# a comma-joined list has no single family, so the family is UNCLASSIFIED
is($row->{source_base_type}, '', "record_auth records '' (UNCLASSIFIED) for the comma-joined failure list");

=head2 source_base_type -- the persisted source family

The family is derived from the source's class hierarchy, so it needs no list of
types to maintain. A direct source records its own type; a source with an
intermediate parent collapses to the family.

=cut

cleanup();
pf::auth_log::record_auth($sms->id, $sms->type, $MAC, 'bob', $pf::auth_log::COMPLETED, 'default');
is(latest()->{source_base_type}, 'SMS', "direct source records its own family (SMS)");

my $ad     = pf::authentication::getAuthenticationSource('LDAP');
my $openid = pf::authentication::getAuthenticationSource('openid');

cleanup();
pf::auth_log::record_auth($ad->id, $ad->type, $MAC, 'bob', $pf::auth_log::COMPLETED, 'default');
is(latest()->{source_base_type}, 'LDAP', "AD collapses to the LDAP family");

cleanup();
pf::auth_log::record_auth($openid->id, $openid->type, $MAC, 'bob', $pf::auth_log::COMPLETED, 'default');
is(latest()->{source_base_type}, 'OAuth', "OpenID collapses to the OAuth family");

=head2 record_guest_attempt / record_completed_guest

=cut

cleanup();
pf::auth_log::record_guest_attempt($sponsor->id, $sponsor->type, $MAC, 'guest@example.com', 'default');
$row = latest();
is($row->{source},      $sponsor->id,   "record_guest_attempt records the source id");
is($row->{source_type}, 'SponsorEmail', "record_guest_attempt records the source type");
is($row->{source_base_type}, 'SponsorEmail', "record_guest_attempt records the source family");

pf::auth_log::record_completed_guest($sponsor->id, $sponsor->type, $MAC, $pf::auth_log::COMPLETED, 'default');
$row = latest();
is($row->{status},      'completed',    "record_completed_guest completes the attempt row");
is($row->{source_type}, 'SponsorEmail', "record_completed_guest keeps the source type");
is($row->{source_base_type}, 'SponsorEmail', "record_completed_guest keeps the source family");

cleanup();

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
