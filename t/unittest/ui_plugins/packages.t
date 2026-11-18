#!/usr/bin/perl

=head1 NAME

packages

=head1 DESCRIPTION

unit test for pf::ui_plugins::packages: the plugins found in conf/plugins.d,
the state of their UI code, the package manager commands.

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
use Digest::SHA qw(sha256_hex);
use pf::ui_plugins::packages;

my $dir = tempdir(CLEANUP => 1);
sub write_file {
    my ($file, $content) = @_;
    open(my $fh, '>', "$dir/$file") or die $!;
    print $fh $content;
    close($fh);
}
my $code = 'export default { hostApi: 1, mount () {} }';
write_file('ok.conf', "[plugin]\nversion=1.0\nschema_dir=$dir\n[bundle]\nsha256=" . sha256_hex($code) . "\n");
write_file('ok.js', $code);
write_file('changed.conf', "[bundle]\nsha256=" . sha256_hex($code) . "\n");
write_file('changed.js', $code . 'alert(1)');
write_file('nojs.conf', "[bundle]\nsha256=" . sha256_hex($code) . "\n");
write_file('nobundle.conf', "[plugin]\nversion=1.0\n");
write_file('Not_A_Name.conf', "");
write_file('readme.txt', "");

is_deeply([pf::ui_plugins::packages::names($dir)], [qw(changed nobundle nojs ok)], 'the plugins of the directory');
is(pf::ui_plugins::packages::bundle_status('ok', $dir), 'ok', 'bundle ok');
is(pf::ui_plugins::packages::bundle_status('changed', $dir), 'mismatch', 'bundle changed');
is(pf::ui_plugins::packages::bundle_status('nojs', $dir), 'missing', 'bundle missing');
is(pf::ui_plugins::packages::bundle_status('nobundle', $dir), 'none', 'no bundle');

is(pf::ui_plugins::packages::package_argument('acme'), 'packetfence-plugin-acme', 'a name is a package');
is(pf::ui_plugins::packages::package_argument('packetfence-plugin-acme'), 'packetfence-plugin-acme', 'a package name');
write_file('packetfence-plugin-acme_1.0-1_all.deb', '');
is(pf::ui_plugins::packages::package_argument("$dir/packetfence-plugin-acme_1.0-1_all.deb"), "$dir/packetfence-plugin-acme_1.0-1_all.deb", 'a package file');
eval { pf::ui_plugins::packages::package_argument('../acme') };
like($@, qr/not a plugin name/, 'not a name');
eval { pf::ui_plugins::packages::package_argument('acme; rm -rf /') };
like($@, qr/not a plugin name/, 'not a name, not a command');

is_deeply([pf::ui_plugins::packages::install_command('acme', package_manager => 'apt-get')], [qw(apt-get install -y packetfence-plugin-acme)], 'install with apt-get');
is_deeply([pf::ui_plugins::packages::install_command('acme', package_manager => 'dnf')], [qw(dnf install -y packetfence-plugin-acme)], 'install with dnf');
is_deeply([pf::ui_plugins::packages::uninstall_command('acme', package_manager => 'apt-get')], [qw(apt-get remove -y packetfence-plugin-acme)], 'remove with apt-get');
is_deeply([pf::ui_plugins::packages::uninstall_command('acme', package_manager => 'apt-get', purge => 1)], [qw(apt-get purge -y packetfence-plugin-acme)], 'purge with apt-get');
is_deeply([pf::ui_plugins::packages::uninstall_command('acme', package_manager => 'dnf', purge => 1)], [qw(dnf remove -y packetfence-plugin-acme)], 'remove with dnf (purge is a flag)');

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
