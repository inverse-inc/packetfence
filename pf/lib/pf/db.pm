package pf::db;

=head1 NAME

pf::db - module for database abstraction and utilities.

=cut

=head1 DESCRIPTION

pf::db contains the database utility functions used by the other
Packetfence modules

=head1 CONFIGURATION AND ENVIRONMENT

Read the F<pf.conf> configuration file.

=cut

use strict;
use warnings;
use DBI;
use File::Basename;
use Log::Log4perl;
use threads;

our ( $dbh, %last_connect );

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw($dbh db_data db_connect db_disconnect);
}

END {
    $dbh->disconnect() if $dbh;
}

use pf::config;

#$dbh = db_connect() if (!threads->self->tid);

sub db_connect {
    my ( $mydbh, @function_list ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::db');
    $mydbh = 0 if ( !defined $mydbh );
    my $caller = ( caller(1) )[3] || basename($0);
    $logger->debug("function $caller is calling db_connect");

    my $tid = threads->self->tid;
    $mydbh = $dbh if ( !$tid && defined $dbh );

    if (   defined( $last_connect{$tid} )
        && $last_connect{$tid}
        && ( time() - $last_connect{$tid} < 30 )
        && $mydbh )
    {
        $logger->debug(
            "not checking db handle, it has less then 300 sec from last time"
        );
        return $mydbh;
    }
    $logger->debug("checking handle");

    if ( $mydbh && $mydbh->ping() ) {
        $last_connect{$tid} = time();
        $logger->debug("we are currently connected");
        return $mydbh;
    }

    $logger->debug(
        "Connecting $mydbh from $tid db connection is DEAD (re)connecting");

    my $host = $Config{'database'}{'host'};
    my $port = $Config{'database'}{'port'};
    my $user = $Config{'database'}{'user'};
    my $pass = $Config{'database'}{'pass'};
    my $db   = $Config{'database'}{'db'};

    $mydbh = DBI->connect( "dbi:mysql:dbname=$db;host=$host;port=$port",
        $user, $pass, { RaiseError => 0, PrintError => 0 } );

    # make sure we have a database handle
    if ($mydbh) {
        $logger->debug("connected");
        $last_connect{$tid} = time() if $mydbh;
        $dbh = $mydbh if ( !$tid );
        foreach my $function (@function_list) {
            $function .= "_db_prepare";
            $logger->debug("db preparing $function");
            (   $main::{$function}
                    or sub { print "No such sub $function: $_\n" }
            )->($mydbh);
        }
        $_[0] = $mydbh;
        return ($mydbh);
    } else {
        $logger->logcroak("unable to connect to database: " . $DBI::errstr);
        return ();
    }
}

sub db_disconnect {
}

sub db_data {
    my ( $db_handle, @value ) = @_;
    if (@value) {
        $db_handle->execute(@value) || return (0);
    } else {
        $db_handle->execute() || return (0);
    }
    my ( $ref, @array );
    while ( $ref = $db_handle->fetchrow_hashref() ) {
        push( @array, $ref );
    }
    $db_handle->finish();
    return (@array);
}

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

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
