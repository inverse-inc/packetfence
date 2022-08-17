#!/usr/bin/perl

=head1 NAME

to-12.0-migrate-security-events-priority.pl

=head1 DESCRIPTION

Migrate the priority attribute values to severity for security events

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw(
    $security_events_config_file
);

my ($login,$pass,$uid,$gid) = getpwnam('pf');
chown $uid, $gid, $security_events_config_file;

use pf::util;
run_as_pf();

my %severity_rewrite_map = (
    10 => 1,
    9 => 1,
    8 => 2,
    7 => 2,
    6 => 3,
    5 => 3,
    4 => 4,
    3 => 4,
    2 => 1,
    1 => 1,
);

my $ini = pf::IniFiles->new(-file => $security_events_config_file, -allowempty => 1);

my $changed = 0;

for my $section ($ini->Sections()) {
    if ($ini->exists($section, "priority")) {
        $changed |= 1;
        my $priority = $ini->val($section, "priority");
        if(my $severity = $severity_rewrite_map{$priority}) {
            if($ini->exists($section, "severity")) {
                print "Severity value already exists for $section. Not migrating the priority\n";
            }
            else {
                $ini->newval($section, "severity", $severity);
            }
        }
        else {
            print "Priority value $priority in security event $section is not a valid value. Will not migrate the priority in this security event.\n";
        }
        $ini->delval($section, "priority");
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

Copyright (C) 2005-2022 Inverse inc.

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
