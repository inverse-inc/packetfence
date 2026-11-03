#!/usr/bin/perl

=head1 NAME

node_regdate

=head1 DESCRIPTION

A node that becomes registered gets a registration date, whichever path
registers it: the DAL, node_modify, or the admin API create and update.

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 27;
use Test::Mojo;
use Test::NoWarnings;
use Utils;
use pf::constants qw($ZERO_DATE);
use pf::dal::node;
use pf::node qw(node_add node_modify);

my $t = Test::Mojo->new('pf::UnifiedApi');

sub regdate_of {
    my ($mac) = @_;
    my ($status, $node) = pf::dal::node->find({ mac => $mac });
    return $node ? $node->regdate : undef;
}

sub has_regdate {
    my ($mac) = @_;
    my $regdate = regdate_of($mac);
    return defined $regdate && $regdate ne $ZERO_DATE;
}

{
    my $mac = Utils::test_mac();
    pf::dal::node->create({ mac => $mac, pid => "default", status => "reg" });
    ok(has_regdate($mac), "DAL create as reg sets regdate");
}

{
    my $mac = Utils::test_mac();
    pf::dal::node->create({ mac => $mac, pid => 'default', status => 'unreg' });
    is(regdate_of($mac), $ZERO_DATE, "unreg node has no regdate");
    ok(node_modify($mac, status => 'reg'), "node_modify to reg");
    ok(has_regdate($mac), "node_modify unreg to reg sets regdate");
}

{
    my $mac = Utils::test_mac();
    my $regdate = '2020-01-02 03:04:05';
    pf::dal::node->create({ mac => $mac, pid => 'default', status => 'reg', regdate => $regdate });
    is(regdate_of($mac), $regdate, "explicit regdate kept on create");
    ok(node_modify($mac, notes => 'edited', regdate => $ZERO_DATE), "node_modify on a reg node");
    is(regdate_of($mac), $ZERO_DATE, "node_modify of a node already reg does not invent a regdate");
}

{
    my $mac = Utils::test_mac();
    ok(node_add($mac, pid => 'default', status => 'reg'), "node_add as reg");
    ok(has_regdate($mac), "node_add as reg sets regdate");
}

{
    my $mac = Utils::test_mac();
    $t->post_ok('/api/v1/nodes' => json => { mac => $mac, pid => 'default', status => 'reg' })
      ->status_is(201);
    ok(has_regdate($mac), "API create as reg sets regdate");
}

{
    my $mac = Utils::test_mac();
    $t->post_ok('/api/v1/nodes' => json => { mac => $mac, pid => 'default', status => 'unreg' })
      ->status_is(201);
    # The admin UI sends the whole node, zero regdate included
    $t->patch_ok("/api/v1/node/$mac" => json => { status => 'reg', regdate => $ZERO_DATE, unregdate => '' })
      ->status_is(200);
    ok(has_regdate($mac), "API update unreg to reg sets regdate");
}

{
    my $mac = Utils::test_mac();
    my $regdate = '2021-05-06 07:08:09';
    pf::dal::node->create({ mac => $mac, pid => 'default', status => 'reg', regdate => $regdate });
    $t->patch_ok("/api/v1/node/$mac" => json => { status => 'reg', notes => 'x' })
      ->status_is(200);
    is(regdate_of($mac), $regdate, "API update of a reg node without regdate keeps it");
    $t->patch_ok("/api/v1/node/$mac" => json => { status => 'reg', regdate => $ZERO_DATE })
      ->status_is(200);
    is(regdate_of($mac), $regdate, "API update of a reg node with a zero regdate keeps it");
}

{
    my $mac = Utils::test_mac();
    my $regdate = '2022-02-03 04:05:06';
    pf::dal::node->create({ mac => $mac, pid => 'default', status => 'unreg' });
    $t->patch_ok("/api/v1/node/$mac" => json => { status => 'reg', regdate => $regdate })
      ->status_is(200);
    is(regdate_of($mac), $regdate, "API update to reg with an explicit regdate uses it");
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
