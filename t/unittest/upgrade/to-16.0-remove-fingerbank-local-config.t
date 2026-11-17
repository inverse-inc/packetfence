#!/usr/bin/perl

=head1 NAME

to-16.0-remove-fingerbank-local-config

=head1 DESCRIPTION

unit test for addons/upgrade/to-16.0-remove-fingerbank-local-config.pl

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}
use pf::file_paths qw($install_dir);
use pf::IniFiles;
use File::Temp qw(tempdir);
require "$install_dir/addons/upgrade/to-16.0-remove-fingerbank-local-config.pl";
use Test::More tests => 15;

#This test will running last
use Test::NoWarnings;

my $dir = tempdir(CLEANUP => 1);
sub write_file {
    my ($name, $content) = @_;
    my $file = "$dir/$name";
    open(my $fh, '>', $file) or die "$file: $!";
    print $fh $content;
    close($fh);
    return $file;
}

sub ini {
    my ($file) = @_;
    return pf::IniFiles->new(-file => $file, -allowempty => 1);
}

sub quietly {
    my ($sub) = @_;
    open(my $out, '>', \my $output);
    my $old = select($out);
    my $res = $sub->();
    select($old);
    return $res;
}

# fingerbank.conf
my $fingerbank = write_file('fingerbank.conf', "[upstream]\napi_key=abc\n[query]\nrecord_unmatched=enabled\n");
ok(quietly(sub { remove_query_section($fingerbank) }), "the [query] section is removed");
ok(!ini($fingerbank)->SectionExists('query'), "fingerbank.conf has no [query] section");
is(ini($fingerbank)->val('upstream', 'api_key'), 'abc', "the other sections are left alone");
ok(!quietly(sub { remove_query_section($fingerbank) }), "nothing to do the second time");
ok(!remove_query_section("$dir/missing.conf"), "a missing fingerbank.conf is skipped");

# pfconfig.conf
my $pfconfig = write_file('pfconfig.conf', "[git_storage]\nstatus=enabled\nfingerbank_db_directory=/usr/local/fingerbank/db\n");
ok(quietly(sub { remove_git_storage_db_directory($pfconfig) }), "fingerbank_db_directory is removed");
ok(!ini($pfconfig)->exists('git_storage', 'fingerbank_db_directory'), "pfconfig.conf has no fingerbank_db_directory");
is(ini($pfconfig)->val('git_storage', 'status'), 'enabled', "the other git storage settings are left alone");
ok(!quietly(sub { remove_git_storage_db_directory($pfconfig) }), "nothing to do the second time");

my $pfconfig_only = write_file('pfconfig-only.conf', "[git_storage]\nfingerbank_db_directory=/usr/local/fingerbank/db\n[mysql]\nhost=localhost\n");
quietly(sub { remove_git_storage_db_directory($pfconfig_only) });
ok(!ini($pfconfig_only)->SectionExists('git_storage'), "an emptied [git_storage] section is removed");

# The local database
mkdir("$dir/db");
write_file("db/$_", "") for qw(fingerbank_Local.db fingerbank_Local.db-journal fingerbank_Upstream.db);
is(quietly(sub { remove_local_db("$dir/db/fingerbank_Local.db*") }), 2, "the local database and its copies are deleted");
ok(!-e "$dir/db/fingerbank_Local.db", "the local database is gone");
ok(-e "$dir/db/fingerbank_Upstream.db", "the upstream database is kept");
is(quietly(sub { remove_local_db("$dir/db/fingerbank_Local.db*") }), 0, "nothing to do the second time");

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
