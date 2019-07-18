#!/usr/bin/perl

=head1 NAME

to-9.1-selfservice-conf.pl

=cut

=head1 DESCRIPTION

Remove references to DEVICE_REGISTRATION_READ in adminroles.conf if there are any
Rename device_registration.conf to self_service.conf
Rename parameters of previous device registration policies into their new self service parameter name

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::IniFiles;
use pf::file_paths qw(
    $admin_roles_config_file
    $self_service_config_file
    $profiles_config_file
);
use List::MoreUtils qw(any);
use pf::util;
use File::Copy;

run_as_pf();

exit 0 unless -e $admin_roles_config_file;
my $admin_ini = pf::IniFiles->new(-file => $admin_roles_config_file, -allowempty => 1);

for my $section ($admin_ini->Sections()) {
    if (my $actions = $admin_ini->val($section, 'actions')) {
        $actions = [ split(/\s*,\s*/, $actions) ];
        if(any {$_ =~ /^DEVICE_REGISTRATION/} @$actions) {
            print "Renaming device registration actions in section $section in file $admin_roles_config_file\n";
            $actions = [ map { $_ =~ s/^DEVICE_REGISTRATION/SELF_SERVICE/g ? $_ : $_ } @$actions ];
            $admin_ini->setval($section, 'actions', join(',', @$actions));
        }
    }
}

$admin_ini->RewriteConfig();

my $dr_file = "/usr/local/pf/conf/device_registration.conf";
print "Copying $dr_file to $self_service_config_file \n";
copy($dr_file, $self_service_config_file);

my $ss_ini = pf::IniFiles->new(-file => $self_service_config_file, -allowempty => 1);

my %remap = (
    category => "device_registration_role",
    allowed_devices => "device_registration_allowed_devices",
);
for my $section ($ss_ini->Sections()) {
    while(my ($old, $new) = each(%remap)) {
        print "Renaming parameter $old to $new in section $section in file $self_service_config_file \n";
        my $val = $ss_ini->val($section, $old);
        $ss_ini->newval($section, $new, $val);
        $ss_ini->delval($section, $old);
    }
}

$ss_ini->RewriteConfig();

my $profile_ini = pf::IniFiles->new(-file => $profiles_config_file, -allowempty => 1);

my %remap = (
    device_registration => "self_service",
);
for my $section ($profile_ini->Sections()) {
    while(my ($old, $new) = each(%remap)) {
        print "Renaming parameter $old to $new in section $section in file $profiles_config_file \n";
        my $val = $profile_ini->val($section, $old);
        $profile_ini->newval($section, $new, $val);
        $profile_ini->delval($section, $old);
    }
}

$profile_ini->RewriteConfig();

print "All done\n";

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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


