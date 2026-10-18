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

use Test::More tests => 9;
use pf::fingerbank;

#This test will running last
use Test::NoWarnings;

my ($enabled, @commits, @deploys, @commit_result, $deploy_dies);
{
    no warnings qw(redefine once);
    *pfconfig::git_storage::is_enabled = sub { $enabled };
    *pfconfig::git_storage::commit_file = sub { shift; push @commits, [@_]; return @commit_result };
    *pfconfig::git_storage::deploy = sub { shift; push @deploys, {@_}; die "deploy failed\n" if $deploy_dies; return 1 };
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
