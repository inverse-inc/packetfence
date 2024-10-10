#!/usr/bin/perl

=head1 NAME

to-11.1-remove-wmi-scan.pl

=head1 DESCRIPTION

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw(
    $scan_config_file
    $profiles_config_file
);

use pf::util;
our %scanEnginesToDelete = map { $_ => undef } qw(wmi);

main() if not caller();

sub main {
    my ($scanConfigStore, $removedScanEngines) = removeWmiScanEngine($scan_config_file);
    if (!$scanConfigStore) {
        print "Nothing to be done\n";
        exit 0;
    }

    my $profileConfigStore = updateProfile($profiles_config_file, $removedScanEngines);
    $scanConfigStore->RewriteConfig();
    if ($profileConfigStore) {
        $profileConfigStore->RewriteConfig();
    }

    print "All done\n";
}

sub removeWmiScanEngine {
    my ($file) = @_;
    my $cs = pf::IniFiles->new(-file => $file, -allowempty => 1);
    my ($update, $removed) = removeTypes($cs, \%scanEnginesToDelete);
    if (!$update) {
        return (undef, undef);
    }

    return ($cs, $removed);
}

sub updateProfile {
    my ($file, $removed) = @_;
    my $cs = pf::IniFiles->new(-file => $file, -allowempty => 1);
    my %removed = map { $_ => undef } @{$removed //[]};
    my $updated = 0;
    for my $section ( grep {/^\S+$/} $cs->Sections() ) {
        $updated |= removeFromList($cs, $section, 'scans', \%removed);
    }

    if ($updated) {
        return $cs;
    }

    return undef;
}

sub removeFromList {
    my ($cs, $section, $field, $toDelete) = @_;
    my $list = $cs->val($section, $field) // '';
    my $updated = 0;
    if (!defined $list || length($list) == 0) {
        return $updated;
    }

    my @new_list;
    for my $i (split(/\s*,\s*/, $list)) {
        if (exists $toDelete->{$i}) {
            $updated |= 1;
            next;
        }

        push @new_list, $i
    }

    if ($updated) {
        $cs->setval($section, $field, join(",", @new_list));
    }

    return $updated;
}

sub removeTypes {
    my ($cs, $typesToDelete) = @_;
    my @removed;
    my $updated = 0;
    for my $section ( grep {/^\S+$/} $cs->Sections() ) {
        my $type = $cs->val($section, 'type');
        if (exists $typesToDelete->{$type}) {
            print "Removing $section\n";
            $cs->DeleteSection($section);
            push @removed, $section;
            $updated |= 1;
        }
    }

    return ($updated, \@removed);
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

1;
