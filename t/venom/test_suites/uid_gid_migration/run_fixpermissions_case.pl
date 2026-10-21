#!/usr/bin/perl
# Load the real pfcmd action with isolated dependencies and filesystem fixtures.
use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use FindBin;
use Errno qw(EACCES);

our ($failure_operation, $failure_path);

BEGIN {
    # Fault injection applies to the real permission helpers as they compile.
    *CORE::GLOBAL::chown = sub {
        if (($failure_operation // '') eq 'chown' && grep { $_ eq $failure_path } @_[2..$#_]) {
            $! = EACCES;
            return 0;
        }
        return CORE::chown(@_);
    };
    *CORE::GLOBAL::chmod = sub {
        if (($failure_operation // '') eq 'chmod' && grep { $_ eq $failure_path } @_[1..$#_]) {
            $! = EACCES;
            return 0;
        }
        return CORE::chmod(@_);
    };
    *CORE::GLOBAL::getpwnam = sub {
        return CORE::getpwuid($>) if $_[0] eq 'pf' || $_[0] eq 'fingerbank';
        return CORE::getpwnam($_[0]);
    };

    $INC{$_} = __FILE__ for qw(
        pf/base/cmd/action_cmd.pm pf/file_paths.pm pf/log.pm pf/constants/exit_code.pm
        pf/constants.pm pf/constants/user.pm pf/util.pm fingerbank/Util.pm
    );
}

{
    package pf::base::cmd::action_cmd;
    sub default_action { 'all' }
    package pf::file_paths;
    use Exporter 'import';
    our @EXPORT_OK = qw($bin_dir $var_dir @log_files @stored_config_files $install_dir
        $tt_compile_cache_dir $generated_conf_dir $pfconfig_cache_dir $log_dir
        $conf_dir $html_dir $lib_dir $config_version_file);
    our ($bin_dir, $var_dir, @log_files, @stored_config_files, $install_dir,
        $tt_compile_cache_dir, $generated_conf_dir, $pfconfig_cache_dir, $log_dir,
        $conf_dir, $html_dir, $lib_dir, $config_version_file);
    package pf::log;
    use Exporter 'import';
    our @EXPORT = qw(get_logger);
    sub get_logger { bless {}, __PACKAGE__ }
    sub error { }
    package pf::constants::exit_code;
    use Exporter 'import';
    our @EXPORT_OK = qw($EXIT_SUCCESS $EXIT_FAILURE);
    our $EXIT_SUCCESS = 0;
    our $EXIT_FAILURE = 1;
    package pf::constants;
    use Exporter 'import';
    our @EXPORT_OK = qw($DIR_MODE $PFCMD_MODE);
    our $DIR_MODE = 02775;
    our $PFCMD_MODE = 06755;
    package pf::constants::user;
    our $PF_UID = $>;
    our $PF_GID = (CORE::getpwuid($>))[3];
    package pf::util;
    use Exporter 'import';
    our @EXPORT = qw(untaint_chain);
    sub untaint_chain { $_[0] }
    package fingerbank::Constant;
    our $FINGERBANK_USER = 'fingerbank';
    our $FILE_PERMISSIONS = 0664;
    our $PATH_PERMISSIONS = 0775;
    package fingerbank::FilePath;
    our ($INSTALL_PATH, @FILES, @PATHS);
    package fingerbank::Util;
    sub fix_permissions {
        # Emulate older Fingerbank releases: both operations can fail silently.
        my (undef, undef, $uid, $gid) = getpwnam('fingerbank');
        for my $path (@fingerbank::FilePath::FILES, @fingerbank::FilePath::PATHS) {
            my $mode = -d $path ? 0775 : 0664;
            $mode = 0775 if $path eq $fingerbank::FilePath::INSTALL_PATH . 'db/upgrade.pl';
            chown($uid, $gid, $path);
            chmod($mode, $path);
        }
        return 1;
    }
}

my $case = shift // die "Missing test case\n";
die "This fixture must run as root in the test VM/container\n" unless $> == 0;
my $root = tempdir(CLEANUP => 1);
$pf::file_paths::install_dir = "$root/pf";
$pf::file_paths::bin_dir = "$root/pf/bin";
$pf::file_paths::var_dir = "$root/pf/var";
$pf::file_paths::conf_dir = "$root/pf/conf";
$pf::file_paths::lib_dir = "$root/pf/lib";
$pf::file_paths::html_dir = "$root/pf/html";
$pf::file_paths::log_dir = "$root/pf/logs";
$pf::file_paths::generated_conf_dir = "$root/pf/var/conf";
$pf::file_paths::tt_compile_cache_dir = "$root/pf/var/cache/tt";
$pf::file_paths::pfconfig_cache_dir = "$root/pf/var/cache/pfconfig";
$pf::file_paths::config_version_file = "$root/pf/var/conf/config_version";
@pf::file_paths::stored_config_files = ("$root/pf/conf/pf.conf", "$root/pf/conf/optional.conf");
$fingerbank::FilePath::INSTALL_PATH = "$root/fingerbank/";
@fingerbank::FilePath::PATHS = ("$root/fingerbank/", map { "$root/fingerbank/$_" } qw(conf db logs));
@fingerbank::FilePath::FILES = ("$root/fingerbank/conf/fingerbank.conf", "$root/fingerbank/db/upgrade.pl",
    "$root/fingerbank/logs/optional.log");
make_path(map { "$root/pf/$_" } qw(bin lib html logs conf var/conf var/redis_cache var/redis_queue));
make_path(@fingerbank::FilePath::PATHS);
for my $file ("$root/pf/bin/pfcmd", "$root/pf/conf/pf.conf", "$root/pf/html/index.html",
              $pf::file_paths::config_version_file, @fingerbank::FilePath::FILES[0, 1]) {
    open(my $fh, '>', $file) or die "$file: $!";
    close($fh);
    CORE::chmod(0600, $file) == 1 or die "$file: $!";
}

my %failures = (
    pf_chown => ['chown', "$root/pf/conf/pf.conf"],
    pf_chmod => ['chmod', "$root/pf/conf/pf.conf"],
    html_chown => ['chown', "$root/pf/html/index.html"],
    fingerbank_chown => ['chown', "$root/fingerbank/conf/fingerbank.conf"],
    fingerbank_chmod => ['chmod', "$root/fingerbank/conf/fingerbank.conf"],
    legacy => ['chmod', "$root/pf/conf/pf.conf"],
);
if (exists $failures{$case}) {
    ($failure_operation, $failure_path) = @{$failures{$case}};
    if ($case eq 'fingerbank_chown') {
        CORE::chown(65534, 65534, $failure_path) == 1 or die "$failure_path: $!";
    }
} elsif ($case eq 'missing_fingerbank_dir') {
    rmdir "$root/fingerbank/logs" or die $!;
} elsif ($case eq 'dangling_symlink') {
    symlink("$root/missing", "$root/pf/conf/optional.conf") or die $!;
} elsif ($case ne 'success') {
    die "Unknown test case $case\n";
}

require "$FindBin::Bin/../../../../lib/pf/cmd/pf/fixpermissions.pm";
my $cmd = bless {}, 'pf::cmd::pf::fixpermissions';
my $result = $case eq 'legacy' ? $cmd->action_all() : $cmd->action_strict();
print "FIXPERMISSIONS_EXIT=$result\n";
exit $result;
