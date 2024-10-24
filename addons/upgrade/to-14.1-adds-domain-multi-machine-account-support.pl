#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-14.1-adds-domain-multi-machine-account-support.pl

=cut

=head1 DESCRIPTION

adds a new field to domain.conf to tell PacketFence how many additional machine account are created and available to do NTLM authentication.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($domain_config_file);

my $ini = pf::IniFiles->new(-file => $domain_config_file, -allowempty => 1);

unless (defined $ini) {
    print("Error loading domain config file. Terminated. Try re-run this script or edit domain settings in admin UI manually. /\n");
    exit;
}

my $updated = 0;

for my $section (grep {/^\S+/} $ini->Sections()) {
    print("Processing section '$section' in domain.conf: ");
    if ($section =~ /^[a-zA-Z0-9\-\._]+ [a-zA-Z0-9]+$/) {
        if ($ini->exists($section, 'additional_machine_accounts')) {
            print("already up to date. skipped.\n")
        }
        else {
            $ini->newval($section, 'additional_machine_accounts', 0);
            $updated = 1;
            print("done\n")
        }
    }
}

if ($updated == 1) {
    $ini->RewriteConfig();
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

