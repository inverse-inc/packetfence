#!/usr/bin/perl

=head1 NAME

to-13.0-remove-provisioner

=head1 DESCRIPTION

to-13.0-remove-provisioner

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw(
    $provisioning_config_file
    $profiles_config_file
);

our %typesToRemove = map { $_ => undef } qw(
    ibm
    servicenow
    sepm
    symantec
    opswat
);

my ($provisioningIni, $removed) = removeProvisioners($provisioning_config_file);

if (!$removed) {
    print "Nothing to be done\n";
    exit 0;
}

$provisioningIni->RewriteConfig();

my $profileIni = updateProfile($profiles_config_file, $removed);

if ($profileIni) {
    $profileIni->RewriteConfig();
}

print "All done\n";

sub updateProfile {
    my ($file, $removed) = @_;
    my $ini = pf::IniFiles->new(-file => $file, -allowempty => 1);
    my %removedSources = map { $_ => undef } @{$removed //[]};
    my $updated = 0;

    for my $section ( grep {/^\S+$/} $ini->Sections() ) {
        $updated |= removeFromList($ini, $section, 'provisioners', \%removedSources);
    }

    if ($updated) {
        return $ini;
    }

    return undef;
}

sub removeFromList {
    my ($ini, $section, $field, $toDelete) = @_;
    my $list = $ini->val($section, $field) // '';
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
        $ini->setval($section, $field, join(",", @new_list));
    }

    return $updated;
}


sub removeProvisioners {
    my ($file) = @_;
    my $ini = pf::IniFiles->new(-file => $file, -allowempty => 1);
    my ($update, $removed) = removeTypes($ini, \%typesToRemove);
    if (!$update) {
        return (undef, undef);
    }

    return ($ini, $removed);
}

sub removeTypes {
    my ($ini, $typesToDelete) = @_;
    my @removed;
    my $updated = 0;
    for my $section ( grep {/^\S+$/} $ini->Sections() ) {
        my $type = $ini->val($section, 'type');
        if (exists $typesToDelete->{$type}) {
            print "Removing $section\n";
            $ini->DeleteSection($section);
            push @removed, $section;
            $updated |= 1;
        }
    }

    return ($updated, \@removed);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca
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

