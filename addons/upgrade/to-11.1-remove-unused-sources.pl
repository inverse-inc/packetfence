#!/usr/bin/perl

=head1 NAME

to-11.1-remove-unused-sources

=head1 DESCRIPTION

to-11.1-remove-unused-sources

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw(
    $authentication_config_file
    $portal_modules_config_file
    $profiles_config_file
);

use pf::util;
main() if not caller();

sub main {
    my ($sourceConfigStore, $removedSources) = removeSources($authentication_config_file);
    if (!$sourceConfigStore) {
        print "Nothing to be done\n";
        exit 0;
    }

    my ($portalModuleConfigStore, $removedPortalModules) = removePortalModules($portal_modules_config_file);
    my $profileConfigStore = updateProfile($profiles_config_file, $removedSources, $removedPortalModules);

    $sourceConfigStore->RewriteConfig();
    if ($portalModuleConfigStore) {
        $portalModuleConfigStore->RewriteConfig();
    }

    if ($profileConfigStore) {
        $profileConfigStore->RewriteConfig();
    }

    print "All done\n";
}

sub updateProfile {

    return undef;
}

sub removeSources {
    my ($file) = @_;
    my @found;
    our %typesToDelete = map { $_ => undef  } qw(Twitter Pinterest Mirapay Instagram AuthorizeNet);
    my $cs = pf::IniFiles->new(-file => $file, -allowempty => 1);
    my ($update, $removed) = removeTypes($cs, \%typesToDelete);
    if (!$update) {
        return (undef, undef);
    }

    for my $section (@$removed) {
        for my $group ($cs->GroupMembers($section)) {
            $cs->DeleteSection($group);
        }
    }

    return ($cs, $removed);
}

sub removePortalModules {
    my ($file) = @_;
    our %toDelete = map { ("Authentication::OAuth::$_" => undef) } qw(Twitter Pinterest Instagram);
    my $cs = pf::IniFiles->new(-file => $file, -allowempty => 1);
    my ($update, $removed) = removeTypes($cs, \%toDelete);
    if (!$update) {
        return (undef, undef);
    }

    return ($cs, $removed);
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

Copyright (C) 2005-2021 Inverse inc.

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
