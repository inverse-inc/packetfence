#!/usr/bin/perl
=head1 NAME

dao/graph.t

=head1 DESCRIPTION

Testing data access layer for the pf::pfcmd::graph module

=cut
use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';

use Test::More tests => 11;
use Test::NoWarnings;

use Log::Log4perl;
use Readonly;

Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( "dao/graph.t" );
Log::Log4perl::MDC->put( 'proc', "dao/graph.t" );
Log::Log4perl::MDC->put( 'tid',  0 );

use TestUtils;

# override database connection settings to connect to test database
TestUtils::use_test_db();

BEGIN { use_ok('pf::pfcmd::graph') }

# These tests validate that the graph methods produce non-zero output
ok(graph_registered('day'), 'graph registered day');
ok(graph_registered('month'), 'graph registered month');
ok(graph_registered('year'), 'graph registered year');

ok(graph_unregistered('day'), 'graph unregistered day');
ok(graph_unregistered('month'), 'graph unregistered month');
ok(graph_unregistered('year'), 'graph unregistered year');

# TODO re-enable violation testing once we will have a test database with full configuration loaded in it
#ok(graph_violations('day'), 'graph violations day');
#ok(graph_violations('month'), 'graph violations month');
#ok(graph_violations('year'), 'graph violations year');

# graph_nodes needs to be evaluated in an array context to give useful output
my @tmp;
ok((@tmp = graph_nodes('day')), 'graph nodes day');
ok((@tmp = graph_nodes('month')), 'graph nodes month');
ok((@tmp = graph_nodes('year')), 'graph nodes year');

# TODO improve tests by validating data

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

