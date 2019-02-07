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

extends 'Catalyst::Model';

our $dbHandler;


=head1 METHODS

=head2 assign

=cut

sub assign {
    my ( $self, $db, $user, $password ) = @_;
    my $logger = get_logger();

    my $status_msg;

    $db = $dbHandler->quote_identifier($db);

    # Create global PF user
    foreach my $host ("'%'","localhost") {
        my $sql_query = "GRANT SELECT,INSERT,UPDATE,DELETE,EXECUTE,LOCK TABLES ON $db.* TO ?\@${host} IDENTIFIED BY ?";
        $dbHandler->do($sql_query, undef, $user, $password);
        if ( $DBI::errstr ) {
            $status_msg = "Error creating the user $user on database $db";
            $logger->warn("$DBI::errstr");
            return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
        }
        $sql_query = "GRANT DROP ON $db.radius_nas TO ?\@${host} IDENTIFIED BY ?";
        $dbHandler->do($sql_query, undef, $user, $password);
        if ( $DBI::errstr ) {
            $status_msg = "Error creating the user $user on database $db";
            $logger->warn("$DBI::errstr");
            return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
        }
        $sql_query = "GRANT SELECT ON mysql.proc TO ?\@${host} IDENTIFIED BY ?";
        $dbHandler->do($sql_query, undef, $user, $password);
        if ( $DBI::errstr ) {
            $status_msg = "Error creating the user $user on database $db";
            $logger->warn("$DBI::errstr");
            return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
        }
    }
    # Apply the new privileges
    $dbHandler->do("FLUSH PRIVILEGES");
    if ( $DBI::errstr ) {
        $status_msg = ["Error creating the user [_1] on database [_2]",$user,$db];
        $logger->warn("$DBI::errstr");
        return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
    }
    $status_msg = ["Successfully created the user [_1] on database [_2]",$user,$db];


    # return original status message
    return ( $STATUS::OK, $status_msg );
}

=head2 connect

=cut

sub connect {
    my ( $self, $db, $user, $password ) = @_;
    my $logger = get_logger();

    my $status_msg;

    $dbHandler = DBI->connect( "dbi:mysql:dbname=$db;host=localhost;port=3306", $user, $password );
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

    # Instantiate a DBI driver
    my $dbDriver = DBI->install_driver("mysql");
    if ( !$dbDriver ) {
        $status_msg = ["Error in creating the database [_1]",$db];
        $logger->warn($DBI::errstr);
        return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
    }

    # Create the requested database
    $result = $dbDriver->func('createdb', $db, 'localhost', $root_user, $root_password, 'admin');
    if ( !$result ) {
        $status_msg = ["Error in creating the database [_1]",$db];
        $logger->warn($DBI::errstr);
        return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
    }

    $status_msg = ["Successfully created the database [_1]",$db];

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
    my $sql_query = "UPDATE mysql.user SET Password=PASSWORD(?) WHERE User=?";
    $dbHandler->do($sql_query, undef, $root_password, $root_user);
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

TODO: Check error handling for pf_run... (undef or whatever)

TODO: sanitize parameters going into pf_run with strict regex

=cut

sub schema {
    my ( $self, $db, $root_user, $root_password ) = @_;
    my $logger = get_logger();

    my ( $status_msg, $result );
    $root_user = quotemeta ($root_user);
    $root_password = quotemeta ($root_password);
    $db = quotemeta ($db);
    my $mysql_cmd = "/usr/bin/mysql -u $root_user -p$root_password $db";
    my $cmd = "$mysql_cmd < $install_dir/db/pf-schema.sql";
    eval { $result = pf_run($cmd, (accepted_exit_status => [ 0 ]), log_strip => quotemeta("-p$root_password")) };
    if ( $@ || !defined($result) ) {
        $status_msg = ["Error applying the schema to the database [_1]",$db ];
        $logger->warn("$@: $result");
        return ( $STATUS::INTERNAL_SERVER_ERROR, $status_msg );
    }
    my @custom_schemas = read_dir( "$install_dir/db/custom", prefix => 1, err_mode => 'quiet' ) ;
    @custom_schemas = sort @custom_schemas;
    foreach my $custom_schema (@custom_schemas) {
        my $cmd = "$mysql_cmd < $custom_schema";
        eval { $result = pf_run($cmd, (accepted_exit_status => [ 0 ], log_strip => quotemeta("-p$root_password"))) };
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

Copyright (C) 2005-2019 Inverse inc.

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
