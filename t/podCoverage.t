#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib qw(/usr/local/pf/lib);
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::Pod::Coverage tests => 24;

pod_coverage_ok('authentication::guest_managers');
pod_coverage_ok('authentication::kerberos');
pod_coverage_ok("authentication::ldap");
pod_coverage_ok("authentication::local");
pod_coverage_ok('authentication::preregistered_guests');
pod_coverage_ok("authentication::radius");

pod_coverage_ok("pf::accounting");
pod_coverage_ok("pf::enforcement");
pod_coverage_ok("pf::floatingdevice");
pod_coverage_ok("pf::freeradius");
pod_coverage_ok("pf::import");
pod_coverage_ok("pf::inline");
pod_coverage_ok("pf::radius");
pod_coverage_ok("pf::services::apache");
pod_coverage_ok("pf::services::dhcpd");
pod_coverage_ok("pf::services::named");
pod_coverage_ok("pf::Switch");
pod_coverage_ok("pf::util::apache");
pod_coverage_ok("pf::util::dhcp");
pod_coverage_ok("pf::util::radius");
pod_coverage_ok("pf::role");
pod_coverage_ok("pf::web");
pod_coverage_ok("pf::web::dispatcher");
pod_coverage_ok("pf::web::guest");
pod_coverage_ok("pf::web::util");

# Warning: this doesn't test for PFAPI subs since it's under another package name
# I couldn't find a way to tell T::P::C to cover it
pod_coverage_ok("pf::WebAPI");

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

