package pf::clustermgmt;

=head1 NAME

pf::clustermgmt

=cut

=head1 DESCRIPTION

Use as a rpc server and as a rpc client.
It will sync between all the cluster members somes configurations parameters.

=cut

use Apache2::RequestRec ();
use Apache2::Request;
use Apache2::Const;
use APR::URI ();
use DBI;
use NetAddr::IP;
use List::MoreUtils qw(uniq);
use Try::Tiny;
use Socket;

use strict;
use warnings;
use pf::config;
use pf::config::cached;
use pf::log;
use pf::util;
use pf::ConfigStore::Interface;
use pf::ConfigStore::Pf;
use NetAddr::IP;
use Net::Interface;
use List::MoreUtils qw(uniq);
use pf::api::jsonrpcclient;
use pf::services;

our %REST_PARSERS = (
    status => \&status,
    mysql => {
        connect => \&connect,
        cluster => \&cluster,
    },
);

=head2 handler

The handler check the status of all the services of the cluster and only allow connection from
the management network (need it for haproxy check)

=cut

sub handler {

    my $r = (shift);

    my $parsed = APR::URI->parse($r->pool, $r->uri);

    my @uri_elements = split('/',$parsed->path);
    shift @uri_elements;

    my $function = findhash($r,\@uri_elements);
    $r->handler('modperl');
    $r->set_handlers( PerlResponseHandler => \&answer );
    if (defined(my $funct= eval $function) ) {
        return $funct->($r,\@uri_elements);
    } else {
        return  Apache2::Const::SERVER_ERROR;
    }

}

=head2 findhash

Find the corresponding sub based on the uri

=cut

sub findhash {
    my ($r,$uri_elements) =@_;

    my $function = '$REST_PARSERS';
    for my $elements (@{$uri_elements}) {
        $function .= '{'.$elements.'}';
        if (ref(eval($function)) eq 'CODE') {
            last;
        }
    }
    return $function;
}

=head2 status

Return 200 if the service is running, 500 else

=cut

sub status {

    my ($r,$uri_elements) = @_;

    my $service = pop @{$uri_elements};
    if (grep { $_ eq $service } @pf::services::ALL_SERVICES) {
        my $manager = pf::services::get_service_manager($service);
        if ($manager->status('1')) {
            return  Apache2::Const::OK;
        } else {
            return  Apache2::Const::SERVER_ERROR;
        }
    } else {
        return  Apache2::Const::SERVER_ERROR;
    }
    return Apache2::Const::OK;
}

=head2 connect_db

Local DBI connection, we use it to test the local database connection

=cut

sub connect_db {

    my $DB_Config = $Config{'database'};
    #we only want to test local access
    my $host = 'localhost';
    my $port = $DB_Config->{'port'};
    my $user = $DB_Config->{'user'};
    my $pass = $DB_Config->{'pass'};
    my $db   = $DB_Config->{'db'};
    my $mydbh = DBI->connect( "dbi:mysql:dbname=$db;host=$host;port=$port",
        $user, $pass, { RaiseError => 0, PrintError => 0, mysql_auto_reconnect => 1 } );
    if ($mydbh) {
        return ($mydbh);
    } else {
        return ();
    }
}

=head2 connect

Check if we can connect to mysql

=cut

sub connect {

    my ($r) = @_;

    my $mydbh = connect_db();
    if ($mydbh) {
        if ($mydbh->ping) {
            return Apache2::Const::OK;
        } else {
            return  Apache2::Const::SERVER_ERROR;
        }
    } else {
        return  Apache2::Const::SERVER_ERROR;
    }
}

=head2 cluster

Check the status of the cluster

=cut

sub cluster {

    my ($r) = @_;

    my $mydbh = connect_db();
    if ($mydbh) {
        my $query = $mydbh->prepare('SELECT 1 FROM node LIMIT 1');
        $query->execute;
        my ($val) = $query->fetchrow_array();
        if ($val eq '1') {
            return Apache2::Const::OK;
        } else {
            return  Apache2::Const::SERVER_ERROR;
        }
    } else {
        return  Apache2::Const::SERVER_ERROR;
    }
}

=head2 answer

ResponseHandler answer

=cut

sub answer {

    my ($r) = @_;

    return Apache2::Const::OK;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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
