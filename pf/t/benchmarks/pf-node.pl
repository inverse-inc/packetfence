#!/usr/bin/perl
=head1 NAME

pf-node.pl

=head1 DESCRIPTION

Some performance benchmarks on some pf::node functions

=cut
use strict;
use warnings;
use diagnostics;

use Benchmark qw(cmpthese timethese);

use lib '/usr/local/pf/lib';

=head1 pf::node's node_view vs node_attributes

=cut
use pf::db;
use pf::node;

# get the db layer started
my $ignored = node_view('f0:4d:a2:cb:d9:c5');
my $results = timethese(100, {
    node_view => sub { 
        node_view('f0:4d:a2:cb:d9:c5');
    },
    node_attributes => sub { 
        node_attributes('f0:4d:a2:cb:d9:c5');
    }
});
cmpthese($results);

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2011 Inverse inc.

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
