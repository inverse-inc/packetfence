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
    $html_dir
    $lib_dir
    $config_version_file
    @secret_config_files
);
use pf::log;
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE);
use pf::constants qw($DIR_MODE $PFCMD_MODE $FILE_MODE $CONF_FILE_MODE $SECRET_FILE_MODE);
use pf::constants::user;
use pf::util;
use File::Find;
use Cwd qw(abs_path);

use fingerbank::Util;

use File::Spec::Functions qw(catfile);

sub default_action { 'all' }

=head2 action_all

Fix the permissions on pf and fingerbank files

=cut

sub action_all {
    my $pfcmd = "${bin_dir}/pfcmd";
    my @extra_var_dirs = map { catfile($var_dir,$_) } qw(run cache conf sessions redis_cache redis_queue);
    _changeFilesToOwner(
        'pf',
        @stored_config_files,
        $install_dir,
        $bin_dir,
        $conf_dir,
        $var_dir,
        $lib_dir,
        $generated_conf_dir,
        $tt_compile_cache_dir,
        $pfconfig_cache_dir,
        @extra_var_dirs,
        $config_version_file,
    );
    _changePathToOwnerRecursive('pf', $html_dir);
    _changeFilesToOwner(
        'root',
        $pfcmd,
    );
    chmod($PFCMD_MODE, $pfcmd);
    _removeOthersPermissions($conf_dir);
    chmod($CONF_FILE_MODE, @stored_config_files, $config_version_file);
    my @secret_files = grep { -f $_ } @secret_config_files;
    _changeFilesToOwner('pf', @secret_files);
    chmod($SECRET_FILE_MODE, @secret_files);
    chmod($DIR_MODE, $conf_dir, $var_dir, "$var_dir/redis_cache", "$var_dir/redis_queue");
    _fingerbank();
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
        chmod(_file_mode($file), $file);
        print "Fixed permissions on file $file \n";
    }

    return $EXIT_SUCCESS;
}

=head2 _file_mode

The mode to apply to a single file: files in the configuration directory and
the configuration version file are not readable by others, and secret files are
only readable by the pf group.
The path is canonicalized first, so that a path like /usr/local/pf//conf/pf.conf
gets the same mode as /usr/local/pf/conf/pf.conf

=cut

sub _file_mode {
    my ($file) = @_;
    my $path = _canonical_path($file);
    return $SECRET_FILE_MODE if grep { $path eq _canonical_path($_) } @secret_config_files;
    return $CONF_FILE_MODE if $path eq _canonical_path($config_version_file);
    return $CONF_FILE_MODE if index($path, _canonical_path($conf_dir) . "/") == 0;
    return $FILE_MODE;
}

sub _canonical_path {
    my ($path) = @_;
    return abs_path($path) // $path;
}

=head2 _removeOthersPermissions

Remove the permissions of others on the regular files under the given directories,
as the Debian package does on the files in the configuration directory.
Only the files owned by the pf user or the pf group are changed, so that pf can still read them.

=cut

sub _removeOthersPermissions {
    my (@paths) = @_;
    my ($pf_uid, $pf_gid) = ($pf::constants::user::PF_UID, $pf::constants::user::PF_GID);
    return unless defined $pf_uid && defined $pf_gid;
    finddepth({no_chdir => 1, untaint => 1, wanted => sub {
        my $file = $File::Find::name;
        return if -l $file;
        my ($mode, $uid, $gid) = (lstat($file))[2, 4, 5];
        return unless defined $mode && -f _;
        return unless $mode & 07;
        return unless $uid == $pf_uid || $gid == $pf_gid;
        chmod($mode & 07770, untaint_chain($file))
            or warn qq(Couldn't change the mode of "$file"\n);
    }}, @paths);
}

sub _changeFilesToOwner {
    my ($user, @files) = @_;
    my ($uid, $gid);
    if ($user eq 'pf') {
        $uid = $pf::constants::user::PF_UID;
        $gid = $pf::constants::user::PF_GID;
    } else {
        (my $login, my $pass, $uid, $gid) = getpwnam($user);
    }

    if(defined $uid && defined $gid) {
        my ($group, undef, undef, undef)= getgrgid($gid);
        chown $uid, $gid, @files;
    }
    else {
        my $msg = "Problem getting group and user id for $user\n";
        print STDERR $msg;
        get_logger->error($msg);
    }
}

sub _changePathToOwnerRecursive {
    my ($user,@paths) = @_;
    my ($login,$pass,$uid,$gid) = getpwnam($user);
    if(defined $uid && defined $gid) {
        my ($group, undef, undef, undef)= getgrgid($gid);
        finddepth ({no_chdir=>1, untaint=>1, wanted=>sub {
            if( ! -l $File::Find::name) {
              chown ($uid, $gid, untaint_chain($File::Find::name))
                  or warn qq(Couldn't change ownership of "$File::Find::name\n");
            }
        }}, @paths);
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

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

