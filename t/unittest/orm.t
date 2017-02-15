=head1 NAME

orm

=cut

=head1 DESCRIPTION

unit test for orm

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 12;

use pf::db;
use pf::dal::node;

my $dbh  = eval {
    db_connect();
};

BAIL_OUT("Cannot connect to dbh") unless $dbh;


#This test will running last
use Test::NoWarnings;

my $test_mac = "ff:ff:ff:ff:ff:fe";

pf::dal::node->remove_by_id({mac => $test_mac});

my $node = pf::dal::node->find($test_mac);

is ($node, undef, "Node does not exists");

$node = pf::dal::node->new({ mac => $test_mac, pid => "default"});

ok(!$node->__from_table, "New node not the database");

ok($node, "New node not the database");

ok($node->save, "Saving $test_mac into the database");

ok($node->__from_table, "New node is in the database");

$node = pf::dal::node->find($test_mac);

ok($node, "Found node in database");

my $old_session = $node->sessionid;
my $new_session = "$$-new";

$node->sessionid($new_session);

ok($node->save, "Saving changes into the database");

$node = pf::dal::node->find($test_mac);

ok($node, "Reloading node from database");

is($node->sessionid, $new_session, "Changes were saved into database");

ok($node->remove, "Remove node in database");

$node = pf::dal::node->find($test_mac);

is ($node, undef, "Node does not exists");

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

