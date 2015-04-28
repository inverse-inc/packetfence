package pf::services::manager::httpd_graphite;

=head1 NAME

pf::services::manager::httpd_graphite

=cut

=head1 DESCRIPTION

pf::services::manager::httpd_graphite

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths;
use pf::config;
use pf::util;

extends 'pf::services::manager::httpd';

has '+name' => ( default => sub {'httpd.graphite'} );
has '+optional' => ( default => sub {1} );

sub generateConfig {
    generate_local_settings();
    generate_dashboard_settings();
}

sub generate_local_settings {
    my %tags;
    $tags{'template'} = "$conf_dir/monitoring/local_settings.py";
    $tags{'conf_dir'} = "$install_dir/var/conf";
    $tags{'log_dir'}  = "$install_dir/logs";
    $tags{'management_ip'}
        = defined( $management_network->tag('vip') )
        ? $management_network->tag('vip')
        : $management_network->tag('ip');
    $tags{'graphite_host'}        = "$Config{'monitoring'}{'graphite_host'}";
    $tags{'graphite_port'}        = "$Config{'monitoring'}{'graphite_port'}";
    $tags{'db_graphite_database'} = $Config{'monitoring'}{'db'};
    $tags{'db_host'}              = $Config{'monitoring'}{'db_host'};
    $tags{'db_port'}              = $Config{'monitoring'}{'db_port'};
    $tags{'db_user'}              = $Config{'monitoring'}{'db_user'};
    $tags{'db_password'}          = $Config{'monitoring'}{'db_pass'};

    parse_template( \%tags, "$tags{'template'}", "$install_dir/var/conf/local_settings.py" );
}

sub generate_dashboard_settings {
    my %tags;
    $tags{'template'} = "$conf_dir/monitoring/dashboard.conf";

    parse_template( \%tags, "$tags{'template'}", "$install_dir/var/conf/dashboard.conf" );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

