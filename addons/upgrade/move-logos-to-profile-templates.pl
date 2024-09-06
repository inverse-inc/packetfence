#!/usr/bin/perl

=head1 NAME

move-logos-to-profile-templates.pl

=cut

=head1 DESCRIPTION

- Find all connection profiles with logo defined in conf/profiles.conf
- Copy each logo into html/captive-portal/profile-templates/PROFILE_NAME/
- Update each connection profile with logo in conf/profiles.conf with new relative paths to logo
- Add logo paths to cluster-files.txt to synchronize across cluster members

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw(
    $profiles_config_file
);
use pf::config::cluster qw($cluster_enabled);
use List::MoreUtils qw(any);
use pf::util;
use File::Copy;
use File::Basename;

run_as_pf();

my $ini = pf::IniFiles->new(-file => $profiles_config_file, -allowempty => 1);
my %profiles_logos;
my $html_prefix = '/usr/local/pf/html';
my $cp_prefix = '/usr/local/pf/html/captive-portal';
my $new_logo_prefix = '/profile-templates';
my $sync_file = '/usr/local/pf/conf/cluster-files.txt';


sub create_sync_file {
    if (-e "$sync_file") {
    print("Synchronization file already exists\n");
    } else {
    print("Creating '$sync_file'\n");
    touch_file($sync_file);
    }
    print("==========\n");
}

sub store_logo_paths {
    my ($profile_id) = @_;
    if (my $logo_path = $ini->val($profile_id, 'logo')) {
    my $logo_filename = basename($logo_path);
        $profiles_logos{$profile_id} = {
            'old_logo_absolute_path' => "$html_prefix$logo_path",
        'old_logo_relative_path' => "$logo_path",
            'new_logo_absolute_path' => "$cp_prefix$new_logo_prefix/$profile_id/$logo_filename",
        'new_logo_relative_path' => "$new_logo_prefix/$profile_id/$logo_filename",
    };
    print("Logo detected on '$profile_id' connection profile\n");
    } else {
    print("No logo declaration detected on '$profile_id' connection profile, profile is using default settings\n");
    }
}


sub check_logo_path {
    my ($profile_id) = @_;

    if ( $profiles_logos{$profile_id}->{'old_logo_absolute_path'} =~ "/profile-templates/" ) {
    print("'$profile_id' has already been migrated\n");
    return 0;
    } else {
    return 1;
    }
}

sub check_logo_exists {
    my ($profile_id) = @_;

    if (-e "$profiles_logos{$profile_id}->{'old_logo_absolute_path'}") {
    print("Current logo configured on '$profile_id' exists on filesystem\n");
        return 1;
    } else {
    print("Current logo configured on '$profile_id' **doesn't** exist on filesystem\n");
    return 0;
    }
}

sub copy_logo_to_new_location {
    my ($profile_id) = @_;
    my $profile_template_dir = dirname($profiles_logos{$profile_id}->{'new_logo_absolute_path'});

    # check if target dir already exist
    if (-d "$profile_template_dir" ) {
    print("$profile_template_dir already exists\n");
    } else {
    print("Creating $profile_template_dir\n");
    mkdir($profile_template_dir);
    }

    print("Copy $profiles_logos{$profile_id}->{'old_logo_absolute_path'} into $profiles_logos{$profile_id}->{'new_logo_absolute_path'}\n");
    copy($profiles_logos{$profile_id}->{'old_logo_absolute_path'}, $profiles_logos{$profile_id}->{'new_logo_absolute_path'});

}

sub update_connection_profile {
    my ($profile_id) = @_;
    print("Updating logo path for '$profile_id' connection profile\n");
    $ini->setval($profile_id, 'logo', $profiles_logos{$profile_id}->{'new_logo_relative_path'});
}

sub add_logo_to_sync {
    my ($profile_id) = @_;
    my $logo_path = $profiles_logos{$profile_id}->{'new_logo_absolute_path'};
    # open file descriptor and write
    open(my $fh, '>>', $sync_file) or die $!;
    print $fh "$logo_path\n";
    close $fh;
}

sub apply_changes {
    $ini->RewriteConfig();
}

### Main

# section = profile ID
for my $section ($ini->Sections()) {
    store_logo_paths($section);
}

print("==========\n");

if ($cluster_enabled) {
    create_sync_file;
}

for my $profile_id (keys %profiles_logos) {
    if (check_logo_path($profile_id)) {
        if (check_logo_exists($profile_id)) {
            copy_logo_to_new_location($profile_id);
            update_connection_profile($profile_id);
        if ($cluster_enabled) {
        add_logo_to_sync($profile_id);
        }
        } else {
            print("==========\n");
            next;
        }
    print("==========\n");
    } else {
    print("Nothing to do on '$profile_id'\n");
    }
}

apply_changes

print "All done\n";

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


