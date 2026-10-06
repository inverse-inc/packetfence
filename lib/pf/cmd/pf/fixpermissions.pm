package pf::cmd::pf::fixpermissions;
=head1 NAME

pf::cmd::pf::fixpermissions add documentation

=head1 SYNOPSIS

 pfcmd fixpermissions <command>

 Commands :
  all                             | executes a fix on the permissions on all PF files
  strict                          | fixes permissions and fails if an existing path cannot be repaired
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
);
use pf::log;
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE);
use pf::constants qw($DIR_MODE $PFCMD_MODE);
use pf::constants::user;
use pf::util;
use File::Find;
use Errno qw(ENOENT);

use fingerbank::Util;

use File::Spec::Functions qw(catfile);

sub default_action { 'all' }

our $STRICT = 0;

sub action_strict {
    my ($self) = @_;
    local $STRICT = 1;
    my $ok = eval { $self->action_all(); 1 };
    unless ($ok) {
        print STDERR "Permission repair failed: $@";
        return $EXIT_FAILURE;
    }
    return $EXIT_SUCCESS;
}

# Some configuration files and generated directories are optional. Skip only
# absent paths; inaccessible paths and dangling symlinks must still fail.
sub _apply_strict {
    my ($operation, $apply, @paths) = @_;
    foreach my $path (@paths) {
        unless (lstat($path)) {
            next if $! == ENOENT;
            die "Cannot inspect $path: $!\n";
        }
        $apply->($path) == 1 or die "Cannot $operation $path: $!\n";
    }
}

sub _chmod {
    my ($mode, @paths) = @_;
    if ($STRICT) {
        _apply_strict('chmod', sub { chmod($mode, $_[0]) }, @paths);
    } else {
        chmod($mode, @paths);
    }
}

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
    _chmod($PFCMD_MODE, $pfcmd);
    _chmod(0664, @stored_config_files, $config_version_file);
    _chmod($DIR_MODE, $conf_dir, $var_dir, "$var_dir/redis_cache", "$var_dir/redis_queue");
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
        chmod 0664, $file;
        print "Fixed permissions on file $file \n";
    }

    return $EXIT_SUCCESS;
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
        if ($STRICT) {
            _apply_strict('chown', sub { chown($uid, $gid, $_[0]) }, @files);
        } else {
            chown $uid, $gid, @files;
        }
    }
    else {
        my $msg = "Problem getting group and user id for $user\n";
        die $msg if $STRICT;
        print STDERR $msg;
        get_logger->error($msg);
    }
}

sub _changePathToOwnerRecursive {
    my ($user,@paths) = @_;
    my ($login,$pass,$uid,$gid) = getpwnam($user);
    if(defined $uid && defined $gid) {
        my ($group, undef, undef, undef)= getgrgid($gid);
        # File::Find warns and skips directories it cannot traverse.
        local $SIG{__WARN__} = sub { die @_ } if $STRICT;
        finddepth ({no_chdir=>1, untaint=>1, wanted=>sub {
            if( ! -l $File::Find::name) {
              chown ($uid, $gid, untaint_chain($File::Find::name))
                  or warn qq(Couldn't change ownership of "$File::Find::name\n");
            }
        }}, @paths);
    }
    else {
        my $msg = "Problem getting group and user id for $user\n";
        die $msg if $STRICT;
        print STDERR $msg;
        get_logger->error($msg);
    }
}


sub _fingerbank {
    fingerbank::Util::fix_permissions();
    return unless $STRICT;

    # Older Fingerbank helpers ignore failed chown/chmod calls. Check their
    # postconditions without requiring a new Fingerbank package for this upgrade.
    my (undef, undef, $uid, $gid) = getpwnam($fingerbank::Constant::FINGERBANK_USER);
    defined($uid) && defined($gid) or die "Cannot look up the Fingerbank account\n";
    my %modes = (
        (map { $_ => $fingerbank::Constant::FILE_PERMISSIONS } @fingerbank::FilePath::FILES),
        (map { $_ => $fingerbank::Constant::PATH_PERMISSIONS } @fingerbank::FilePath::PATHS),
        $fingerbank::FilePath::INSTALL_PATH . 'db/upgrade.pl' => 0775,
    );
    my %required = map { $_ => 1 } @fingerbank::FilePath::PATHS;
    foreach my $path (sort keys %modes) {
        unless (lstat($path)) {
            next if $! == ENOENT && !$required{$path};
            die "Cannot inspect $path: $!\n";
        }
        my @stat = stat($path);
        @stat or die "Cannot stat $path: $!\n";
        if ($stat[4] != $uid || $stat[5] != $gid || ($stat[2] & 07777) != $modes{$path}) {
            die sprintf("Incorrect permissions on %s: got %s:%s %04o, expected %s:%s %04o\n",
                $path, $stat[4], $stat[5], $stat[2] & 07777, $uid, $gid, $modes{$path});
        }
    }
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

