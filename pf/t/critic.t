#!/usr/bin/perl

=head1 NAME

critic.t

=head1 DESCRIPTION

run Perl Critic for automated worst-practices avoidance

=cut

use strict;
use warnings;
use diagnostics;

use Test::Perl::Critic ( -profile => 'perlcriticrc' );
use Test::More;
use Test::NoWarnings;

use TestUtils;

# TODO: should these really be absolute PATHs? I don't think so!
my @files = (
    '/usr/local/pf/addons/802.1X/packetfence.pm',
    '/usr/local/pf/addons/accounting.pl',
    '/usr/local/pf/addons/autodiscover.pl',
    '/usr/local/pf/addons/connect_and_read.pl',
    '/usr/local/pf/addons/convertToPortSecurity.pl',
    '/usr/local/pf/addons/dhcp_dumper',
    '/usr/local/pf/addons/monitorpfsetvlan.pl',
    '/usr/local/pf/addons/mrtg/mrtg-wrapper.pl',
    '/usr/local/pf/addons/pfdetect_remote/sbin/pfdetect_remote',
    '/usr/local/pf/addons/recovery.pl',
    '/usr/local/pf/addons/upgrade/update-all-useragents.pl',
    '/usr/local/pf/bin/flip.pl',
    '/usr/local/pf/bin/pfcmd',
    '/usr/local/pf/bin/pfcmd_vlan',
    '/usr/local/pf/conf/authentication/guest_managers.pm',
    '/usr/local/pf/conf/authentication/kerberos.pm',
    '/usr/local/pf/conf/authentication/ldap.pm',
    '/usr/local/pf/conf/authentication/local.pm',
    '/usr/local/pf/conf/authentication/preregistered_guests.pm',
    '/usr/local/pf/conf/authentication/radius.pm',
    '/usr/local/pf/html/captive-portal/email_activation.cgi',  
    '/usr/local/pf/html/captive-portal/guest-management.cgi',
    '/usr/local/pf/html/captive-portal/guest-selfregistration.cgi',
    '/usr/local/pf/html/captive-portal/redir.cgi',
    '/usr/local/pf/html/captive-portal/release.cgi',
    '/usr/local/pf/html/captive-portal/register.cgi',
    '/usr/local/pf/html/captive-portal/wispr.cgi',
    '/usr/local/pf/lib/pf/action.pm',
    '/usr/local/pf/lib/pf/class.pm',
    '/usr/local/pf/lib/pf/configfile.pm',
    '/usr/local/pf/lib/pf/config.pm',
    '/usr/local/pf/lib/pf/db.pm',
    '/usr/local/pf/lib/pf/email_activation.pm',
    '/usr/local/pf/lib/pf/floatingdevice.pm',
    '/usr/local/pf/lib/pf/floatingdevice/custom.pm',
    '/usr/local/pf/lib/pf/freeradius.pm',
    '/usr/local/pf/lib/pf/ifoctetslog.pm',
    '/usr/local/pf/lib/pf/import.pm',
    '/usr/local/pf/lib/pf/iplog.pm',
    '/usr/local/pf/lib/pf/iptables.pm',
    '/usr/local/pf/lib/pf/locationlog.pm',
    '/usr/local/pf/lib/pf/lookup/node.pm',
    '/usr/local/pf/lib/pf/lookup/person.pm',
    '/usr/local/pf/lib/pf/nodecache.pm',
    '/usr/local/pf/lib/pf/nodecategory.pm',
    '/usr/local/pf/lib/pf/node.pm',
    '/usr/local/pf/lib/pf/os.pm',
    '/usr/local/pf/lib/pf/person.pm',
    '/usr/local/pf/lib/pf/pfcmd/checkup.pm',
    '/usr/local/pf/lib/pf/pfcmd/dashboard.pm',
    '/usr/local/pf/lib/pf/pfcmd/graph.pm',
    '/usr/local/pf/lib/pf/pfcmd/help.pm',
    '/usr/local/pf/lib/pf/pfcmd/pfcmd.pm',
    '/usr/local/pf/lib/pf/pfcmd.pm',
    '/usr/local/pf/lib/pf/pfcmd/report.pm',
    '/usr/local/pf/lib/pf/radius.pm',
    '/usr/local/pf/lib/pf/radius/constants.pm',
    '/usr/local/pf/lib/pf/radius/custom.pm',
    '/usr/local/pf/lib/pf/rawip.pm',
    '/usr/local/pf/lib/pf/scan.pm',
    '/usr/local/pf/lib/pf/schedule.pm',
    '/usr/local/pf/lib/pf/services.pm',
    '/usr/local/pf/lib/pf/services/apache.pm',
    '/usr/local/pf/lib/pf/services/dhcpd.pm',
    '/usr/local/pf/lib/pf/services/named.pm',
    '/usr/local/pf/lib/pf/SwitchFactory.pm',
    '/usr/local/pf/lib/pf/switchlocation.pm',
    '/usr/local/pf/lib/pf/temporary_password.pm',
    '/usr/local/pf/lib/pf/traplog.pm',
    '/usr/local/pf/lib/pf/trigger.pm',
    '/usr/local/pf/lib/pf/useragent.pm',
    '/usr/local/pf/lib/pf/util.pm',
    '/usr/local/pf/lib/pf/violation.pm',
    '/usr/local/pf/lib/pf/vlan/custom.pm',
    '/usr/local/pf/lib/pf/vlan.pm',
    '/usr/local/pf/lib/pf/web.pm',
    '/usr/local/pf/lib/pf/web/backend_modperl_require.pl',
    '/usr/local/pf/lib/pf/web/captiveportal_modperl_require.pl',
    '/usr/local/pf/lib/pf/web/custom.pm',
    '/usr/local/pf/lib/pf/web/guest.pm',
    '/usr/local/pf/lib/pf/web/util.pm',
    '/usr/local/pf/lib/pf/web/wispr.pm',
    '/usr/local/pf/lib/pf/WebAPI.pm',
    '/usr/local/pf/sbin/pfdetect',
    '/usr/local/pf/sbin/pfdhcplistener',
    '/usr/local/pf/sbin/pfmon',
    '/usr/local/pf/sbin/pfredirect',
    '/usr/local/pf/sbin/pfsetvlan',
);

push(@files, TestUtils::get_networkdevices_modules());

# all files + no warnings
plan tests => scalar @files * 1 + 1;

foreach my $currentFile (@files) {
    critic_ok($currentFile);
}

=head1 AUTHOR

Dominik Ghel <dghel@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>
        
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

