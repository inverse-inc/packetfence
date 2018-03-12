package pf::cmd::pf::fixpermissions;
=head1 NAME

pf::cmd::pf::fixpermissions add documentation

=head1 SYNOPSIS

 pfcmd fixpermissions <command>

 Commands :
  all                             | executes a fix on the permissions on all PF files
  file file1 [file2, file3, ...]  | executes a fix on the permissions on a list of files (absolute paths)
    (File(s) must exist and located in /usr/local/pf or /usr/local/fingerbank)

=head1 DESCRIPTION

pf::cmd::pf::fixpermissions

=cut

use strict;
use warnings;

use base qw(pf::base::cmd::action_cmd);

use pf::file_paths qw(
    $bin_dir
    $var_dir
    @log_files
    @stored_config_files
    $install_dir
    $tt_compile_cache_dir
    $generated_conf_dir
    $pfconfig_cache_dir
    $log_dir
    $conf_dir
    $lib_dir
    $config_version_file
);
use pf::log;
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE);
use pf::util;
use File::Find;

use fingerbank::Util;

use File::Spec::Functions qw(catfile);

sub default_action { 'all' }

=head2 action_all

Fix the permissions on pf and fingerbank files

=cut

sub action_all {
    my $pfcmd = "${bin_dir}/pfcmd";
    my @extra_var_dirs = map { catfile($var_dir,$_) } qw(run cache conf sessions redis_cache redis_queue);
    _changeFilesToOwner('pf',@log_files, @stored_config_files, $install_dir, $bin_dir, $conf_dir, $var_dir, $lib_dir, $log_dir, $generated_conf_dir, $tt_compile_cache_dir, $pfconfig_cache_dir, @extra_var_dirs, $config_version_file);
    _changeFilesToOwner('root',$pfcmd);
    chmod(06755,$pfcmd);
    chmod(0664, @stored_config_files);
    chmod(02775, $conf_dir, $var_dir, $log_dir, "$var_dir/redis_cache", "$var_dir/redis_queue");
    _fingerbank();
    find({ wanted => \&wanted,untaint => 1}, $log_dir);
    print "Fixed permissions.\n";
    return $EXIT_SUCCESS;
}

sub parse_file {
    my ($self,@args) = @_;
    foreach my $file (@args){
        unless(-f $file){
            print STDERR "File $file doesn't exist \n";
            return 0;
        }
        unless($file =~ /\/usr\/local\/pf\// || $file =~ /\/usr\/local\/fingerbank\//){
            print STDERR "File $file is not in an allowed directory \n";
            return 0;
        }
    }
    return 1;
}

=head2 action_file

Apply the permission fix on specific(s) file(s)
Will determine the user to set rights to depending on the destination directory
Doesn't work outside /usr/local/pf and /usr/local/fingerbank

=cut

sub action_file {
    my ($self) = @_;
    my (@files) = $self->action_args;

    unless(@files){
        print STDERR "No files specified \n";
        return $EXIT_FAILURE;
    }

    foreach my $file (@files){
        $file = untaint_chain($file);

        my $user;
        if($file =~ /\/usr\/local\/pf\//){
            $user = 'pf';
        }
        elsif($file =~ /\/usr\/local\/fingerbank\//){
            $user = 'fingerbank';
        }
        else {
            print STDERR "Cannot compute user from directory \n";
            return $EXIT_FAILURE;
        }
        _changeFilesToOwner($user,$file);
        chmod 0660, $file;
        print "Fixed permissions on file $file \n";
    }

    return $EXIT_SUCCESS;
}

sub _changeFilesToOwner {
    my ($user,@files) = @_;
    my ($login,$pass,$uid,$gid) = getpwnam($user);
    if(defined $uid && defined $gid) {
        my ($group, undef, undef, undef)= getgrgid($gid);
        chown $uid,$gid,@files;
    }
    else {
        my $msg = "Problem getting group and user id for $user\n";
        print STDERR $msg;
        get_logger->error($msg);
    }
}

sub _fingerbank {
    fingerbank::Util::fix_permissions();
}

sub wanted {
    my $perm = -d $File::Find::name ? 0555 : 0664;
    chmod $perm, untaint_chain($File::Find::name);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

