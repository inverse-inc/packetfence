#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib qw(
   /usr/local/pf/conf
   /usr/local/pf/lib
);

use Test::Pod::Coverage tests => 15;

pod_coverage_ok('authentication::kerberos');
pod_coverage_ok("authentication::ldap");
pod_coverage_ok("authentication::local");
pod_coverage_ok("authentication::radius");

pod_coverage_ok("pf::radius");
pod_coverage_ok("pf::vlan");
pod_coverage_ok("pf::SNMP");
pod_coverage_ok("pf::floatingdevice");
pod_coverage_ok("pf::freeradius");
pod_coverage_ok("pf::import");
pod_coverage_ok("pf::services::apache");
pod_coverage_ok("pf::web");
pod_coverage_ok("pf::web::util");
pod_coverage_ok("pf::web::wispr");
# Warning: this doesn't test for PFAPI subs since it's under another package name
# I couldn't find a way to tell T::P::C to cover it
pod_coverage_ok("pf::WebAPI");

=head1 AUTHOR

Dominik Ghel <dghel@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

Regis Balzard <rbalzard@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2009-2011 Inverse inc.

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

