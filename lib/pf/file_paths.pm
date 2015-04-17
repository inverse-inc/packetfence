package pf::file_paths;

=head1 NAME

pf::file_paths add documentation

=cut

=head1 DESCRIPTION

pf::file_paths

file paths for PacketFence
These will re-exported in pf::config

=cut

use strict;
use warnings;
use File::Spec::Functions;


our (
    #Directories
    $install_dir, $bin_dir, $conf_dir, $lib_dir, $html_dir, $cert_dir, $log_dir, $generated_conf_dir, $var_dir,
    $tt_compile_cache_dir, $pfconfig_cache_dir, $domains_chroot_dir,

    #Config files
    #pf.conf.default
    $default_config_file, $pf_default_file,
    #pf.conf
    $config_file, $pf_config_file,
    #network.conf
    $network_config_file,
    #oauth2-ips.conf
    $oauth_ip_file,
    #documentation.conf variables
    $pf_doc_file,
    #floating_network_device.conf variables
    $floating_devices_config_file,
    #dhcp_fingerprints.conf variables
    $dhcp_fingerprints_file, $dhcp_fingerprints_url,
    #oui.txt variables
    $oui_file, $oui_url,
    #profiles.conf variables
    $profiles_config_file, %Profiles_Config,
    #Other configuraton files variables
    $switches_config_file, $violations_config_file, $authentication_config_file,
    $chi_config_file, $ui_config_file, $floating_devices_file, $log_config_file,
    @stored_config_files, @log_files,
    $provisioning_config_file,
    $admin_roles_config_file,
    $wrix_config_file,
    $firewall_sso_config_file,
    $allowed_device_oui_file, $allowed_device_types_file,
    $apache_filters_config_file,
    $cache_control_file,
    $log_conf_dir,
    $vlan_filters_config_file,
    $pfcmd_binary,
    $realm_config_file,
    $cluster_config_file,
    $server_cert, $server_key, $server_pem,
    $domain_config_file,
    $scan_config_file,
    $wmi_config_file,
    $pki_provider_config_file
);

BEGIN {

    *config_file = \$pf_config_file; # TODO: To be deprecated. See $pf_config_file
    *default_config_file = \$pf_default_file;  # TODO: To be deprecated. See $pf_default_file
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # Categorized by feature, pay attention when modifying
    @EXPORT = qw(
        $install_dir $bin_dir $conf_dir $lib_dir $html_dir $cert_dir $log_dir $generated_conf_dir $var_dir
        $tt_compile_cache_dir $pfconfig_cache_dir $domains_chroot_dir
        $default_config_file $pf_default_file
        $config_file $pf_config_file
        $network_config_file
        $oauth_ip_file
        $pf_doc_file
        $floating_devices_config_file
        $dhcp_fingerprints_file $dhcp_fingerprints_url
        $oui_file $oui_url
        $profiles_config_file %Profiles_Config
        $switches_config_file $violations_config_file $authentication_config_file
        $chi_config_file $ui_config_file $floating_devices_file $log_config_file
        @stored_config_files @log_files
        $provisioning_config_file
        $admin_roles_config_file
        $wrix_config_file
        @stored_config_files
        $firewall_sso_config_file
        $allowed_device_oui_file $allowed_device_types_file
        $apache_filters_config_file
        $cache_control_file
        $log_conf_dir
        $vlan_filters_config_file
        $pfcmd_binary
        $realm_config_file
        $cluster_config_file
        $server_cert $server_key $server_pem
        $domain_config_file
        $scan_config_file
        $wmi_config_file
        $pki_provider_config_file
    );
}

$install_dir = '/usr/local/pf';

# TODO bug#920 all application config data should use Readonly to avoid accidental post-startup alterration
$bin_dir  = catdir( $install_dir,"bin" );
$conf_dir = catdir( $install_dir,"conf" );
$var_dir  = catdir( $install_dir,"var" );
$lib_dir  = catdir( $install_dir,"lib" );
$html_dir = catdir( $install_dir,"html" );
$log_dir  = catdir( $install_dir,"logs" );
$log_conf_dir  = catdir( $conf_dir,"log.conf.d" );

$generated_conf_dir   = catdir( $var_dir,"conf");
$tt_compile_cache_dir = catdir( $var_dir,"tt_compile_cache");
$pfconfig_cache_dir = catdir( $var_dir,"cache/pfconfig");
$domains_chroot_dir = catdir( "/chroots");

$pfcmd_binary   = catfile($bin_dir, "pfcmd");

$oui_file        = catfile($conf_dir, "oui.txt");
$pf_doc_file     = catfile($conf_dir, "documentation.conf");
$oauth_ip_file   = catfile($conf_dir, "oauth2-ips.conf");
$ui_config_file  = catfile($conf_dir, "ui.conf");
$pf_config_file  = catfile($conf_dir, "pf.conf"); # TODO: Adjust. See $config_file
$pf_default_file = catfile($conf_dir, "pf.conf.defaults"); # TODO: Adjust. See $default_config_file
$chi_config_file = catfile($conf_dir, "chi.conf");
$log_config_file = catfile($conf_dir, "log.conf");
$provisioning_config_file = catfile($conf_dir, 'provisioning.conf');
$pki_provider_config_file  = catfile($conf_dir,"pki_provider.conf");

$network_config_file    = catfile($conf_dir, "networks.conf");
$switches_config_file   = catfile($conf_dir, "switches.conf");
$profiles_config_file   = catfile($conf_dir, "profiles.conf");
$floating_devices_file  = catfile($conf_dir, "floating_network_device.conf");  # TODO: To be deprecated. See $floating_devices_config_file
$violations_config_file = catfile($conf_dir, "violations.conf");
$dhcp_fingerprints_file = catfile($conf_dir, "dhcp_fingerprints.conf");
$admin_roles_config_file = catfile($conf_dir, "adminroles.conf");

$violations_config_file       = catfile($conf_dir, "violations.conf");
$authentication_config_file   = catfile($conf_dir, "authentication.conf");
$floating_devices_config_file = catfile($conf_dir, "floating_network_device.conf"); # TODO: Adjust to /floating_devices.conf when $floating_devices_file will be deprecated
$wrix_config_file = catfile($conf_dir, "wrix.conf");
$allowed_device_oui_file   = catfile($conf_dir,"allowed_device_oui.txt");
$allowed_device_types_file = catfile($conf_dir,"allowed_device_types.txt");
$apache_filters_config_file = catfile($conf_dir, "apache_filters.conf");
$vlan_filters_config_file = catfile($conf_dir, "vlan_filters.conf");
$firewall_sso_config_file =  catfile($conf_dir,"firewall_sso.conf");
$realm_config_file = catfile($conf_dir,"realm.conf");
$cluster_config_file = catfile($conf_dir,"cluster.conf");
$server_key = catfile($conf_dir,"ssl/server.key");
$server_cert = catfile($conf_dir,"ssl/server.crt");
$server_pem = catfile($conf_dir,"ssl/server.pem");
$domain_config_file = catfile($conf_dir,"domain.conf");
$scan_config_file = catfile($conf_dir,"scan.conf");
$wmi_config_file = catfile($conf_dir,"wmi.conf");

$oui_url               = 'http://standards.ieee.org/regauth/oui/oui.txt';
$dhcp_fingerprints_url = 'http://www.packetfence.org/dhcp_fingerprints.conf';

$cert_dir = catdir( $html_dir, "captive-portal/certs");

@log_files = map {catfile($log_dir, $_)}
  qw(
  httpd.admin.access httpd.admin.catalyst httpd.admin.error httpd.admin.log
  httpd.portal.access httpd.admin.error httpd.portal.catalyst httpd.portal.log
  httpd.proxy.access httpd.proxy.error httpd.proxy.log
  httpd.proxy.reverse.access httpd.proxy.reverse.error
  httpd.webservices.access httpd.webservices.error
  packetfence.log pfbandwidthd.log pfdetect.log
  pfdhcplistener.log pfdns.log pfmon.log pfconfig.log
);

@stored_config_files = (
    $pf_config_file, $network_config_file,
    $switches_config_file, $violations_config_file,
    $authentication_config_file, $floating_devices_config_file,
    $dhcp_fingerprints_file, $profiles_config_file,
    $oui_file, $floating_devices_file,
    $chi_config_file,$allowed_device_oui_file,$allowed_device_types_file,
    $ui_config_file,$provisioning_config_file,$oauth_ip_file,$log_config_file,
    $admin_roles_config_file,$wrix_config_file,$apache_filters_config_file,
    $vlan_filters_config_file,$firewall_sso_config_file,$scan_config_file,
    $wmi_config_file,
    $pki_provider_config_file,
);


$cache_control_file = catfile($var_dir, "cache_control");


=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

1;

