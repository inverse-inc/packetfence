#!/usr/bin/perl -T

=head1 NAME

fixpermissions_taint

=head1 DESCRIPTION

unit test for pf::cmd::pf::fixpermissions in taint mode, as pfcmd runs it:
the names File::Find hands _removeOthersPermissions come from readdir and are
tainted, and so is what lstat returns for them. The path is untainted before
the lstat, or chmod dies on the tainted mode ("Insecure dependency in chmod",
seen by the Debian postinst of 16.0).

=cut

use strict;
use warnings;

# no setup_test_config (no pfconfig needed): test_paths alone points the
# files read at load time (system_init_key) to t/data. PERL5LIB is ignored in
# taint mode, hence the explicit lib paths
use lib qw(/usr/local/pf/t /usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use test_paths;

use Test::More;
use File::Temp qw(tempdir);
use pf::cmd::pf::fixpermissions;

ok(${^TAINT}, 'taint mode');

my $dir = tempdir(CLEANUP => 1);
my @modes = (0664, 0600, 0755);
my @files = map { my $f = "$dir/file$_"; open(my $fh, '>', $f) or die $!; close $fh; chmod($modes[$_], $f); $f } 0 .. $#modes;
mkdir("$dir/plugins.d") or die $!;
my $plugin_file = "$dir/plugins.d/acme.json";
open(my $fh, '>', $plugin_file) or die $!; close $fh; chmod(0644, $plugin_file);

local $pf::constants::user::PF_UID = $<;
local $pf::constants::user::PF_GID = (split ' ', $()[0];
local $pf::cmd::pf::fixpermissions::ui_plugins_conf_dir = "$dir/plugins.d";

my $died = !eval { pf::cmd::pf::fixpermissions::_removeOthersPermissions($dir); 1 };
ok(!$died, "_removeOthersPermissions runs in taint mode") or diag($@);
is_deeply([ map { (stat($_))[2] & 07777 } @files ], [0660, 0600, 0750], "permissions of others are removed");
is((stat($plugin_file))[2] & 07777, 0644, "the plugins directory is left out");

done_testing();
