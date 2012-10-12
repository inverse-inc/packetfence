#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More tests => 77;

# pf core libs
use lib '/usr/local/pf/lib';

BEGIN { use_ok('pf::accounting') }
BEGIN { use_ok('pf::action') }
BEGIN { use_ok('pf::billing') }
BEGIN { use_ok('pf::billing::constants') }
BEGIN { use_ok('pf::billing::custom') }
BEGIN { use_ok('pf::billing::gateway::authorize_net') }
BEGIN { use_ok('pf::class') }
BEGIN { use_ok('pf::configfile') }
BEGIN { use_ok('pf::config') }
BEGIN { use_ok('pf::db') }
BEGIN { use_ok('pf::email_activation') }
BEGIN { use_ok('pf::enforcement') }
BEGIN { use_ok('pf::floatingdevice') }
BEGIN { use_ok('pf::floatingdevice::custom') }
BEGIN { use_ok('pf::freeradius') }
BEGIN { use_ok('pf::ifoctetslog') }
BEGIN { use_ok('pf::import') }
BEGIN { use_ok('pf::inline') }
BEGIN { use_ok('pf::inline::custom') }
BEGIN { use_ok('pf::iplog') }
BEGIN { use_ok('pf::locationlog') }
BEGIN { use_ok('pf::lookup::node') }
BEGIN { use_ok('pf::lookup::person') }
BEGIN { use_ok('pf::nodecategory') }
BEGIN { use_ok('pf::node') }
BEGIN { use_ok('pf::os') }
BEGIN { use_ok('pf::person') }
BEGIN { use_ok('pf::pfcmd::checkup') }
BEGIN { use_ok('pf::pfcmd::dashboard') }
BEGIN { use_ok('pf::pfcmd::graph') }
BEGIN { use_ok('pf::pfcmd::help') }
BEGIN { use_ok('pf::pfcmd::pfcmd') }
BEGIN { use_ok('pf::pfcmd::report') }
BEGIN { use_ok('pf::Portal::Profile') }
BEGIN { use_ok('pf::Portal::ProfileFactory') }
BEGIN { use_ok('pf::Portal::Session') }
BEGIN { use_ok('pf::radius') }
BEGIN { use_ok('pf::radius::constants') }
BEGIN { use_ok('pf::radius::custom') }
BEGIN { use_ok('pf::scan') }
BEGIN { use_ok('pf::scan::nessus') }
BEGIN { use_ok('pf::scan::openvas') }
BEGIN { use_ok('pf::schedule') }
BEGIN { use_ok('pf::SNMP::constants') }
BEGIN { use_ok('pf::services') }
BEGIN { use_ok('pf::services::apache') }
BEGIN { use_ok('pf::services::dhcpd') }
BEGIN { use_ok('pf::services::named') }
BEGIN { use_ok('pf::sms_activation') }
BEGIN { use_ok('pf::soh') }
BEGIN { use_ok('pf::soh::custom') }
BEGIN { use_ok('pf::switchlocation') }
BEGIN { use_ok('pf::temporary_password') }
BEGIN { use_ok('pf::traplog') }
BEGIN { use_ok('pf::trigger') }
BEGIN { use_ok('pf::useragent') }
BEGIN { use_ok('pf::util') }
BEGIN { use_ok('pf::util::apache') }
BEGIN { use_ok('pf::util::dhcp') }
BEGIN { use_ok('pf::util::radius') }
BEGIN { use_ok('pf::violation') }
BEGIN { use_ok('pf::vlan') }
BEGIN { use_ok('pf::vlan::custom') }
BEGIN { use_ok('pf::web') }
BEGIN { use_ok('pf::web::admin') }
BEGIN { use_ok('pf::web::constants') }
BEGIN { use_ok('pf::web::custom') }
BEGIN { use_ok('pf::web::dispatcher') }
BEGIN { use_ok('pf::web::guest') }
BEGIN { use_ok('pf::web::release') }
BEGIN { use_ok('pf::web::util') }

# external authentication modules
use lib '/usr/local/pf/conf/';
BEGIN { use_ok('authentication::guest_managers') }
BEGIN { use_ok('authentication::kerberos') }
BEGIN { use_ok('authentication::ldap') }
BEGIN { use_ok('authentication::local') }
BEGIN { use_ok('authentication::preregistered_guests') }
BEGIN { use_ok('authentication::radius') }

=head1 AUTHOR

Dominik Ghel <dghel@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

Regis Balzard <rbalzard@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2009-2012 Inverse inc.

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

