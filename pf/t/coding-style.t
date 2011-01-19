#!/usr/bin/perl
=head1 NAME

coding-style.t

=head1 DESCRIPTION

Test validating coding style guidelines.

=cut
use strict;
use warnings;
use diagnostics;

use Test::More tests => 224;

# TODO we should have a global file list
my @files = (
    '/usr/local/pf/addons/802.1X/packetfence.pm',
    '/usr/local/pf/addons/accounting.pl',
    '/usr/local/pf/addons/autodiscover.pl',
    '/usr/local/pf/addons/connect_and_read.pl',
    '/usr/local/pf/addons/convertToPortSecurity.pl',
    '/usr/local/pf/addons/dhcp_dumper',
    '/usr/local/pf/addons/monitorpfsetvlan.pl',
    '/usr/local/pf/addons/mrtg/mrtg-wrapper.pl',
    '/usr/local/pf/addons/recovery.pl',
    '/usr/local/pf/bin/flip.pl',
    '/usr/local/pf/bin/pfcmd',
    '/usr/local/pf/bin/pfcmd_vlan',
    '/usr/local/pf/cgi-bin/redir.cgi',
    '/usr/local/pf/cgi-bin/release.cgi',
    '/usr/local/pf/cgi-bin/register.cgi',
    '/usr/local/pf/conf/authentication/ldap.pm',
    '/usr/local/pf/conf/authentication/local.pm',
    '/usr/local/pf/conf/authentication/radius.pm',
    '/usr/local/pf/lib/pf/action.pm',
    '/usr/local/pf/lib/pf/class.pm',
    '/usr/local/pf/lib/pf/configfile.pm',
    '/usr/local/pf/lib/pf/config.pm',
    '/usr/local/pf/lib/pf/db.pm',
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
    '/usr/local/pf/lib/pf/pfcmd/dashboard.pm',
    '/usr/local/pf/lib/pf/pfcmd/graph.pm',
    '/usr/local/pf/lib/pf/pfcmd/help.pm',
    '/usr/local/pf/lib/pf/pfcmd/pfcmd.pm',
    '/usr/local/pf/lib/pf/pfcmd.pm',
    '/usr/local/pf/lib/pf/pfcmd/report.pm',
    '/usr/local/pf/lib/pf/rawip.pm',
    '/usr/local/pf/lib/pf/scan.pm',
    '/usr/local/pf/lib/pf/schedule.pm',
    '/usr/local/pf/lib/pf/services.pm',
    '/usr/local/pf/lib/pf/services/apache.pm',
    '/usr/local/pf/lib/pf/SNMP/Accton/ES3526XA.pm',
    '/usr/local/pf/lib/pf/SNMP/Accton/ES3528M.pm',
    '/usr/local/pf/lib/pf/SNMP/Accton.pm',
    '/usr/local/pf/lib/pf/SNMP/Amer.pm',
    '/usr/local/pf/lib/pf/SNMP/Amer/SS2R24i.pm',
    '/usr/local/pf/lib/pf/SNMP/Aruba/Controller_200.pm',
    '/usr/local/pf/lib/pf/SNMP/Aruba.pm',
    '/usr/local/pf/lib/pf/SNMP/Cisco.pm',
    '/usr/local/pf/lib/pf/SNMP/Cisco/Aironet_1130.pm',
    '/usr/local/pf/lib/pf/SNMP/Cisco/Aironet_1242.pm',
    '/usr/local/pf/lib/pf/SNMP/Cisco/Aironet_1250.pm',
    '/usr/local/pf/lib/pf/SNMP/Cisco/Aironet.pm',
    '/usr/local/pf/lib/pf/SNMP/Cisco/Catalyst_2900XL.pm',
    '/usr/local/pf/lib/pf/SNMP/Cisco/Catalyst_2950.pm',
    '/usr/local/pf/lib/pf/SNMP/Cisco/Catalyst_2960.pm',
    '/usr/local/pf/lib/pf/SNMP/Cisco/Catalyst_2970.pm',
    '/usr/local/pf/lib/pf/SNMP/Cisco/Catalyst_3500XL.pm',
    '/usr/local/pf/lib/pf/SNMP/Cisco/Catalyst_3550.pm',
    '/usr/local/pf/lib/pf/SNMP/Cisco/Catalyst_3560.pm',
    '/usr/local/pf/lib/pf/SNMP/Cisco/Catalyst_3750.pm',
    '/usr/local/pf/lib/pf/SNMP/Cisco/Catalyst_4500.pm',
    '/usr/local/pf/lib/pf/SNMP/Cisco/ISR_1800.pm',
    '/usr/local/pf/lib/pf/SNMP/Cisco/WiSM.pm',
    '/usr/local/pf/lib/pf/SNMP/Cisco/WLC_2106.pm',
    '/usr/local/pf/lib/pf/SNMP/Cisco/WLC_4400.pm',
    '/usr/local/pf/lib/pf/SNMP/constants.pm',
    '/usr/local/pf/lib/pf/SNMP/Dell.pm',
    '/usr/local/pf/lib/pf/SNMP/Dell/PowerConnect3424.pm',
    '/usr/local/pf/lib/pf/SNMP/Dlink/DES_3526.pm',
    '/usr/local/pf/lib/pf/SNMP/Dlink/DWS_3026.pm',
    '/usr/local/pf/lib/pf/SNMP/Dlink.pm',
    '/usr/local/pf/lib/pf/SNMP/Enterasys/D2.pm',
    '/usr/local/pf/lib/pf/SNMP/Enterasys/Matrix_N3.pm',
    '/usr/local/pf/lib/pf/SNMP/Enterasys.pm',
    '/usr/local/pf/lib/pf/SNMP/Enterasys/SecureStack_C2.pm',
    '/usr/local/pf/lib/pf/SNMP/Enterasys/SecureStack_C3.pm',
    '/usr/local/pf/lib/pf/SNMP/Extreme.pm',
    '/usr/local/pf/lib/pf/SNMP/Extreme/Summit.pm',
    '/usr/local/pf/lib/pf/SNMP/Extreme/Summit_X250e.pm',
    '/usr/local/pf/lib/pf/SNMP/Extricom.pm',
    '/usr/local/pf/lib/pf/SNMP/Extricom/EXSW800.pm',
    '/usr/local/pf/lib/pf/SNMP/Foundry/FastIron_4802.pm',
    '/usr/local/pf/lib/pf/SNMP/Foundry.pm',
    '/usr/local/pf/lib/pf/SNMP/HP.pm',
    '/usr/local/pf/lib/pf/SNMP/HP/Procurve_2500.pm',
    '/usr/local/pf/lib/pf/SNMP/HP/Procurve_2600.pm',
    '/usr/local/pf/lib/pf/SNMP/HP/Procurve_3400cl.pm',
    '/usr/local/pf/lib/pf/SNMP/HP/Procurve_4100.pm',
    '/usr/local/pf/lib/pf/SNMP/HP/Controller_MSM710.pm',
    '/usr/local/pf/lib/pf/SNMP/Intel/Express_460.pm',
    '/usr/local/pf/lib/pf/SNMP/Intel/Express_530.pm',
    '/usr/local/pf/lib/pf/SNMP/Intel.pm',
    '/usr/local/pf/lib/pf/SNMP/Juniper.pm',
    '/usr/local/pf/lib/pf/SNMP/Juniper/EX.pm',
    '/usr/local/pf/lib/pf/SNMP/Linksys.pm',
    '/usr/local/pf/lib/pf/SNMP/Linksys/SRW224G4.pm',
    '/usr/local/pf/lib/pf/SNMP/Meru.pm',
    '/usr/local/pf/lib/pf/SNMP/Meru/MC.pm',
    '/usr/local/pf/lib/pf/SNMP/MockedSwitch.pm',
    '/usr/local/pf/lib/pf/SNMP/Nortel/BayStack4550.pm',
    '/usr/local/pf/lib/pf/SNMP/Nortel/BayStack470.pm',
    '/usr/local/pf/lib/pf/SNMP/Nortel/BayStack5520.pm',
    '/usr/local/pf/lib/pf/SNMP/Nortel/BayStack5520Stacked.pm',
    '/usr/local/pf/lib/pf/SNMP/Nortel/BPS2000.pm',
    '/usr/local/pf/lib/pf/SNMP/Nortel/ERS2500.pm',
    '/usr/local/pf/lib/pf/SNMP/Nortel/ERS4500.pm',
    '/usr/local/pf/lib/pf/SNMP/Nortel/ES325.pm',
    '/usr/local/pf/lib/pf/SNMP/Nortel.pm',
    '/usr/local/pf/lib/pf/SNMP/PacketFence.pm',
    '/usr/local/pf/lib/pf/SNMP.pm',
    '/usr/local/pf/lib/pf/SNMP/SMC.pm',
    '/usr/local/pf/lib/pf/SNMP/SMC/TS6128L2.pm',
    '/usr/local/pf/lib/pf/SNMP/SMC/TS6224M.pm',
    '/usr/local/pf/lib/pf/SNMP/SMC/TS8800M.pm',
    '/usr/local/pf/lib/pf/SNMP/ThreeCom/NJ220.pm',
    '/usr/local/pf/lib/pf/SNMP/ThreeCom.pm',
    '/usr/local/pf/lib/pf/SNMP/ThreeCom/SS4200.pm',
    '/usr/local/pf/lib/pf/SNMP/ThreeCom/SS4500.pm',
    '/usr/local/pf/lib/pf/SNMP/ThreeCom/Switch_4200G.pm',
    '/usr/local/pf/lib/pf/SNMP/Xirrus.pm',
    '/usr/local/pf/lib/pf/SwitchFactory.pm',
    '/usr/local/pf/lib/pf/switchlocation.pm',
    '/usr/local/pf/lib/pf/traplog.pm',
    '/usr/local/pf/lib/pf/trigger.pm',
    '/usr/local/pf/lib/pf/useragent.pm',
    '/usr/local/pf/lib/pf/util.pm',
    '/usr/local/pf/lib/pf/violation.pm',
    '/usr/local/pf/lib/pf/vlan/custom.pm',
    '/usr/local/pf/lib/pf/vlan.pm',
    '/usr/local/pf/lib/pf/web.pm',
    '/usr/local/pf/lib/pf/web/custom.pm',
    '/usr/local/pf/lib/pf/web/util.pm',
    '/usr/local/pf/sbin/pfdetect',
    '/usr/local/pf/sbin/pfdhcplistener',
    '/usr/local/pf/sbin/pfmon',
    '/usr/local/pf/sbin/pfredirect',
    '/usr/local/pf/sbin/pfsetvlan',
    '/usr/local/pf/html/admin/administration/adduser.php',
    '/usr/local/pf/html/admin/administration/index.php',
    '/usr/local/pf/html/admin/administration/services.php',
    '/usr/local/pf/html/admin/administration/ui_options.php',
    '/usr/local/pf/html/admin/administration/version.php',
    '/usr/local/pf/html/admin/3rdparty/calendar/calendar.php',
    '/usr/local/pf/html/admin/check_login.php',
    '/usr/local/pf/html/admin/common.php',
    '/usr/local/pf/html/admin/common/adminperm.inc',
    '/usr/local/pf/html/admin/common/helpers.inc',
    '/usr/local/pf/html/admin/configuration/fingerprint.php',
    '/usr/local/pf/html/admin/configuration/floatingnetworkdevice_add.php',
    '/usr/local/pf/html/admin/configuration/floatingnetworkdevice_edit.php',
    '/usr/local/pf/html/admin/configuration/floatingnetworkdevice.php',
    '/usr/local/pf/html/admin/configuration/index.php',
    '/usr/local/pf/html/admin/configuration/interfaces_add.php',
    '/usr/local/pf/html/admin/configuration/interfaces_edit.php',
    '/usr/local/pf/html/admin/configuration/interfaces.php',
    '/usr/local/pf/html/admin/configuration/main.php',
    '/usr/local/pf/html/admin/configuration/more_info.php',
    '/usr/local/pf/html/admin/configuration/networks_add.php',
    '/usr/local/pf/html/admin/configuration/networks_edit.php',
    '/usr/local/pf/html/admin/configuration/networks.php',
    '/usr/local/pf/html/admin/configuration/switches_add.php',
    '/usr/local/pf/html/admin/configuration/switches_edit.php',
    '/usr/local/pf/html/admin/configuration/switches.php',
    '/usr/local/pf/html/admin/configuration/violation_add.php',
    '/usr/local/pf/html/admin/configuration/violation_edit.php',
    '/usr/local/pf/html/admin/configuration/violation.php',
    '/usr/local/pf/html/admin/exporter.php',
    '/usr/local/pf/html/admin/footer.php',
    '/usr/local/pf/html/admin/header.php',
    '/usr/local/pf/html/admin/index.php',
    '/usr/local/pf/html/admin/login.php',
    '/usr/local/pf/html/admin/node/add.php',
    '/usr/local/pf/html/admin/node/categories.php',
    '/usr/local/pf/html/admin/node/categories_add.php',
    '/usr/local/pf/html/admin/node/categories_edit.php',
    '/usr/local/pf/html/admin/node/edit.php',
    '/usr/local/pf/html/admin/node/index.php',
    '/usr/local/pf/html/admin/node/lookup.php',
    '/usr/local/pf/html/admin/node/view.php',
    '/usr/local/pf/html/admin/person/add.php',
    '/usr/local/pf/html/admin/person/edit.php',
    '/usr/local/pf/html/admin/person/index.php',
    '/usr/local/pf/html/admin/person/lookup.php',
    '/usr/local/pf/html/admin/person/view.php',
    '/usr/local/pf/html/admin/printer.php',
    '/usr/local/pf/html/admin/scan/edit.php',
    '/usr/local/pf/html/admin/scan/index.php',
    '/usr/local/pf/html/admin/scan/results.php',
    '/usr/local/pf/html/admin/scan/scan.php',
    '/usr/local/pf/html/admin/status/dashboard.php',
    '/usr/local/pf/html/admin/status/grapher.php',
    '/usr/local/pf/html/admin/status/graphs.php',
    '/usr/local/pf/html/admin/status/index.php',
    '/usr/local/pf/html/admin/status/reports.php',
    '/usr/local/pf/html/admin/status/sajax-dashboard.php',
    '/usr/local/pf/html/admin/violation/add.php',
    '/usr/local/pf/html/admin/violation/edit.php',
    '/usr/local/pf/html/admin/violation/index.php',
    '/usr/local/pf/html/admin/violation/view.php',
    '/usr/local/pf/html/user/content/index.php',
    '/usr/local/pf/html/user/content/style.php',
    '/usr/local/pf/html/user/content/violations/banned_os.php',
    '/usr/local/pf/html/user/content/violations/banned_devices.php',
    '/usr/local/pf/html/user/content/violations/darknet.php',
    '/usr/local/pf/html/user/content/violations/failed_scan.php',
    '/usr/local/pf/html/user/content/violations/generic.php',
    '/usr/local/pf/html/user/content/violations/lsass.php',
    '/usr/local/pf/html/user/content/violations/nat.php',
    '/usr/local/pf/html/user/content/violations/p2p.php',
    '/usr/local/pf/html/user/content/violations/roguedhcp.php',
    '/usr/local/pf/html/user/content/violations/scanning.php',
    '/usr/local/pf/html/user/content/violations/spam.php',
    '/usr/local/pf/html/user/content/violations/system_scan.php',
    '/usr/local/pf/html/user/content/violations/trojan.php',
    '/usr/local/pf/html/user/content/violations/zotob.php',
);

# lookout for TABS
foreach my $file (@files) {

    open(my $fh, '<', $file) or die $!;

    my $tabFound = 0;
    while (<$fh>) {
        if (/\t/) {
            $tabFound = 1;
        }
    }

    # I hate tabs!!
    ok(!$tabFound, "no tab character in $file");
}

# TODO test the tests for coding style but only if they are present
# (since they are not present in build system by default)


=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2010 Inverse inc.

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

