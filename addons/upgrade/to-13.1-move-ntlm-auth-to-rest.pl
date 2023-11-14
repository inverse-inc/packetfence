#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-10.1-move-radius-configuration-parameter.pl

=cut

=head1 DESCRIPTION

Move radius configuration parameters to associated new files

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($authentication_config_file $domain_config_file);
use pf::util;

my $ini = pf::IniFiles->new(-file => $domain_config_file, -allowempty => 1);

unless ($ini) {
    exit;
}

my $updated = 0;
for my $section (grep {/^\S+$/} $ini->Sections()) {

    if (($ini->exists($section, 'machine_account')) || ($ini->exists($section, 'machine_account_password'))) {
        print("Section: ", $section, " already has machine_account and machine_account_password set. skipped\n");
        next;
    }

    my $samba_conf_path = "/chroots/$section/etc/samba/$section.conf";
    my $samba_ini = pf::IniFiles->new(-file => $samba_conf_path, -allowempty => 1);
    unless ($samba_ini) {
        print("unable to find correspond samba conf file in $samba_conf_path, terminated\n");
        exit;
    }

    my $dns_name = $ini->val($section, "dns_name");
    my $work_group = $samba_ini->val("global", "workgroup");
    my $realm = $samba_ini->val("global", "realm");

    print("---- section: $section\n");
    print("---- dns name is: $dns_name \n");
    print("---- work_group is: $work_group\n");
    print("---- realm is: $realm\n");

    # the tdb file should be located at /var/lib/samba/secrets.tdb, but here we use cache instead
    my $secret_tdb_file = "/chroots/$section/var/cache/samba/secrets.tdb";
    print("---- tdb file is located in: $secret_tdb_file \n");

    my $exit_code = 0;

    # extract machine account from tdb file
    my $machine_account_key = "SECRETS/SALTING_PRINCIPAL/DES/$dns_name";
    my $tdb_secret_host_value;
    ($exit_code, $tdb_secret_host_value) = tdbdump_get_value("/chroots/$section/var/cache/samba/secrets.tdb", $machine_account_key);
    if ($exit_code == 0 && $tdb_secret_host_value ne "") {
        my $machine_account = extract_machine_account($tdb_secret_host_value, $dns_name);
        if ($machine_account ne "") {
            print("  ---- machine_account is: $machine_account\n");
        }
    }

    # extract machine account password from tdb file
    my $machine_account_password_key = "SECRETS/MACHINE_PASSWORD/$work_group";
    my $tdb_secret_machine_password_value;
    ($exit_code, $tdb_secret_machine_password_value) = tdbdump_get_value("/chroots/$section/var/cache/samba/secrets.tdb", $machine_account_password_key);
    if ($exit_code == 0 && $tdb_secret_machine_password_value ne "") {

        $tdb_secret_machine_password_value = $tdb_secret_machine_password_value;
        ($exit_code, my $machine_password) = extract_machine_password($tdb_secret_machine_password_value);

    }


    if (!$ini->exists($section, 'server_name')) {
        my $machine_account = getServerName $section;
        ini->newval($section, 'server_name', $samba_server_name);
        $updated |= 1;
    }

    if (!$ini->exists($section, 'username')) {
        my $machine_account = getMachineAccount $section;
        ini->newval($section, 'username', $machine_account);
        $updated |= 1;
    }
    if (!$ini->exists($section, 'password')) {
        my $password = getMachineAccountPassword $section;
        ini->newval($section, 'password', $password);
        $updated |= 1;
    }
}

if ($updated) {
    $ini->RewriteConfig();
}

sub tdbdump_get_value {
    my ($tdb_file, $key) = @_;
    my $cmd = "/usr/bin/tdbdump $tdb_file -k $key";

    my $result = qx($cmd);
    my $exit_code = $? >> 8;

    return $exit_code, $result;
}

sub extract_machine_account {
    my ($tdb_secret_host_string, $dns_name) = @_;

    if ($tdb_secret_host_string =~ /^host\/(.*?)@(.*?)\\00$/i) {
        my $hostname = $1;
        my $domain = $2;

        if ($hostname =~ /^(.*?)\.$domain/i) {
            return $1 . '$';
        }
    }
    else {
        return "";
    }
}

sub extract_machine_password {
    my ($raw_password) = @_;

    my $replace_cmd = "sed s/\\\\00//g| sed 's/\\\\//g'";
    my $decrypt_cmd = 'import hashlib,binascii,sys;input=sys.stdin.read().strip();print(binascii.hexlify(hashlib.new("md4",binascii.unhexlify(input.replace("\\\", "").replace("\00","")).decode("utf-8").encode("utf-16le")).digest()))';
    my $cmd = "echo -n '$raw_password'| $replace_cmd| python -c '$decrypt_cmd'";

    my $result = qx($cmd);
    my $exit_code = $? >> 8;
    my $password = "";
    if ($exit_code != 0 && $result ne "") {
        if ($result =~ /b'([a-f0-9]+)'/) {
            $password = $1;
        }
    }
    return $exit_code, $password;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2023 Inverse inc.

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

