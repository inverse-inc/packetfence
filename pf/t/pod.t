#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::Pod;
use Test::More tests => 596;

my @files = (
    '/usr/local/pf/addons/accounting.pl',
    '/usr/local/pf/addons/autodiscover.pl',
    '/usr/local/pf/addons/connect_and_read.pl',
    '/usr/local/pf/addons/convertToPortSecurity.pl',
    '/usr/local/pf/addons/dhcp_dumper',
    '/usr/local/pf/addons/monitorpfsetvlan.pl',
    '/usr/local/pf/addons/recovery.pl',
    '/usr/local/pf/addons/802.1X/packetfence.pm',
    '/usr/local/pf/addons/mrtg/mrtg-wrapper.pl',
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
    '/usr/local/pf/lib/pf/iplog.pm',
    '/usr/local/pf/lib/pf/import.pm',
    '/usr/local/pf/lib/pf/iptables.pm',
    '/usr/local/pf/lib/pf/locationlog.pm',
    '/usr/local/pf/lib/pf/lookup/node.pm',
    '/usr/local/pf/lib/pf/lookup/person.pm',
    '/usr/local/pf/lib/pf/mod_perl_require.pl',
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
    '/usr/local/pf/lib/pf/radius.pm',
    '/usr/local/pf/lib/pf/radius/constants.pm',
    '/usr/local/pf/lib/pf/radius/custom.pm',
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
    '/usr/local/pf/lib/pf/WebAPI.pm',
    '/usr/local/pf/sbin/pfdetect',
    '/usr/local/pf/sbin/pfdhcplistener',
    '/usr/local/pf/sbin/pfmon',
    '/usr/local/pf/sbin/pfredirect',
    '/usr/local/pf/sbin/pfsetvlan',
);

foreach my $currentFile (@files) {
    my $shortname = $1 if ($currentFile =~ m'^/usr/local/pf/(.+)$');
    pod_file_ok($currentFile, "${shortname}'s POD is valid");
}

# PacketFence module POD
# for now NAME, AUTHOR, COPYRIGHT
# TODO expect NAME, SYNOPSIS, DESCRIPTION, AUTHOR, COPYRIGHT, LICENSE
# TODO port to perl module: http://search.cpan.org/~mkutter/Test-Pod-Content-0.0.5/
my @pf_general_pod = qw(NAME AUTHOR COPYRIGHT);
foreach my $currentFile (@files) {
    my $shortname = $1 if ($currentFile =~ m'^/usr/local/pf/(.+)$');

    # TODO extract in a method if I re-use

    # basically it extracts <name> out of a perl file POD's =head* <name>
    # "perl -l00n" comes from the POD section of the camel book, not so sure what it does
    my $cmd = "cat $currentFile | perl -l00n -e 'print \"\$1\\n\" if /^=head\\d\\s+(\\w+)/;'";
    my $result = `$cmd`;
    $result =~ s/\c@//g; # I had these weird control-chars in my string
    my @pod_headers = split("\n", $result);
    chomp @pod_headers; # discards last element if it's a newline

    foreach my $pf_expected_header (@pf_general_pod) {
        # TODO performance could be improved if I qr// the regexp (see perlop)
        ok(grep(/^$pf_expected_header$/, @pod_headers), "$shortname POD doc section $pf_expected_header exists");
    }
}

# TODO switch module POD
# expect bugs and limitations, status, ...

# TODO CLI perl
# expect USAGE

# TODO PacketFence core
# # expect SUBROUTINES
