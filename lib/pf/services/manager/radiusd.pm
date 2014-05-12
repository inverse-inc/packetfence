package pf::services::manager::radiusd;
=head1 NAME

pf::services::manager::radiusd add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::radiusd

=cut

use strict;
use warnings;
use pf::file_paths;
use pf::util;
use pf::config;
use Moo;

extends 'pf::services::manager';

has '+name' => ( default => sub { 'radiusd' } );

has '+launcher' => ( default => sub { "sudo %1\$s -d $install_dir/raddb/"} );

sub generateConfig {
    my ($self,$quick) = @_;
    generate_radiusd_mainconf();
    generate_radiusd_eapconf();
    generate_radiusd_sqlconf();
}

=head2 generate_radiusd_mainconf

Generates the radiusd.conf configuration file

=cut

sub generate_radiusd_mainconf {
    my %tags;

    $tags{'template'}    = "$conf_dir/radiusd/radiusd.conf";
    $tags{'install_dir'} = $install_dir;
    $tags{'management_ip'} = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
    $tags{'arch'} = `uname -m` eq "x86_64" ? "64" : "";
    $tags{'rpc_pass'} = $Config{webservices}{pass} || "''";
    $tags{'rpc_user'} = $Config{webservices}{user} || "''";
    $tags{'rpc_port'} = $Config{webservices}{port} || "9090";
    $tags{'rpc_server'} = $Config{webservices}{host} || "127.0.0.1";
    $tags{'rpc_proto'} = $Config{webservices}{proto} || "http";

    parse_template( \%tags, "$conf_dir/radiusd/radiusd.conf", "$install_dir/raddb/radiusd.conf" );
}

=head2 generate_radiusd_eapconf

Generates the eap.conf configuration file

=cut

sub generate_radiusd_eapconf {
   my %tags;

   $tags{'template'}    = "$conf_dir/radiusd/eap.conf";
   $tags{'install_dir'} = $install_dir;

   parse_template( \%tags, "$conf_dir/radiusd/eap.conf", "$install_dir/raddb/eap.conf" );
}

=head2 generate_radiusd_sqlconf

Generates the sql.conf configuration file

=cut

sub generate_radiusd_sqlconf {
   my %tags;

   $tags{'template'}    = "$conf_dir/radiusd/sql.conf";
   $tags{'install_dir'} = $install_dir;
   $tags{'db_host'} = $Config{'database'}{'host'};
   $tags{'db_port'} = $Config{'database'}{'port'};
   $tags{'db_database'} = $Config{'database'}{'db'};
   $tags{'db_username'} = $Config{'database'}{'user'};
   $tags{'db_password'} = $Config{'database'}{'pass'};

   parse_template( \%tags, "$conf_dir/radiusd/sql.conf", "$install_dir/raddb/sql.conf" );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

