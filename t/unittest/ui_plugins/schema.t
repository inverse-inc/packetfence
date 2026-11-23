#!/usr/bin/perl

=head1 NAME

schema

=head1 DESCRIPTION

unit test for pf::ui_plugins::schema, the database tables of the packages
installed on top of PacketFence: the descriptor, the files of a schema
directory and the plan, with a package "acme" written in a temporary
directory. Running the files of a package against MariaDB needs the root
user of a database: not done here.

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More;
use File::Temp qw(tempdir);
use pf::ui_plugins::schema;

# a package "acme": its descriptor in $data/conf, its files in $acme
my $data = tempdir(CLEANUP => 1);
my $acme = "$data/acme";
mkdir("$data/conf") or die $!;
mkdir($acme) or die $!;
sub write_file {
    my ($file, $content) = @_;
    open(my $fh, '>', $file) or die "$file: $!";
    print $fh $content;
    close($fh);
}
write_file("$data/conf/acme.conf", "[plugin]\nversion=1.2\nschema_dir=$acme\n");
write_file("$acme/$_", "-- $_\n") for qw(acme-schema-1.0.sql acme-schema-1.2.sql upgrade-1.0-1.1.sql upgrade-1.1-1.2.sql teardown.sql);

# version_int
is(pf::ui_plugins::schema::version_int('1.2'), 1 << 16 | 2 << 8, 'version 1.2');
ok(pf::ui_plugins::schema::version_int('1.10') > pf::ui_plugins::schema::version_int('1.9'), '1.10 is after 1.9');
is(pf::ui_plugins::schema::version_int($_), undef, "invalid version '$_'") for ('1', '1.2.3', 'a.b', '1.256', '');

# descriptor
my $descriptor = pf::ui_plugins::schema::descriptor('acme', "$data/conf");
is_deeply($descriptor, { name => 'acme', version => '1.2', version_int => 1 << 16 | 2 << 8, schema_dir => $acme }, 'descriptor of acme');
eval { pf::ui_plugins::schema::descriptor('missing', "$data/conf") };
like($@, qr/no descriptor/, 'no descriptor');
eval { pf::ui_plugins::schema::descriptor('../acme', "$data/conf") };
like($@, qr/invalid name/, 'a name is a URL segment');
my $dir = tempdir(CLEANUP => 1);
for my $case (
    ["[plugin]\nversion=1\nschema_dir=$acme\n", qr/invalid version/, 'version X.Y'],
    ["[plugin]\nversion=1.0\nschema_dir=relative\n", qr/schema_dir/, 'schema_dir is absolute'],
    ["[plugin]\nversion=1.0\nschema_dir=/no/such/dir\n", qr/schema_dir/, 'schema_dir exists'],
) {
    my ($content, $error, $name) = @$case;
    open(my $fh, '>', "$dir/bad.conf") or die $!;
    print $fh $content;
    close($fh);
    eval { pf::ui_plugins::schema::descriptor('bad', $dir) };
    like($@, $error, $name);
}

# schema_files
my $files = pf::ui_plugins::schema::schema_files('acme', $acme);
is_deeply([sort keys %{$files->{schema}}], ['1.0', '1.2'], 'schema files');
is_deeply({ map { $_ => $files->{upgrade}{$_}[0] } keys %{$files->{upgrade}} }, { '1.0' => '1.1', '1.1' => '1.2' }, 'upgrade files');
is($files->{teardown}, "$acme/teardown.sql", 'teardown file');
is_deeply(pf::ui_plugins::schema::schema_files('other', $acme)->{schema}, {}, 'the schema files are named after the package');

# plan
sub steps { [ map { [ (split(m{/}, $_->[0]))[-1], $_->[1] ] } pf::ui_plugins::schema::plan('acme', @_, $files) ] }
is_deeply(steps(undef, '1.2'), [['acme-schema-1.2.sql', '1.2']], 'fresh install: the schema of the version');
is_deeply(steps(undef, '1.0'), [['acme-schema-1.0.sql', '1.0']], 'fresh install of an older version');
is_deeply(steps('1.0', '1.2'), [['upgrade-1.0-1.1.sql', '1.1'], ['upgrade-1.1-1.2.sql', '1.2']], 'upgrade 1.0 to 1.2');
is_deeply(steps('1.1', '1.2'), [['upgrade-1.1-1.2.sql', '1.2']], 'upgrade 1.1 to 1.2');
is_deeply(steps('1.2', '1.2'), [], 'up to date');
eval { steps(undef, '1.1') };
like($@, qr/no acme-schema-1\.1\.sql/, 'fresh install without its schema file');
eval { steps('1.2', '1.0') };
like($@, qr/newer than the package/, 'the database is newer than the package');
eval { steps('0.9', '1.2') };
like($@, qr/no upgrade-0\.9-/, 'a missing upgrade');
eval { steps('1.0', '1.1') };
is($@, '', 'an upgrade stops at the package version');

# installed_version and check, against the test database
use pf::dal::plugin_version;
pf::dal::plugin_version->remove_items(-where => { name => 'acme' });
is(pf::ui_plugins::schema::installed_version('acme'), undef, 'not installed');
my ($ok, $message) = pf::ui_plugins::schema::check('acme', conf_dir => "$data/conf");
ok(!$ok, 'check: not installed');
like($message, qr/not installed/, 'check: not installed message');
pf::dal::plugin_version->create({ name => 'acme', id => 1 << 16, version => '1.0' });
pf::dal::plugin_version->create({ name => 'acme', id => 1 << 16 | 1 << 8, version => '1.1' });
is(pf::ui_plugins::schema::installed_version('acme'), '1.1', 'the latest version');
($ok, $message) = pf::ui_plugins::schema::check('acme', conf_dir => "$data/conf");
ok(!$ok, 'check: behind the package');
like($message, qr/pfcmd plugin schema apply acme/, 'check: behind the package message');
pf::dal::plugin_version->create({ name => 'acme', id => 1 << 16 | 2 << 8, version => '1.2' });
($ok) = pf::ui_plugins::schema::check('acme', conf_dir => "$data/conf");
ok($ok, 'check: at the package version');
pf::dal::plugin_version->create({ name => 'acme', id => 1 << 16 | 3 << 8, version => '1.3' });
($ok, $message) = pf::ui_plugins::schema::check('acme', conf_dir => "$data/conf");
ok(!$ok, 'check: newer than the package');
like($message, qr/newer than the package/, 'check: newer than the package message');
pf::dal::plugin_version->remove_items(-where => { name => 'acme' });

done_testing();

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
