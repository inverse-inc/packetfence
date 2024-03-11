#!/usr/bin/perl

=head1 NAME

to-11.1-cleanup-ntlm-cache-batch-fields.pl

=head1 DESCRIPTION

Remove fields related to NTLM background cache from domain.conf

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw(
    $domain_config_file
);

my ($login,$pass,$uid,$gid) = getpwnam('pf');
chown $uid, $gid, $domain_config_file;

use pf::util;
run_as_pf();

my $ini = pf::IniFiles->new(-file => $domain_config_file, -allowempty => 1);

my @deprecated_fields = (
  "ntlm_cache_on_connection",
  "ntlm_cache_batch_one_at_a_time",
  "ntlm_cache_batch",
  "ntlm_cache_filter",  
);

my $changed = 0;

for my $section (grep { !/\s/  } $ini->Sections()) {
    for my $field (@deprecated_fields) {
        if ($ini->exists($section, $field)) {
            $changed |= 1;
            $ini->delval($section, $field);
            print "Deleted deprecated field '$field' from domain '$section'\n" 
        }
    }
}

if ($changed) {
    $ini->RewriteConfig();
    print "All done\n";
} else {
    print "Nothing to be done\n";
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



# ntlm_cache_on_connection
# ntlm_cache_batch_one_at_a_time
# ntlm_cache_batch
# ntlm_cache_filter
