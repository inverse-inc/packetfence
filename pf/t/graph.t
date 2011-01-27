#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More tests => 13;
use lib '/usr/local/pf/lib';

BEGIN { use_ok('pf::pfcmd::graph') }

# These tests validate that the graph methods produce non-zero output
ok(graph_registered('day'), 'graph registered day');
ok(graph_registered('month'), 'graph registered month');
ok(graph_registered('year'), 'graph registered year');

ok(graph_unregistered('day'), 'graph unregistered day');
ok(graph_unregistered('month'), 'graph unregistered month');
ok(graph_unregistered('year'), 'graph unregistered year');

ok(graph_violations('day'), 'graph violations day');
ok(graph_violations('month'), 'graph violations month');
ok(graph_violations('year'), 'graph violations year');

# graph_nodes needs to be evaluated in an array context to give useful output
my @tmp;
ok((@tmp = graph_nodes('day')), 'graph nodes day');
ok((@tmp = graph_nodes('month')), 'graph nodes month');
ok((@tmp = graph_nodes('year')), 'graph nodes year');

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2010-2011 Inverse inc.

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

