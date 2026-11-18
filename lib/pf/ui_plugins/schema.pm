package pf::ui_plugins::schema;

=head1 NAME

pf::ui_plugins::schema - the database tables of the packages installed on top of PacketFence

=head1 SYNOPSIS

    use pf::ui_plugins::schema;

    # the package postinst / %post
    pf::ui_plugins::schema::apply('acme');

    # the service, before it starts
    my ($ok, $message) = pf::ui_plugins::schema::check('acme');

    # the package purge
    pf::ui_plugins::schema::drop('acme');

=head1 DESCRIPTION

A package that adds tables to the PacketFence database keeps its schema the
way PacketFence keeps its own (db/pf-schema-X.Y.sql, db/upgrade-X.Y-X.Z.sql):

=over

=item <name>-schema-X.Y.sql

the whole schema of version X.Y, for a fresh install

=item upgrade-X.Y-X.Z.sql

from version X.Y to version X.Z, for an upgrade

=item teardown.sql

drops the tables, when the package is purged

=back

Each file records its version in the plugin_version table, like a PacketFence
schema file records its version in pf_version, and an upgrade file starts with
CALL ValidatePluginVersion(<name>, <previous version>).

The package declares its name, its version and where these files are in its
descriptor, conf/plugins.d/<name>.conf:

    [plugin]
    version=1.0
    schema_dir=/usr/local/acme/db

apply runs the files the database needs to reach the version of the
descriptor with the mysql client, as the MariaDB root user, each in a session
where db/upgrade-helpers.sql is loaded first. The root user is reached through
the local socket without a password (as the PacketFence upgrade does), or
through a client options file (--defaults-file).

See https://github.com/akainverse/packetfence-plugin-example.

=cut

use strict;
use warnings;
use Config::IniFiles;
use File::Basename qw(basename);
use File::Copy qw(copy);
use File::Path qw(make_path remove_tree);
use File::Spec::Functions qw(catfile catdir file_name_is_absolute);
use pf::file_paths qw($ui_plugins_conf_dir $ui_plugins_var_dir $ui_plugins_upgrade_helpers_file);
use pf::error qw(is_error);

# keep in sync with pf::ui_plugins::NAME_RE (the registered name of the plugin)
our $NAME_RE = qr/^[a-z][a-z0-9_-]{0,62}\z/;
our $VERSION_RE = qr/^([0-9]{1,3})\.([0-9]{1,3})\z/;
our $MYSQL = 'mysql';
our $SOCKET = '/var/lib/mysql/mysql.sock';
our @HELPER_PROCEDURES = qw(ValidatePluginVersion CopyRowsInBatches AddColumnUnlessExists DropColumnIfExists AddIndexUnlessExists DropIndexIfExists);

=head2 version_int

    my $int = version_int('1.2'); # 1 << 16 | 2 << 8

The version as an integer that orders like the version, as the id of
plugin_version (and of pf_version). undef for an invalid version.

=cut

sub version_int {
    my ($version) = @_;
    return undef if !defined $version || $version !~ $VERSION_RE || $1 > 255 || $2 > 255;
    return $1 << 16 | $2 << 8;
}

=head2 descriptor

    my $descriptor = descriptor('acme');

The descriptor of the package: { name, version, version_int, schema_dir }.
Dies when it is missing or invalid.

=cut

sub descriptor {
    my ($name, $dir) = @_;
    $dir //= $ui_plugins_conf_dir;
    $name = check_name($name);
    my $file = catfile($dir, "$name.conf");
    die "no descriptor $file\n" if !-f $file;
    my $ini = Config::IniFiles->new(-file => $file, -allowempty => 1)
        or die "cannot read $file: @Config::IniFiles::errors\n";
    my $version = $ini->val('plugin', 'version');
    my $schema_dir = $ini->val('plugin', 'schema_dir');
    my $version_int = version_int($version);
    die sprintf("%s: invalid version \"%s\", expected X.Y\n", $file, $version // '') if !defined $version_int;
    if (!defined $schema_dir || !file_name_is_absolute($schema_dir) || !-d $schema_dir) {
        die sprintf("%s: schema_dir \"%s\" is not an absolute path to a directory\n", $file, $schema_dir // '');
    }
    return {
        name        => $name,
        version     => $version,
        version_int => $version_int,
        schema_dir  => $schema_dir,
    };
}

=head2 schema_files

    my $files = schema_files('acme', '/usr/local/acme/db');

The files of a schema directory:
{ schema => { 'X.Y' => file }, upgrade => { 'X.Y' => [ 'X.Z', file ] }, teardown => file }

=cut

sub schema_files {
    my ($name, $dir) = @_;
    my %files = (schema => {}, upgrade => {}, teardown => undef);
    opendir(my $dh, $dir) or die "cannot read $dir: $!\n";
    for my $entry (sort readdir($dh)) {
        my $file = catfile($dir, $entry);
        next if !-f $file;
        if ($entry =~ /^\Q$name\E-schema-([0-9]+\.[0-9]+)\.sql\z/ && defined version_int($1)) {
            $files{schema}{$1} = $file;
        } elsif ($entry =~ /^upgrade-([0-9]+\.[0-9]+)-([0-9]+\.[0-9]+)\.sql\z/ && defined version_int($1) && defined version_int($2)) {
            die "$dir: two upgrades from $1\n" if exists $files{upgrade}{$1};
            die "$dir: $entry does not go to a newer version\n" if version_int($2) <= version_int($1);
            $files{upgrade}{$1} = [$2, $file];
        } elsif ($entry eq 'teardown.sql') {
            $files{teardown} = $file;
        }
    }
    closedir($dh);
    return \%files;
}

=head2 plan

    my @steps = plan('acme', $installed, $target, $files);

The files to run to go from the installed version (undef: none) to the target
version, as [ file, version reached ] pairs. Dies when the files do not allow
it, or when the database is newer than the target.

=cut

sub plan {
    my ($name, $installed, $target, $files) = @_;
    my $target_int = version_int($target);
    if (!defined $installed) {
        my $file = $files->{schema}{$target}
          or die "no $name-schema-$target.sql to install version $target of $name\n";
        return ([$file, $target]);
    }
    my $installed_int = version_int($installed);
    die "invalid installed version \"$installed\" of $name\n" if !defined $installed_int;
    return () if $installed_int == $target_int;
    if ($installed_int > $target_int) {
        die "the database has version $installed of $name, newer than the package version $target\n";
    }
    my @steps;
    my $current = $installed;
    while (version_int($current) < $target_int) {
        my $upgrade = $files->{upgrade}{$current}
          or die "no upgrade-$current-*.sql to upgrade $name from $current to $target\n";
        my ($to, $file) = @$upgrade;
        die sprintf("%s goes past the package version %s\n", basename($file), $target) if version_int($to) > $target_int;
        push @steps, [$file, $to];
        $current = $to;
    }
    return @steps;
}

=head2 installed_version

    my $version = installed_version('acme');

The latest version of the package recorded in plugin_version, undef when none.

=cut

sub installed_version {
    my ($name) = @_;
    require pf::dal::plugin_version;
    my ($status, $iterator) = pf::dal::plugin_version->search(
        -where    => { name => $name },
        -order_by => { -desc => 'id' },
        -limit    => 1,
    );
    die "cannot read the plugin_version table\n" if is_error($status);
    my $row = $iterator->next;
    return $row ? $row->{version} : undef;
}

=head2 mysql_args

    my @args = mysql_args(defaults_file => $file);

The arguments of the mysql client, as the MariaDB root user.

=cut

sub mysql_args {
    my (%options) = @_;
    require pf::config;
    my $db = $pf::config::Config{database};
    my @args;
    if (my $defaults_file = $options{defaults_file}) {
        die "no options file $defaults_file\n" if !-r $defaults_file;
        push @args, "--defaults-file=" . _mysql_value('options file', $defaults_file, qr{\A[^\0\n]+\z});
    }
    if (!defined $db->{host} || $db->{host} eq 'localhost') {
        push @args, "--socket=" . _mysql_value('socket', $db->{unix_socket} || $SOCKET, qr{\A/[^\0\n]+\z});
    } else {
        push @args, "--host=" . _mysql_value('database host', $db->{host}, qr/\A[A-Za-z0-9.:_\[\]-]+\z/),
          "--port=" . _mysql_value('database port', $db->{port}, qr/\A[0-9]{1,5}\z/);
    }
    push @args, '--batch', '--database', _mysql_value('database', $db->{db}, qr/\A[A-Za-z0-9_\$-]+\z/);
    return @args;
}

=head2 can_connect

True when the mysql client connects with these arguments.

=cut

sub can_connect {
    my (@args) = @_;
    my $pid = fork() // die "cannot fork: $!\n";
    if (!$pid) {
        open(STDIN, '<', '/dev/null');
        open(STDOUT, '>', '/dev/null');
        open(STDERR, '>', '/dev/null');
        exec($MYSQL, @args, '-e', 'SELECT 1') or exit 127;
    }
    waitpid($pid, 0);
    return $? == 0;
}

=head2 run_file

    run_file($file, @args);

Runs a schema, upgrade or teardown file with the mysql client, after
db/upgrade-helpers.sql in the same session, and drops the helpers after it.
The files are sent on the standard input of the client, which stops at the
first error (an error in a file read with "source" does not stop it). Dies
when the client fails.

=cut

sub run_file {
    my ($file, @args) = @_;
    my $script = join("\n",
        _read_sql($ui_plugins_upgrade_helpers_file),
        _read_sql($file),
        'DELIMITER ;',
        (map { "DROP PROCEDURE IF EXISTS $_;" } @HELPER_PROCEDURES),
        '',
    );
    open(my $mysql, '|-', $MYSQL, @args) or die "cannot run $MYSQL: $!\n";
    print $mysql $script;
    close($mysql);
    if ($? != 0) {
        my $code = $? >> 8;
        # the client stopped at the error, before dropping the helpers
        if (open(my $cleanup, '|-', $MYSQL, @args)) {
            print $cleanup join("\n", (map { "DROP PROCEDURE IF EXISTS $_;" } @HELPER_PROCEDURES), '');
            close($cleanup);
        }
        die sprintf("%s failed (exit code %d)\n", basename($file), $code);
    }
    return 1;
}

sub _read_sql {
    my ($file) = @_;
    open(my $fh, '<', $file) or die "cannot read $file: $!\n";
    local $/;
    my $sql = <$fh>;
    close($fh);
    return $sql;
}

=head2 connection

    my @args = connection(%options);

The mysql client arguments for the root user: the --defaults-file of the
options, or the local socket without a password. Dies with the command to
run by hand when neither connects.

=cut

sub connection {
    my (%options) = @_;
    my @args = mysql_args(%options);
    return @args if can_connect(@args);
    my $how = $options{defaults_file}
      ? "with $options{defaults_file}"
      : "as root through $SOCKET without a password";
    die "cannot connect to the database $how\n";
}

=head2 apply

    my @applied = apply('acme', defaults_file => $file);

Brings the tables of the package to the version of its descriptor. Returns
the versions applied (none when it is up to date). Keeps a copy of
teardown.sql in var/plugins/<name>/ for drop, the package files are gone
when it is purged.

=cut

sub apply {
    my ($name, %options) = @_;
    $name = check_name($name);
    my $descriptor = descriptor($name, $options{conf_dir});
    my $files = schema_files($name, $descriptor->{schema_dir});
    _keep_teardown($name, $files->{teardown}) if $files->{teardown};
    my @steps = plan($name, installed_version($name), $descriptor->{version}, $files);
    return () if !@steps;

    my @args = connection(%options);
    my $lock = _lock($name);
    my @applied;
    for my $step (@steps) {
        my ($file, $version) = @$step;
        # another node of a cluster may have applied it meanwhile: they all use the same tables
        my $installed = installed_version($name);
        next if defined $installed && version_int($installed) >= version_int($version);
        run_file($file, @args);
        $installed = installed_version($name) // 'none';
        if ($installed ne $version) {
            die sprintf("%s did not record version %s of %s in plugin_version (found %s)\n", basename($file), $version, $name, $installed);
        }
        push @applied, $version;
    }
    return @applied;
}

=head2 check

    my ($ok, $message) = check('acme');

True when the tables of the package are at the version of its descriptor. It
only reads the database, as the PacketFence database user.

=cut

sub check {
    my ($name, %options) = @_;
    my $descriptor = eval { descriptor($name, $options{conf_dir}) };
    return (0, $@) if !$descriptor;
    my $installed = eval { installed_version($name) };
    return (0, $@) if $@;
    my $target = $descriptor->{version};
    if (!defined $installed) {
        return (0, "the tables of $name are not installed, run: pfcmd plugin schema apply $name\n");
    }
    my $installed_int = version_int($installed) // 0;
    if ($installed_int < $descriptor->{version_int}) {
        return (0, "the tables of $name are at version $installed, the package needs $target, run: pfcmd plugin schema apply $name\n");
    }
    if ($installed_int > $descriptor->{version_int}) {
        return (0, "the tables of $name are at version $installed, newer than the package version $target\n");
    }
    return (1, "the tables of $name are at version $installed\n");
}

=head2 drop

    drop('acme', force => 1);

Runs the teardown.sql of the package (from its schema directory, or the copy
kept by apply), then forgets its versions and its registration. On a cluster
the tables are shared by every node: it refuses unless force is set.

=cut

sub drop {
    my ($name, %options) = @_;
    $name = check_name($name);
    if (!$options{force} && _cluster_enabled()) {
        die "this server is a member of a cluster, the tables of $name are shared by every node: remove $name from every node, then run: pfcmd plugin schema drop $name --force\n";
    }
    my $teardown = _teardown_file($name, $options{conf_dir});
    die "no teardown.sql for $name\n" if !$teardown;
    my @args = connection(%options);
    my $lock = _lock($name);
    run_file($teardown, @args);
    require pf::dal::plugin_version;
    my ($status) = pf::dal::plugin_version->remove_items(-where => { name => $name });
    die "cannot remove the versions of $name from plugin_version\n" if is_error($status);
    require pf::ui_plugins;
    my $error;
    ($status, $error) = pf::ui_plugins::deregister($name);
    die "$error\n" if is_error($status);
    remove_tree(catdir($ui_plugins_var_dir, $name));
    return 1;
}

=head2 check_name

    $name = check_name($name);

Dies unless $name is a valid plugin name. Returns it untainted (pfcmd runs
in taint mode): it names files, directories and packages.

=cut

sub check_name {
    my ($name) = @_;
    die sprintf("invalid name \"%s\"\n", $name // '') if !defined $name || $name !~ $NAME_RE;
    return _untaint($name);
}

# a value checked by the caller, untainted
sub _untaint {
    my ($value) = @_;
    ($value) = $value =~ /\A(.*)\z/s;
    return $value;
}

# a value of the mysql client arguments, untainted once it matches $re
sub _mysql_value {
    my ($what, $value, $re) = @_;
    die sprintf("invalid %s \"%s\"\n", $what, $value // '') if !defined $value || $value !~ $re;
    return _untaint($value);
}

sub _keep_teardown {
    my ($name, $teardown) = @_;
    my $dir = catdir($ui_plugins_var_dir, $name);
    make_path($dir, { mode => 0750 });
    copy($teardown, catfile($dir, 'teardown.sql')) or die "cannot copy $teardown to $dir: $!\n";
}

sub _teardown_file {
    my ($name, $conf_dir) = @_;
    my $descriptor = eval { descriptor($name, $conf_dir) };
    if ($descriptor) {
        my $file = schema_files($name, $descriptor->{schema_dir})->{teardown};
        return $file if $file;
    }
    my $kept = catfile($ui_plugins_var_dir, $name, 'teardown.sql');
    return -f $kept ? $kept : undef;
}

sub _cluster_enabled {
    require pf::config::cluster;
    return $pf::config::cluster::cluster_enabled;
}

# one apply or drop of a package at a time on this server. GET_LOCK is not
# supported by Galera (as in pf::freeradius): on a cluster there is no lock,
# the package is installed on one node at a time (the files are idempotent,
# and ValidatePluginVersion keeps a node from applying an upgrade twice). The
# lock name is at most 64 characters (MySQL 5.7+).
sub _lock {
    my ($name) = @_;
    return undef if _cluster_enabled();
    require pf::db;
    require Digest::SHA;
    my $lock_name = 'plugin_schema_' . substr(Digest::SHA::sha256_hex($name), 0, 32);
    my $dbh = pf::db::db_connect() or die "cannot connect to the database\n";
    my ($locked) = $dbh->selectrow_array('SELECT GET_LOCK(?, 0)', undef, $lock_name);
    die "cannot lock the schema of $name: " . ($dbh->errstr // 'pfcmd plugin schema is already running for it') . "\n" if !$locked;
    return pf::ui_plugins::schema::lock->new($dbh, $lock_name);
}

package pf::ui_plugins::schema::lock;

sub new {
    my ($class, $dbh, $name) = @_;
    return bless { dbh => $dbh, name => $name }, $class;
}

sub DESTROY {
    my ($self) = @_;
    eval { $self->{dbh}->do('SELECT RELEASE_LOCK(?)', undef, $self->{name}) };
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
