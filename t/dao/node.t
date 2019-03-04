#!/usr/bin/perl -w

=head1 NAME

dao/node.t

=head1 DESCRIPTION

Testing data access layer for the pf::node module

=cut

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 7;
use Test::NoWarnings;

use Log::Log4perl;

Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( "dao/node.t" );
Log::Log4perl::MDC->put( 'proc', "dao/node.t" );
Log::Log4perl::MDC->put( 'tid',  0 );

use lib qw(/usr/local/pf/t);
use TestUtils;

# override database connection settings to connect to test database
TestUtils::use_test_db();

BEGIN { use_ok('pf::node') }

# method that we can test with a database that won't alter data and that need no parameters
my @simple_methods = qw(
    node_db_prepare
    node_view_all
    node_count_all
);

# Test methods with no parameters, assume no warnings and some results
{
    no strict 'refs';

    foreach my $method (@simple_methods) {

        ok(defined(&{$method}()), "testing $method call");
    }
}

# node_attributes_with_fingerprint returns 0 on failure, test against that
ok(node_attributes_with_fingerprint('f0:4d:a2:cb:d9:c5'), "node_attributes_with_fingerprint SQL query pass");

# node_view returns 0 on failure, test against that
ok(node_view('f0:4d:a2:cb:d9:c5'), "node_view SQL query pass");

# TODO add more tests, we should test:
#  - node_view on a node with no category should be empty ('') category and not undef (see #1063)
#  - exercice all SQL queries

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

