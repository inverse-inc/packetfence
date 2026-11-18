package pf::ui_plugins::packages;

=head1 NAME

pf::ui_plugins::packages - the plugin packages installed on top of PacketFence

=head1 SYNOPSIS

    use pf::ui_plugins::packages;

    my $plugins = pf::ui_plugins::packages::list();
    my $status = pf::ui_plugins::packages::install('acme');     # or a package file
    $status = pf::ui_plugins::packages::uninstall('acme', purge => 1);

=head1 DESCRIPTION

A plugin is installed as a package named packetfence-plugin-<name>, with its
descriptor conf/plugins.d/<name>.conf. install and uninstall run the package
manager (apt-get or dnf): the scripts of the package apply the tables, start
and register the service. list reports what is installed.

See https://github.com/akainverse/packetfence-plugin-example.

=cut

use strict;
use warnings;
use Digest::SHA;
use File::Spec::Functions qw(catfile);
use pf::file_paths qw($ui_plugins_conf_dir $ui_plugins_var_dir);
use pf::ui_plugins::schema;

our $PACKAGE_PREFIX = 'packetfence-plugin-';

=head2 names

The names of the plugins with a descriptor in conf/plugins.d.

=cut

sub names {
    my ($dir) = @_;
    $dir //= $ui_plugins_conf_dir;
    opendir(my $dh, $dir) or return ();
    my @names = sort grep { $_ =~ $pf::ui_plugins::schema::NAME_RE } map { /^(.+)\.conf\z/ ? $1 : () } readdir($dh);
    closedir($dh);
    return @names;
}

=head2 bundle_status

"none" (no [bundle] sha256), "missing" (no <name>.js), "ok", or "mismatch"
(the code does not match its sha256: the admin UI does not load it).

=cut

sub bundle_status {
    my ($name, $dir) = @_;
    $dir //= $ui_plugins_conf_dir;
    require Config::IniFiles;
    my $ini = Config::IniFiles->new(-file => catfile($dir, "$name.conf"), -allowempty => 1) or return 'none';
    my $expected = lc($ini->val('bundle', 'sha256') // '');
    return 'none' if $expected eq '';
    my $file = catfile($dir, "$name.js");
    return 'missing' if !-f $file;
    my $sha = Digest::SHA->new(256);
    $sha->addfile($file);
    return $sha->hexdigest eq $expected ? 'ok' : 'mismatch';
}

=head2 list

    my $plugins = list();

One entry per installed plugin: { name, package, version (of the
descriptor), schema (the version of its tables in the database, or undef),
registration ("host:port", or undef), bundle (bundle_status), error }.

=cut

sub list {
    my (%options) = @_;
    my $dir = $options{conf_dir} // $ui_plugins_conf_dir;
    my $registrations = eval { require pf::ui_plugins; pf::ui_plugins::list() } || {};
    my @plugins;
    for my $name (names($dir)) {
        my %plugin = (name => $name, package => $PACKAGE_PREFIX . $name);
        my $descriptor = eval { pf::ui_plugins::schema::descriptor($name, $dir) };
        if ($descriptor) {
            $plugin{version} = $descriptor->{version};
        } else {
            ($plugin{error} = $@) =~ s/\n\z//;
        }
        $plugin{schema} = eval { pf::ui_plugins::schema::installed_version($name) };
        my $r = $registrations->{$name};
        $plugin{registration} = $r ? "$r->{host}:$r->{port}" : undef;
        $plugin{bundle} = bundle_status($name, $dir);
        push @plugins, \%plugin;
    }
    return \@plugins;
}

=head2 package_manager

"apt-get" on Debian, "dnf" on EL, undef otherwise.

=cut

sub package_manager {
    return 'apt-get' if -x '/usr/bin/apt-get';
    return 'dnf' if -x '/usr/bin/dnf';
    return undef;
}

=head2 package_argument

A package file (.deb, .rpm) as is, else the name of a plugin as its package
name (acme: packetfence-plugin-acme).

=cut

sub package_argument {
    my ($what) = @_;
    die "no plugin name or package file\n" if !defined $what;
    # untainted once checked (pfcmd runs in taint mode)
    if ($what =~ /\.(deb|rpm)\z/ && -f $what) {
        my ($file) = $what =~ /\A([^\0\n]+)\z/ or die "invalid package file name\n";
        return $file;
    }
    if (index($what, $PACKAGE_PREFIX) == 0) {
        return $PACKAGE_PREFIX . pf::ui_plugins::schema::check_name(substr($what, length($PACKAGE_PREFIX)))
          if substr($what, length($PACKAGE_PREFIX)) =~ $pf::ui_plugins::schema::NAME_RE;
    }
    return $PACKAGE_PREFIX . pf::ui_plugins::schema::check_name($what) if $what =~ $pf::ui_plugins::schema::NAME_RE;
    die sprintf("\"%s\" is not a plugin name or a package file\n", $what);
}

=head2 install_command, uninstall_command

The package manager command (a list) to install a plugin (a name or a
package file), or to remove it. uninstall with purge also drops its tables:
apt-get purge; with dnf, the purge-on-erase flag of the package.

=cut

sub install_command {
    my ($what, %options) = @_;
    my $pm = $options{package_manager} // package_manager() // die "no apt-get or dnf\n";
    my $arg = package_argument($what);
    # a relative file name: never read as an option, nor as a package name
    $arg = "./$arg" if $arg =~ /\.(deb|rpm)\z/ && $arg !~ m{\A\.{0,2}/};
    return ($pm, 'install', '-y', $arg);
}

sub uninstall_command {
    my ($name, %options) = @_;
    my $pm = $options{package_manager} // package_manager() // die "no apt-get or dnf\n";
    $name = pf::ui_plugins::schema::check_name($name);
    my $package = $PACKAGE_PREFIX . $name;
    return ($pm, ($options{purge} ? 'purge' : 'remove'), '-y', $package) if $pm eq 'apt-get';
    return ($pm, 'remove', '-y', $package);
}

=head2 install, uninstall

Run the package manager, return its exit code.

=cut

sub install {
    my ($what, %options) = @_;
    return _exit_code(system(install_command($what, %options)));
}

# the exit code of system(): 1 when the command could not run
sub _exit_code {
    my ($status) = @_;
    return 1 if $status == -1 || ($status & 127);
    return $status >> 8;
}

sub uninstall {
    my ($name, %options) = @_;
    $name = pf::ui_plugins::schema::check_name($name);
    my @command = uninstall_command($name, %options);
    if ($options{purge} && $command[0] ne 'apt-get') {
        # rpm has no purge: the package drops the tables on erase when flagged
        my $dir = catfile($ui_plugins_var_dir, $name);
        require File::Path;
        File::Path::make_path($dir);
        open(my $fh, '>', catfile($dir, 'purge-on-erase')) or die "cannot flag $name for purge: $!\n";
        close($fh);
    }
    my $code = _exit_code(system(@command));
    if ($code != 0 && $options{purge} && $command[0] ne 'apt-get') {
        # not removed: the flag must not drop the tables at a later erase
        unlink(catfile($ui_plugins_var_dir, $name, 'purge-on-erase'));
    }
    return $code;
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
