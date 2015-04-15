package pf::cmd::pf::fixpermissions;
=head1 NAME

pf::cmd::pf::fixpermissions add documentation

=head1 SYNOPSIS

 pfcmd fixpermissions

Fix the permissions of the files and directories of packetfence

=head1 DESCRIPTION

pf::cmd::pf::fixpermissions

=cut

use strict;
use warnings;
use base qw(pf::cmd);
use pf::file_paths;
use pf::constants::exit_code qw($EXIT_SUCCESS);
use File::Spec::Functions qw(catfile);

sub parseArgs { 1 }

sub _run {
    my $pfcmd = "${bin_dir}/pfcmd";
    my @extra_var_dirs = map { catfile($var_dir,$_) } qw(run cache conf sessions);
    _changeFilesToOwner('pf',@log_files, @stored_config_files, $install_dir, $bin_dir, $conf_dir, $var_dir, $lib_dir, $log_dir, $generated_conf_dir, $tt_compile_cache_dir, $pfconfig_cache_dir, @extra_var_dirs);
    _changeFilesToOwner('root',$pfcmd);
    chmod(06755,$pfcmd);
    chmod(0664, @stored_config_files);
    chmod(02775, $conf_dir, $var_dir, $log_dir);
    return $EXIT_SUCCESS;
}

sub _changeFilesToOwner {
    my ($user,@files) = @_;
    my ($login,$pass,$uid,$gid) = getpwnam($user);
    my ($group, undef, undef, undef)= getgrgid($gid);
    chown $uid,$gid,@files;
}
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

