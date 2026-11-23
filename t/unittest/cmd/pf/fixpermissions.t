#!/usr/bin/perl

=head1 NAME

fixpermissions

=head1 DESCRIPTION

unit test for fixpermissions

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 24;

#This test will running last
use Test::NoWarnings;
use File::Temp;
use pf::cmd::pf::fixpermissions;
use pf::constants qw($FILE_MODE $CONF_FILE_MODE $SECRET_FILE_MODE);
use pf::file_paths qw($install_dir $conf_dir $html_dir $config_version_file $local_secret_file);
use pf::util;
use fingerbank::FilePath;

my $file_mode = \&pf::cmd::pf::fixpermissions::_file_mode;

is($CONF_FILE_MODE & 07, 0, "configuration files are not readable by others");
is($SECRET_FILE_MODE & 07, 0, "secret files are not readable by others");
is($file_mode->("$conf_dir/domain.conf"), $CONF_FILE_MODE, "file in the configuration directory");
is($file_mode->("$html_dir/captive-portal/templates/layout.html"), $FILE_MODE, "file outside the configuration directory");
is($file_mode->($local_secret_file), $SECRET_FILE_MODE, "secret file");
is($file_mode->($config_version_file), $CONF_FILE_MODE, "configuration version file");
is($file_mode->($fingerbank::FilePath::CONF_FILE), $CONF_FILE_MODE, "fingerbank.conf");
is($file_mode->("$fingerbank::FilePath::INSTALL_PATH/db/upgrade.pl"), $FILE_MODE, "other fingerbank file");

# Paths that are not canonical get the same mode as the canonical path
is($file_mode->("$install_dir//conf/pf.conf.defaults"), $CONF_FILE_MODE, "double slash before the configuration directory");
is($file_mode->("$install_dir/var/../conf/pf.conf.defaults"), $CONF_FILE_MODE, "parent directory in the path");
is($file_mode->("$conf_dir/../conf/domain.conf"), $CONF_FILE_MODE, "parent directory inside the configuration directory");

# A mode coming from another server can be stricter than the local one, not looser
is(pf::util::restrict_mode(0100664, $CONF_FILE_MODE), 0660, "a configuration file synced as 0664 becomes 0660");
is(pf::util::restrict_mode(0100664, $SECRET_FILE_MODE), 0640, "a secret file synced as 0664 becomes 0640");
is(pf::util::restrict_mode(0100600, $CONF_FILE_MODE), 0600, "a stricter mode is kept");
is(pf::util::restrict_mode(0100755, $FILE_MODE), 0755, "execute permissions are kept");
is(pf::util::restrict_mode(0100644, undef), 0644, "the mode is kept when the local mode is unknown");
is(pf::util::restrict_mode(0102775, $FILE_MODE), 0775, "the setgid bit is dropped when the local mode is known");
is(pf::util::restrict_mode(0102775, undef), 0775, "the setgid bit is dropped when the local mode is unknown");
# (setup_test_config points $server_pem and $server_key to test files)
is($file_mode->("$conf_dir/ssl/server.pem"), $SECRET_FILE_MODE, "server.pem holds the private key of the HTTPS certificate");
is($file_mode->("$conf_dir/ssl/server.key"), $SECRET_FILE_MODE, "server.key");

{
    # Others lose their permissions on the files owned by pf, the other bits are kept
    my $dir = File::Temp->newdir();
    my @modes = (0664, 0600, 0755);
    my @files = map { my $f = "$dir/file$_"; open(my $fh, '>', $f) or die; close $fh; chmod($modes[$_], $f); $f } 0 .. $#modes;
    mkdir("$dir/plugins.d") or die;
    my $plugin_file = "$dir/plugins.d/acme.json";
    open(my $fh, '>', $plugin_file) or die; close $fh; chmod(0644, $plugin_file);
    local $pf::constants::user::PF_UID = $<;
    local $pf::constants::user::PF_GID = (split ' ', $()[0];
    local $pf::cmd::pf::fixpermissions::ui_plugins_conf_dir = "$dir/plugins.d";
    pf::cmd::pf::fixpermissions::_removeOthersPermissions("$dir");
    is_deeply([ map { (stat($_))[2] & 07777 } @files ], [0660, 0600, 0750], "permissions of others are removed recursively");
    is((stat($plugin_file))[2] & 07777, 0644, "the plugins directory is left out");
}

{
    # The private key files are limited to the secret mode, never widened, even
    # when they don't belong to pf (server.pem was created as root:root 0644)
    my $dir = File::Temp->newdir();
    my @modes = (0644, 0600);
    my @files = map { my $f = "$dir/key$_"; open(my $fh, '>', $f) or die; close $fh; chmod($modes[$_], $f); $f } 0 .. $#modes;
    symlink($files[0], "$dir/link") or die;
    local $pf::constants::user::PF_UID = $<;
    local $pf::constants::user::PF_GID = (split ' ', $()[0];
    local @pf::cmd::pf::fixpermissions::private_key_files = (@files, "$dir/link", "$dir/missing");
    pf::cmd::pf::fixpermissions::_restrictPrivateKeyFiles();
    is_deeply([ map { (stat($_))[2] & 07777 } @files ], [0640, 0600], "the private key files are not readable by others, a stricter mode is kept");
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
