#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-16.0-remove-fingerbank-local-config.pl

=cut

=head1 DESCRIPTION

Remove what is left of the local Fingerbank database, removed in 16.0.

The upgrade of the fingerbank package already does it, but an import restores
the fingerbank.conf and pfconfig.conf of the export after the packages were
installed, and a deployment without packages (k8s) never runs it:

=over

=item * the [query] section of fingerbank.conf (record_unmatched)

=item * fingerbank_db_directory in the [git_storage] section of pfconfig.conf

=item * the local database file (fingerbank_Local.db) and its copies

=item * with git storage, the local database saved in the repository (fingerbank/db/)

=back

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use File::Basename qw(basename);
use pf::IniFiles;
use pf::file_paths qw($fingerbank_config_file);
use pf::util;
use pfconfig::constants;
use fingerbank::FilePath;

our $LOCAL_DB_GLOB = $fingerbank::FilePath::INSTALL_PATH . "db/fingerbank_Local.db*";
our $GIT_STORAGE_DB_DIR = "fingerbank/db";

main() if not caller();

sub main {
    # The fingerbank files belong to the fingerbank user: done before switching to pf
    remove_query_section($fingerbank_config_file);
    remove_local_db($LOCAL_DB_GLOB);
    run_as_pf();
    remove_git_storage_db_directory($pfconfig::constants::CONFIG_FILE_PATH);
    remove_local_db_from_git_storage();
}

=head2 remove_query_section

Remove the [query] section of fingerbank.conf: its only setting (record_unmatched)
was used by the local matcher

=cut

sub remove_query_section {
    my ($file) = @_;
    return 0 unless -f $file;
    my $ini = pf::IniFiles->new(-file => $file, -allowempty => 1) or return 0;
    return 0 unless $ini->SectionExists('query');
    my ($uid, $gid) = (stat($file))[4, 5];
    $ini->DeleteSection('query');
    $ini->RewriteConfig() or die "Unable to rewrite $file";
    # The file is rewritten through a temporary file: keep its owner
    chown($uid, $gid, $file) if $< == 0;
    print("Removed the [query] section of $file: the local Fingerbank matcher was removed\n");
    return 1;
}

=head2 remove_local_db

Delete the local database file and its copies

=cut

sub remove_local_db {
    my ($glob) = @_;
    my $removed = 0;
    for my $file (glob($glob)) {
        next unless -f $file;
        if (unlink($file)) {
            print("Deleted the local Fingerbank database $file\n");
            $removed++;
        } else {
            print STDERR "Unable to delete the local Fingerbank database $file: $!\n";
        }
    }
    return $removed;
}

=head2 remove_git_storage_db_directory

Remove fingerbank_db_directory from the [git_storage] section of pfconfig.conf:
the local database is not synchronized through git storage anymore

=cut

sub remove_git_storage_db_directory {
    my ($file) = @_;
    return 0 unless -f $file;
    my $ini = pf::IniFiles->new(-file => $file, -allowempty => 1) or return 0;
    return 0 unless $ini->exists('git_storage', 'fingerbank_db_directory');
    $ini->delval('git_storage', 'fingerbank_db_directory');
    $ini->DeleteSection('git_storage') if !$ini->Parameters('git_storage');
    $ini->RewriteConfig() or die "Unable to rewrite $file";
    print("Removed git_storage.fingerbank_db_directory from $file: the local Fingerbank database was removed\n");
    return 1;
}

=head2 remove_local_db_from_git_storage

With git storage, delete the local database saved in the repository

=cut

sub remove_local_db_from_git_storage {
    require pfconfig::git_storage;
    return 0 unless pfconfig::git_storage->is_enabled;
    my $dir = pfconfig::git_storage->git_directory . "/$GIT_STORAGE_DB_DIR";
    my $removed = 0;
    for my $file (glob("$dir/fingerbank_Local.db*")) {
        my $name = "$GIT_STORAGE_DB_DIR/" . basename($file);
        my ($res, $msg) = pfconfig::git_storage->delete_file($name);
        if ($res) {
            print("Deleted the local Fingerbank database $name from git storage\n");
            $removed++;
        } else {
            # Not fatal: the file is not read anymore
            print STDERR "Unable to delete $name from git storage: " . ($msg // 'unknown error') . "\n";
        }
    }
    return $removed;
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

1;
