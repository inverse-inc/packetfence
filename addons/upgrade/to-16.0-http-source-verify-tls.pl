#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-16.0-http-source-verify-tls.pl

=cut

=head1 DESCRIPTION

HTTP sources created before the Verify TLS option existed did not verify the
certificate of the API server. The admin form defaults the option to enabled,
so saving such a source would silently turn verification on. Write
verify_tls=disabled in each existing HTTP source to keep its behavior.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($authentication_config_file);
use pf::util;
run_as_pf();

exit 0 unless -e $authentication_config_file;

my $ini = pf::IniFiles->new(-file => $authentication_config_file, -allowempty => 1);
unless (defined $ini) {
    print("Error loading $authentication_config_file. Add verify_tls=disabled manually in each HTTP source.\n");
    exit 1;
}

my $updated = 0;
for my $section ($ini->Sections()) {
    next if $section =~ / /;
    my $type = $ini->val($section, 'type');
    next unless defined($type) && $type eq 'HTTP';
    next if defined $ini->val($section, 'verify_tls');
    $ini->newval($section, 'verify_tls', 'disabled');
    print("HTTP source '$section': verify_tls set to disabled\n");
    $updated = 1;
}

if ($updated) {
    $ini->RewriteConfig();
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

