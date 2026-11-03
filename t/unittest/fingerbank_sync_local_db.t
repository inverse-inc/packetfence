#!/usr/bin/perl

=head1 NAME

fingerbank_sync_local_db

=head1 DESCRIPTION

pf::fingerbank::sync_local_db saves the local Fingerbank database to the git
storage when it is enabled

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 19;
use pf::fingerbank;

#This test will running last
use Test::NoWarnings;

my ($enabled, @commits, @deploys, @commit_result, $deploy_dies, $deploy_refused);
{
    no warnings qw(redefine once);
    *pfconfig::git_storage::is_enabled = sub { $enabled };
    *pfconfig::git_storage::commit_file = sub { shift; push @commits, [@_]; return @commit_result };
    *pfconfig::git_storage::deploy = sub { shift; push @deploys, {@_}; die "deploy failed\n" if $deploy_dies; return $deploy_refused ? 0 : 1 };
}

$enabled = 0;
is_deeply([pf::fingerbank::sync_local_db()], [1, undef], "Without git storage the sync succeeds");
is(scalar @commits, 0, "Without git storage nothing is committed");

$enabled = 1;
@commit_result = (1, undef);
is_deeply([pf::fingerbank::sync_local_db()], [1, undef], "With git storage the sync succeeds");
is_deeply([map { $_->[1] } @commits], ["fingerbank/db/fingerbank_Local.db"], "The local database is committed to the git storage");
is_deeply(\@deploys, [{ namespace => "config::FingerbankSettings", light => 1 }], "A single light deploy is triggered");

@commits = @deploys = ();
@commit_result = (0, "push failed");
is_deeply([pf::fingerbank::sync_local_db()], [0, "push failed"], "A failed commit is reported");
is(scalar @deploys, 0, "No deploy after a failed commit");

@commit_result = (1, undef);
$deploy_dies = 1;
my ($res, $msg) = pf::fingerbank::sync_local_db();
ok(!$res && $msg =~ /deploying it failed/, "A failed deploy is reported");

$deploy_dies = 0;
$deploy_refused = 1;
($res, $msg) = pf::fingerbank::sync_local_db();
ok(!$res && $msg =~ /deploying it failed/, "A deploy that pfconfig refuses is reported");

# restore_local_db_from_storage: before an edit, the local database is replaced
# by the shared copy of the git repository when they differ
{
    use File::Temp qw(tempdir);
    my $dir = tempdir(CLEANUP => 1);
    mkdir "$dir/repo"; mkdir "$dir/repo/fingerbank"; mkdir "$dir/repo/fingerbank/db"; mkdir "$dir/local";
    sub write_db { my ($f, $c) = @_; open(my $fh, '>', $f) or die $!; print $fh $c; close $fh; }
    sub read_db { my ($f) = @_; open(my $fh, '<', $f) or return undef; local $/; my $c = <$fh>; close $fh; return $c; }
    my $repo_db = "$dir/repo/fingerbank/db/fingerbank_Local.db";
    my $local_db = "$dir/local/fingerbank_Local.db";
    local $fingerbank::FilePath::LOCAL_DB_FILE = $local_db;
    my ($pulls, $pull_ok) = (0, 1);
    no warnings qw(redefine once);
    local *pfconfig::git_storage::pull = sub { $pulls++; return $pull_ok ? (1, undef) : (0, "Unable to pull repository.") };
    local *pfconfig::git_storage::git_directory = sub { "$dir/repo" };

    $enabled = 0;
    is_deeply([pf::fingerbank::restore_local_db_from_storage()], [1], "Without git storage the local database is used as is");
    is($pulls, 0, "Without git storage nothing is pulled");

    $enabled = 1;
    $pull_ok = 0;
    my ($res, $msg) = pf::fingerbank::restore_local_db_from_storage();
    ok(!$res && $msg =~ /Unable to pull/, "A repository that can't be pulled prevents the edit");
    $pull_ok = 1;

    write_db($local_db, "local edits");
    is_deeply([pf::fingerbank::restore_local_db_from_storage()], [1], "No shared copy yet: the local database is used as is");
    is(read_db($local_db), "local edits", "and kept");

    write_db($repo_db, "local edits");
    my $mtime = (stat $local_db)[9];
    utime($mtime - 100, $mtime - 100, $local_db);
    pf::fingerbank::restore_local_db_from_storage();
    is((stat $local_db)[9], $mtime - 100, "The same database as the shared copy is not rewritten");

    write_db($local_db, "");
    write_db($repo_db, "shared database");
    is_deeply([pf::fingerbank::restore_local_db_from_storage()], [1], "A local database that differs from the shared copy can be edited");
    is(read_db($local_db), "shared database", "after being replaced by the shared copy");

    unlink $local_db;
    pf::fingerbank::restore_local_db_from_storage();
    is(read_db($local_db), "shared database", "A missing local database is restored from the shared copy");
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
