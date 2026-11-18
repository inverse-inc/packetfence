#!/usr/bin/perl -T

=head1 NAME

taint

=head1 DESCRIPTION

unit test for pf::ui_plugins::packages and pf::ui_plugins::schema in taint
mode, as pfcmd runs them: the names and files they get from the command line
are untainted once checked, before they reach the package manager, the mysql
client or the filesystem.

=cut

use strict;
use warnings;

# no setup_test_config: these functions read no configuration, and
# PERL5LIB is ignored in taint mode
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);

use Test::More;
use File::Temp qw(tempdir);
use Scalar::Util qw(tainted);
use pf::ui_plugins::packages;
use pf::ui_plugins::schema;

my $dir = tempdir(CLEANUP => 1);

# a value as it comes from outside (the command line, a file): tainted
sub from_outside {
    my ($value) = @_;
    open(my $fh, '>', "$dir/value") or die $!;
    print $fh $value;
    close($fh);
    open($fh, '<', "$dir/value") or die $!;
    my $read = <$fh>;
    close($fh);
    return $read;
}

ok(${^TAINT}, 'taint mode');
ok(tainted(from_outside('acme')), 'a value from outside is tainted');

my $name = pf::ui_plugins::schema::check_name(from_outside('acme'));
is($name, 'acme', 'check_name returns the name');
ok(!tainted($name), 'check_name: untainted');
eval { pf::ui_plugins::schema::check_name(from_outside('../acme')) };
like($@, qr/invalid name/, 'check_name: refused');

for my $what ('acme', 'packetfence-plugin-acme') {
    my @command = pf::ui_plugins::packages::install_command(from_outside($what), package_manager => 'apt-get');
    is_deeply(\@command, [qw(apt-get install -y packetfence-plugin-acme)], "install $what");
    ok(!grep({ tainted($_) } @command), "install $what: untainted");
}

open(my $fh, '>', "$dir/-acme_1.0-1_all.deb") or die $!;
close($fh);
chdir($dir) or die $!;
my @command = pf::ui_plugins::packages::install_command(from_outside('-acme_1.0-1_all.deb'), package_manager => 'apt-get');
is_deeply(\@command, [qw(apt-get install -y ./-acme_1.0-1_all.deb)], 'install a file: never read as an option');
ok(!grep({ tainted($_) } @command), 'install a file: untainted');

@command = pf::ui_plugins::packages::uninstall_command(from_outside('acme'), package_manager => 'apt-get', purge => 1);
is_deeply(\@command, [qw(apt-get purge -y packetfence-plugin-acme)], 'purge');
ok(!grep({ tainted($_) } @command), 'purge: untainted');

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
