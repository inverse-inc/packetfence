#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-13.1-move-ntlm-auth-to-rest.pl

=cut

=head1 DESCRIPTION

Modify domain.conf to work with new NTLM auth API.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($authentication_config_file $domain_config_file);
use pf::util;
use pf::cluster qw($cluster_enabled $host_id);
use Digest::MD4;
use Encode;
use MIME::Base64;
use Socket;
use Sys::Hostname;

my $ini = pf::IniFiles->new(-file => $domain_config_file, -allowempty => 1);

unless (defined $ini) {
    print("Error loading domain config file. Terminated. Try re-run this script or edit domain settings in admin UI manually. /\n");
    exit;
}

my $updated = 0;
my $ntlm_auth_host = "100.64.0.1";
my $ntlm_auth_port = 4999;

my $tmp = pf_run("date +%Y%m%d_%H%M%S");
$tmp =~ s/^\s+|\s+$//g;

my $domain_bk="/usr/local/pf/conf/domain.conf_".$tmp."_bk";
my $realm_bk="/usr/local/pf/conf/realm.conf_".$tmp."_bk";
pf_run("cp -R /usr/local/pf/conf/domain.conf $domain_bk");
pf_run("cp -R /usr/local/pf/conf/realm.conf $realm_bk");

for my $section (grep {/^\S+$/} $ini->Sections()) {
    print("Updating config for section: $section\n");
    $ntlm_auth_port += 1;

    if ($ini->exists($section, 'machine_account_password')) {
        print("  Section: ", $section, " already has machine_account_password. section $section skipped.\n");
        next;
    }

    my $samba_conf_path = "/etc/samba/$section.conf";
    unless (-e $samba_conf_path) {
        print("  $samba_conf_path not found, skipped. If $section is a domain in use, you need to reconfigure it in admin UI\n");
        next;
    }

    my $samba_ini = pf::IniFiles->new(-file => $samba_conf_path, -allowempty => 1);
    unless (defined $samba_ini) {
        print("  Unable to find corresponding Samba configuration file in $samba_conf_path, section $section skipped. If $section is a domain in use, you need to reconfigure it in admin UI\n");
        next;
    }

    my $dns_name = $ini->val($section, "dns_name");
    my $work_group = $samba_ini->val("global", "workgroup");
    my $realm = $samba_ini->val("global", "realm");

    my $ad_server = $ini->val($section, "ad_server");
    my $dns_servers = $ini->val($section, "dns_servers");
    my $ad_fqdn = $ini->val($section, "ad_fqdn");
    my $samba_server_name = $samba_ini->val("global", "server string");

    if ($cluster_enabled) {
        if ($samba_server_name ne $host_id) {
            print("  In a cluster mode the Samba server ($samba_server_name) name needs to match the hostname of the server ($host_id)\n");
            print("  The configuration will be migrated but the server name in the domain configuration will be replaced by %h (the return of the hostname command)\n");
            print("  You have to manually rejoin the server to the domain from the Admin UI in Configuration -> Policies and Access Control -> Active Directory Domains\n");
            print("  By editing the domain configuration, fill in the domain administrator username and password, and save the configuration.\n");
            $ini->setval($section, 'server_name', "%h");
        }
        my $parsedPh = parsePh();
        print("  This node will use %h (parsed as '$parsedPh' as machine account, Samba was using '$samba_server_name')\n");
        print("  You may need to change the hostname of this node if \n");
        print("    1) two or more nodes in the cluster will return with same value for '%h' ('$parsedPh' for this node), we will use the first word of the hostname splitting by '.'.\n");
        if ($samba_server_name ne $host_id) {
            print("    2) Samba was not using cluster's 'host_id' as server name. Samba server name is: '$samba_server_name', host_id is: '$host_id'\n");
        }
    }
    if (!defined($ad_fqdn) || $ad_fqdn eq "") {
        if (valid_ip($ad_server)) {
            print("  Trying to resolve '$ad_server' to a fqdn ");
            my $ad_fqdn_from_system = gethostbyaddr(inet_aton($ad_server), AF_INET);
            if (defined($ad_fqdn_from_system) && $ad_fqdn_from_system ne "") {
                $ad_fqdn = $ad_fqdn_from_system;
            }
            else {
                print("Got nothing. You need to input the AD's FQDN manually here (Run hostname command on the AD server): ");
                $ad_fqdn = <STDIN>;
                chomp($ad_fqdn);
                $ad_fqdn=~ s/^\s+|\s+$//g;
            }
            print("  Verify that the fqdn matches with the ip\n");
            my ($ad_fqdn_from_dns, $ip, $msg) = pf::util::dns_resolve($ad_fqdn, $dns_servers);
            if (defined($ip) && ($ip ne $ad_server)) {
                print("  The dns resolution of the fqdn '$ad_fqdn' does not match with the ip of the ad server '$ad_server', the dns returned $ip\n");
                print("  Unable to use the AD fqdn. Section $section skipped. If $section is a domain in use, you need to reconfigure it in admin UI\n");
                next;
            } elsif (!defined($ip)) {
                print("  The dns resolution of the fqdn '$ad_fqdn' does not returned any ip address\n");
                print("  Unable to use the AD fqdn. Section $section skipped. If $section is a domain in use, you need to reconfigure it in admin UI\n");
                next;
            } else {
                print("  The dns resolution of the fqdn '$ad_fqdn' match with the ip of the ad server '$ad_server', the dns returned $ip, continue ...\n");
            }
        }
        else {
            $ad_fqdn = $ad_server;
            my ($h, $ip_from_dns, $msg) = pf::util::dns_resolve($ad_fqdn, $dns_servers, $dns_name);
            if (defined($ip_from_dns) && $ip_from_dns ne "") {
                $ad_server = $ip_from_dns;
            }
            else {
                my $packed_ip = gethostbyname($ad_fqdn);
                if (defined $packed_ip) {
                    $ad_server = inet_ntoa($packed_ip);
                }
                else {
                    print("  Failed to resolve FQDN: '$ad_fqdn', Please check your DNS/network config\n")
                }
            }
        }
    }

    unless (defined($dns_name) && $dns_name ne "") {
        print("  Unable to retrieve dns_name from config file. Section $section skipped. If $section is a domain in use, you need to reconfigure it in admin UI \n");
        next;
    }
    unless (defined($work_group) && $work_group ne "") {
        print("  Unable to retrieve work_group from config file. Section $section skipped. If $section is a domain in use, you need to reconfigure it in admin UI\n");
        next;
    }


    # the tdb file should be located at /var/lib/samba/secrets.tdb, but here we use cache instead
    my $secret_tdb_file = "/chroots/$section/var/cache/samba/secrets.tdb";

    my $exit_code = 0;

    # extract machine account from tdb file
    my $machine_account = "";
    my $machine_account_key = uc("SECRETS/SALTING_PRINCIPAL/DES/$dns_name");
    my $tdb_secret_host_value;
    ($exit_code, $tdb_secret_host_value) = tdbdump_get_value("/chroots/$section/var/cache/samba/secrets.tdb", $machine_account_key);
    if ($exit_code == 0 && $tdb_secret_host_value ne "") {
        $machine_account = extract_machine_account($tdb_secret_host_value);
    }
    else {
        print("  Unable to retrieve machine account from tdb file. Please check samba tdb database. Section $section Skipped\n");
        next;
    }

    # extract machine account password from tdb file
    my $machine_password = "";
    my $machine_account_password_key = uc("SECRETS/MACHINE_PASSWORD/$work_group");
    my $tdb_secret_machine_password_value;

    ($exit_code, $tdb_secret_machine_password_value) = tdbdump_get_value("/chroots/$section/var/cache/samba/secrets.tdb", $machine_account_password_key);

    if ($exit_code == 0 && $tdb_secret_machine_password_value ne "") {
        $machine_password = extract_machine_password($tdb_secret_machine_password_value);
    }
    else {
        print("  Unable to retrieve machine account password from tdb file. Please check samba tdb database. Section $section Skipped. If $section is a domain in use, you need to reconfigure it in admin UI\n");
        next;
    }

    my $server_name = $ini->val($section, 'server_name');
    if ((lc($server_name) ne lc($machine_account)) && $server_name ne "%h") {
        print("  Unable to rewrite server_name values, current value is: $server_name, expected is: $machine_account, Section $section Skipped. If $section is a domain in use, you need to reconfigure it in admin UI\n");
        next;
    }

    if (!$ini->exists($section, 'machine_account_password')) {
        $ini->newval($section, 'machine_account_password', $machine_password);
        $ini->newval($section, 'password_is_nt_hash', '1');
        $ini->newval($section, 'ntlm_auth_host', $ntlm_auth_host);
        $ini->newval($section, 'ntlm_auth_port', $ntlm_auth_port);
        $ini->newval($section, 'ad_fqdn', $ad_fqdn);
        $ini->setval($section, 'ad_server', $ad_server);
        $updated |= 1;
    }
}

if ($updated) {
    $ini->RewriteConfig();
}

print("Stopping winbindd\n");
pf_run("sudo systemctl stop packetfence-winbindd 2>/dev/null");
sleep(3);
pf_run("sudo systemctl disable packetfence-winbindd 2>/dev/null");
print("/chroots/* directories will be removed at the next reboot.\n");
print("Domain config backup is available here $domain_bk\n");
print("Realm  config backup is available here $realm_bk\n");

####
# Sub functions
####

sub tdbdump_get_value {
    my ($tdb_file, $key) = @_;
    my $cmd = "/usr/bin/tdbdump $tdb_file -k $key";

    my $result = qx($cmd);
    my $exit_code = $? >> 8;

    return $exit_code, $result;
}

sub extract_machine_account {
    my ($tdb_secret_host_string) = @_;
    if ($tdb_secret_host_string =~ /^host\/(.*?)@(.*?)\\00$/i) {
        my $hostname = $1;
        my $domain = $2;

        # this is a double check to make sure we have valid machine FQDN
        if ($hostname =~ /^(.*?)\.$domain/i) {
            return $1;
        }
    }
    return "";
}

sub extract_machine_password {
    my ($raw_password) = @_;

    chomp($raw_password);
    $raw_password =~ s/\\00//g;
    $raw_password =~ s/\\//g;
    $raw_password =~ s/\\//g;

    my $bin_data = encode("UTF-16le", decode("UTF-8", pack("H*", $raw_password)));

    my $md4 = Digest::MD4->new;
    $md4->add($bin_data);
    my $hash = $md4->digest;

    return (unpack("H*", $hash));
}

sub parsePh {
    my $real_computer_name = hostname();
    my @s = split(/\./, $real_computer_name);
    return $s[0];
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

