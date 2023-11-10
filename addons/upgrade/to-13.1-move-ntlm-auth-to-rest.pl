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
run_as_pf();

my $ini = pf::IniFiles->new(-file => $domain_config_file, -allowempty => 1);

unless ($ini) {
    exit;
}

my $updated = 0;
for my $section (grep {/^\S+$/} $ini->Sections()) {
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

sub getServerName {
    my $domain = $_[0];

    my $r = system("/usr/bin/tdbdump /chroots/$domain/var/cache/samba/gencache.tdb| grep NEG_CONN_CACHE | awk '{print $NF}' | sed s/\"//g | sed s/\00// | awk -F , '{print $NF}'");
    @r
}
sub getMachineAccount {
    my $domain = $_[0];
    my @r = readpipe("/usr/bin/tdbdump /chroots/$domain/var/cache/samba/gencache.tdb| grep 'SECRETS/SID/'| awk -F / '{print $3}' |sed s/\"//");
    $r
}
sub getMachineAccountPassword {
    my $domain = $_[0];
    my $r = "";
    $r
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

