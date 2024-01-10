#!/usr/bin/perl

=head1 NAME

firewallsso_to_update -

=head1 DESCRIPTION

firewallsso_to_update

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::constants::config;
use pf::file_paths qw(
    $switches_config_file
);


my $switches = pf::IniFiles->new( -file => $switches_config_file, -allowempty => 1);

if (length ($switches->Sections()) > 0) {
    for my $section ($switches->Sections()) {
        if ($switches->exists($section, 'PushACLs')) {
            $switches->newval($section, 'UsePushACLs', $switches->val($section, 'PushACLs'));
            $switches->delval($section, 'PushACLs');
        }
    }
    $switches->RewriteConfig();
} else {
    print "Nothing to do\n";
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
