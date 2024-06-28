package pfappserver::Model::DB;

=head1 NAME

pfappserver::Model::DB - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use strict;
use warnings;

use DBI;
use Moose;
use namespace::autoclean;

use pf::log;
use pf::config;
use pf::file_paths qw($install_dir);
use pf::error;
use pf::util;
use File::Slurp qw(read_dir);
use File::Temp qw(tempfile);

extends 'Catalyst::Model';

our $dbHandler;


=head1 METHODS

=head2 assign

=cut

sub assign {
    my ( $self, $db, $user, $password ) = @_;
    return $self->_assign($dbHandler, $db, $user, $password);
}

sub get_db_type {
    my ($dbh) = @_;
    my $data = $dbh->selectrow_arrayref("SELECT VERSION()");
    if (!defined $data || !@$data) {
        return
    }

    my $version = $data->[0];
    ($version, my $type) = split('-', $version);
    $type //= "MySQL";
    return ($version, $type);
}

sub assign_database {
    my ($self, $args) = @_;
    my $logger = get_logger();
    my $db = delete $args->{database};
    $args->{database} = '';
    my ($dbh, undef, $user) = connect_to_database($args);
    if (!$dbh) {
        $logger->warn("$DBI::errstr");
        return ( $STATUS::INTERNAL_SERVER_ERROR, [ "Error creating the user $user on database $db}"] );
    }

    return $self->_assign($dbh, $db, $args->{pf_username}, $args->{pf_password});
}

sub _assign {
    my ($self, $dbh, $db, $user, $password ) = @_;
    my $logger = get_logger();

    my $status_msg;
    my ($version, $type) = get_db_type($dbh);
    $db = $dbh->quote_identifier($db);

    # Create global PF user
    foreach my $host ("'%'","localhost") {
        my $sql_query = "DROP USER IF EXISTS ?\@${host}";
        $dbh->do($sql_query, undef, $user);
        if ( $DBI::errstr ) {
            $status_msg = "Error creating the user $user on database $db";
            $logger->warn("$DBI::errstr");
            return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
        }

        $sql_query = "CREATE USER ?\@${host} IDENTIFIED BY ?";
        $dbh->do($sql_query, undef, $user, $password);
        if ( $DBI::errstr ) {
            $status_msg = "Error creating the user $user on database $db";
            $logger->warn("$DBI::errstr");
            return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
        }

        $sql_query = "GRANT DROP,SELECT,INSERT,UPDATE,DELETE,EXECUTE,LOCK TABLES,CREATE TEMPORARY TABLES ON $db.* TO ?\@${host}";
        $dbh->do($sql_query, undef, $user);
        if ( $DBI::errstr ) {
            $status_msg = "Error creating the user $user on database $db";
            $logger->warn("$DBI::errstr");
            return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
        }

        $sql_query = "GRANT CREATE,DROP ON $db.radius_nas TO ?\@${host}";
        $dbh->do($sql_query, undef, $user);
        if ( $DBI::errstr ) {
            $status_msg = "Error creating the user $user on database $db";
            $logger->warn("$DBI::errstr");
            return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
        }

        if ($type ne 'MySQL') {
            $sql_query = "GRANT SELECT ON mysql.proc TO ?\@${host}";
            $dbh->do($sql_query, undef, $user);
            if ( $DBI::errstr ) {
                $status_msg = "Error creating the user $user on database $db";
                $logger->warn("$DBI::errstr");
                return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
            }
        }


        $sql_query = $type eq 'MySQL' ? "GRANT BINLOG_ADMIN ON *.* TO ?\@${host}" : "GRANT BINLOG ADMIN ON *.* TO ?\@${host}";
        $dbh->do($sql_query, undef, $user);
        if ( $DBI::errstr ) {
            $status_msg = "Error granting BINLOG ADMIN for user $user on database $db";
            $logger->warn("$DBI::errstr");
            return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
        }
    }
    # Apply the new privileges
    $dbh->do("FLUSH PRIVILEGES");
    if ( $DBI::errstr ) {
        $status_msg = ["Error creating the user [_1] on database [_2]",$user,$db];
        $logger->warn("$DBI::errstr");
        return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
    }

    $status_msg = ["Successfully created the user [_1] on database [_2]",$user,$db];

    # return original status message
    return ( $STATUS::OK, $status_msg );
}

sub connect_to_database {
    my ($args) = @_;
    my $fh;
    $args->{database} //= "mysql";
    $args->{hostname} ||= "localhost";
    if ($args->{remote}{ca_cert}) {
        ($fh, my $filename) = tempfile();
        print $fh $args->{remote}{ca_cert};
        $fh->flush();
        $fh->close();
        $args->{remote}{ca_file} = $filename;
    }

    my ($connect_str, $user, $password) = make_connection_str($args);
    my $dbh = DBI->connect($connect_str, $user, $password);
    return $dbh, $args->{database}, $user;
}

sub test_connection {
    my ($self, $args) = @_;
    my $logger = get_logger();
    my ($dbh, $db, $user) = connect_to_database($args);
    if ( !$dbh ) {
        my $status_msg = ["Error in connection to the database [_1] with user [_2]",$db,$user];
        $logger->warn("$DBI::errstr");
        return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
    }

    my $status_msg = ["Successfully connected to the database [_1] with user [_2]",$db,$user];
    return ( $STATUS::OK, $status_msg );
}

sub make_connection_str {
    my ($args) = @_;
    my $dsn = "DBI:mysql:dbname=$args->{database}";
    if (!$args->{is_remote}) {
        return (
            "$dsn;mysql_socket=/var/lib/mysql/mysql.sock",
            $args->{username},
            $args->{password},
        );
    }

    my $remote = $args->{remote};
    $dsn .= ";host=$remote->{hostname}";
    my $port = $remote->{port} // '3306';
    $dsn .= ";port=$port";
    if ($remote->{encryption} eq "tls") {
        $dsn .= ";mysql_ssl=1";
        if ($remote->{ca_file}) {
            $dsn .= ";mysql_ssl_ca_file=$remote->{ca_file}";
        }
    }

    return (
        $dsn,
        $remote->{username},
        $remote->{password},
    );
}

=head2 connect

=cut

sub connect {
    my ( $self, $db, $user, $password ) = @_;
    my $logger = get_logger();

    my $status_msg;

    $dbHandler = DBI->connect( "dbi:mysql:dbname=$db;host=localhost;port=3306;mysql_socket=/var/lib/mysql/mysql.sock", $user, $password );
    if ( !$dbHandler ) {
        $status_msg = ["Error in connection to the database [_1] with user [_2]",$db,$user];
        $logger->warn("$DBI::errstr");
        return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
    }

    $status_msg = ["Successfully connected to the database [_1] with user [_2]",$db,$user];
    return ( $STATUS::OK, $status_msg );
}

=head2 create

=cut

sub create {
    my ( $self, $db, $root_user, $root_password ) = @_;
    my $logger = get_logger();

    my ( $status_msg, $result );

    my $dbh = DBI->connect("dbi:mysql:mysql_socket=/var/lib/mysql/mysql.sock", $root_user, $root_password);
    $result = $dbh->do("CREATE DATABASE $db DEFAULT CHARACTER SET = 'utf8mb4'");
    if ( !$result ) {
        $status_msg = ["Error in creating the database [_1]",$db];
        $logger->warn($DBI::errstr);
        return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
    }

    $status_msg = ["Successfully created the database [_1]",$db];

    # return original status message
    return ( $STATUS::OK, $status_msg );
}

sub make_mysql_command {
    my ($args) = @_;
    if ($args->{is_remote}) {
        return make_remote_mysql_command($args);
    }

    my $user = $args->{username};
    my $password = $args->{password};
    my $db = quotemeta ($args->{database});
    my $mysql_cmd = ['/usr/bin/mysql', '--socket=/var/lib/mysql/mysql.sock', '-u', $user, "-p$password", $db];
    return ($mysql_cmd, undef, "-p$password");
}

sub make_remote_mysql_command {
    my ($args) = @_;
    my $remote = $args->{remote};
    my $mysql_cmd = "/usr/bin/mysql";
    if ($remote->{encryption} eq 'tls') {
        $mysql_cmd .= " --ssl";
    }

    if ($remote->{port}) {
        $mysql_cmd .= " -P".  quotemeta($remote->{port});
    }

    my $fh = make_file_for_cert($remote);
    if ($remote->{ca_file}) {
        $mysql_cmd .= " --ssl-ca=".  $remote->{ca_file};
    }

    my $host = quotemeta ($remote->{hostname});
    my $user = quotemeta ($remote->{username});
    my $password = quotemeta ($remote->{password});
    my $db = quotemeta ($args->{database});
    $mysql_cmd .= " -h$host -u$user -p$password $db";
    return ($mysql_cmd, $fh, "-p$password");
}

sub make_file_for_cert {
    my ($remote_args) = @_;
    if (!$remote_args->{ca_cert}) {
        return undef;
    }

    my ($fh, $filename) = tempfile();
    print $fh $remote_args->{ca_cert};
    $fh->flush();
    $fh->close();
    $remote_args->{ca_file} = $filename;
    return $fh;
}

sub apply_schema {
    my ( $self, $args) = @_;
    my $logger = get_logger();

    my ( $status_msg, $result );
    my ($mysql_cmd, $fh, $log_strip) = make_mysql_command($args);
    my $db = $args->{database};
    eval { $result = safe_pf_run(@$mysql_cmd, {stdin => "$install_dir/db/pf-schema.sql", accepted_exit_status => [ 0 ], log_strip => $log_strip}) };
    if ( $@ || !defined($result) ) {
        $status_msg = ["Error applying the schema to the database [_1]", $db ];
        $logger->warn("$@: $result");
        return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
    }
    my @custom_schemas = read_dir( "$install_dir/db/custom", prefix => 1, err_mode => 'quiet' ) ;
    @custom_schemas = sort @custom_schemas;
    foreach my $custom_schema (@custom_schemas) {
        eval { $result = safe_pf_run(@$mysql_cmd, {stdin => $custom_schema, accepted_exit_status => [ 0 ], log_strip => $log_strip}) };
        if ( $@ || !defined($result) ) {
            $status_msg = ["Error applying the custom schema $custom_schema to the database [_1]", $db ];
            $logger->warn("$@: $result");
            return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
        }
    }

    $status_msg = ["Successfully applied the schema to the database [_1]", $db];
    # return original status message
    return ( $STATUS::OK, $status_msg );
}

=head2 create_database

=cut

sub create_database {
    my ( $self, $args ) = @_;
    my $db = $args->{database};
    my $logger = get_logger();
    my ( $status_msg, $result );
    my ($dbh, undef, $user) = connect_to_database({%$args, database => ''});
    if (!$dbh) {
        $status_msg = ["Error in creating the database [_1]",$db];
        $logger->warn($DBI::errstr);
        return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
    }

    my $db_quoted = $dbh->quote_identifier($db);
    $result = $dbh->do("CREATE DATABASE $db_quoted DEFAULT CHARACTER SET = 'utf8mb4'");
    if ( !$result ) {
        $status_msg = ["Error in creating the database [_1]", $db];
        $logger->warn($DBI::errstr);
        return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
    }

    $status_msg = ["Successfully created the database [_1]", $db];
    # return original status message
    return ( $STATUS::OK, $status_msg );
}

=head2 secureInstallation

Intended to integrate the "/usr/bin/mysql_secure_installation" steps

1. Set a password for the database "root" user (different from the Linux root user!), which is blank by default;

2. Delete "anonymous" users, i.e. users with the empty string as user name;

3. Ensure the root user can not log in remotely;

4. Remove the database named "test";

5. Flush the privileges tables, i.e. ensure that the changes to user access applied in the previous steps are committed immediately.

=cut

sub secureInstallation {
    my ( $self, $root_user, $root_password ) = @_;
    my $logger = get_logger();

    my ($status, $status_msg);

    # 1. Set a password for the database "root" user (different from the Linux root user!), which is blank by default;
    my $sql_query = "set password for ?\@'localhost'  = password(?)";
    $dbHandler->do($sql_query, undef, $root_user, $root_password);
    if ( $DBI::errstr ) {
        $status_msg = ["Error changing root user [_1] password",$root_user ];
        $logger->warn($DBI::errstr);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    # 2. Delete "anonymous" users, i.e. users with the empty string as user name;
    $dbHandler->do("DELETE FROM mysql.user WHERE User=''");
    if ( $DBI::errstr ) {
        $status_msg = ["Error deleting MySQL anonymous users" ];
        $logger->warn($DBI::errstr);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    # 3. Ensure the root user can not log in remotely;
    $sql_query = "DELETE FROM mysql.user WHERE User=? AND Host NOT IN ('localhost', '127.0.0.1', '::1')";
    $dbHandler->do($sql_query, undef, $root_user);
    if ( $DBI::errstr ) {
        $status_msg = ["Error setting correct permissions to root user [_1]",$root_user ];
        $logger->warn($DBI::errstr);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    # 4. Remove the database named "test";
    $dbHandler->do("DROP DATABASE IF EXISTS test");
    if ( $DBI::errstr ) {
        $status_msg = ["Error dropping the 'test' database" ];
        $logger->warn($DBI::errstr);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }
    $dbHandler->do("DELETE FROM mysql.db WHERE Db='test' OR Db='test_%'");
    if ( $DBI::errstr ) {
        $status_msg = ["Error removing the 'test' database privileges" ];
        $logger->warn($DBI::errstr);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    # 5. Flush the privileges tables, i.e. ensure that the changes to user access applied in the previous steps are committed immediately.
    $dbHandler->do("FLUSH PRIVILEGES");
    if ( $DBI::errstr ) {
        $status_msg = ["Error applying new privileges to root user [_1]",$root_user ];
        $logger->warn($DBI::errstr);
        return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
    }

    $status_msg = "Successfully secured mysql installation";
    $logger->info($status_msg);
    return ($STATUS::OK, $status_msg);
}

=head2 schema

TODO: Check error handling for safe_pf_run... (undef or whatever)

TODO: sanitize parameters going into safe_pf_run with strict regex

=cut

sub schema {
    my ( $self, $db, $root_user, $root_password ) = @_;
    my $logger = get_logger();

    my ( $status_msg, $result );
    my @mysql_cmd = ('/usr/bin/mysql', '--socket=/var/lib/mysql/mysql.sock', '-u', $root_user, "-p$root_password", $db);
    eval { $result = safe_pf_run(@mysql_cmd, {stdin => "$install_dir/db/pf-schema.sql", accepted_exit_status => [ 0 ], log_strip => $root_password}) };
    if ( $@ || !defined($result) ) {
        $status_msg = ["Error applying the schema to the database [_1]",$db ];
        $logger->warn("$@: $result");
        return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
    }
    my @custom_schemas = read_dir( "$install_dir/db/custom", prefix => 1, err_mode => 'quiet' ) ;
    @custom_schemas = sort @custom_schemas;
    foreach my $custom_schema (@custom_schemas) {
        eval { $result = safe_pf_run(@mysql_cmd, {stdin => $custom_schema, accepted_exit_status => [ 0 ], log_strip => $root_password}) };
        if ( $@ || !defined($result) ) {
            $status_msg = ["Error applying the custom schema $custom_schema to the database [_1]",$db ];
            $logger->warn("$@: $result");
            return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
        }
    }
    $status_msg = ["Successfully applied the schema to the database [_1]",$db ];


    # return original status message
    return ( $STATUS::OK, $status_msg );
}

=head2 resetUserPassword

=cut

sub resetUserPassword {
    my ( $self, $user, $password ) = @_;
    my $logger = get_logger();

    my ( $status, $status_msg );
    # Making sure username/password are "ok"
    if (   !defined($user)
        || !defined($password)
        || ( length($user) == 0 )
        || ( length($password) == 0 ) )
    {
        $status_msg = [ "Error while changing the password of [_1].", $user ];
        return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
    }

    # Doing the update
    if ( pf::password::reset_password( $user, $password ) ) {
        $status_msg =
          [ "The password of [_1] was successfully modified.", $user ];
        return ( $STATUS::OK, $status_msg );
    }
    else {
        $logger->warn("Error while changing the password of $user");
        $status_msg = [ "Error while changing the password of [_1].", $user ];
        return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
    }
}

=head1 AUTHORS

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
