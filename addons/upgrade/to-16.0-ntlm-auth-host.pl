#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-16.0-ntlm-auth-host.pl

=cut

=head1 DESCRIPTION

Domains joined before 15.1 have ntlm_auth_host=127.0.0.1 in domain.conf.
The NTLM auth API is reached from containers (api-frontend), where the
loopback is the container itself, so replace it with
containers-gateway.internal like the domains joined since 15.1.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($domain_config_file);
use pf::util;
run_as_pf();

my $new_host = 'containers-gateway.internal';

exit 0 unless -e $domain_config_file;

my $ini = pf::IniFiles->new(-file => $domain_config_file, -allowempty => 1);
unless (defined $ini) {
    print("Error loading $domain_config_file. Replace ntlm_auth_host=127.0.0.1 with ntlm_auth_host=$new_host manually in each domain.\n");
    exit 1;
}

my $updated = 0;
for my $section ($ini->Sections()) {
    next if isenabled($ini->val($section, 'use_connector'));
    my $host = $ini->val($section, 'ntlm_auth_host');
    next unless defined($host) && $host =~ /^\s*(127\.0\.0\.1|localhost|::1)\s*$/i;
    $ini->setval($section, 'ntlm_auth_host', $new_host);
    print("Domain '$section': ntlm_auth_host changed from $host to $new_host\n");
    $updated = 1;
}

if ($updated) {
    $ini->RewriteConfig();
    print("Restart packetfence-ntlm-auth-api for the change to take effect\n");
}
else {
    print("Nothing to do\n");
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
