package pf::services::manager::carbon_cache;

=head1 NAME

pf::services::manager::carbon_cache

=cut

=head1 DESCRIPTION

pf::services::manager::carbon_cache
carbon-cache daemon manager module for PacketFence.

=cut

use strict;
use warnings;
use pf::file_paths;
use pf::util;
use pf::config;
use Moo;

extends 'pf::services::manager';

has '+name' => ( default => sub {'carbon-cache'} );

has '+launcher' => (
    default => sub {
        "sudo %1\$s --config=$install_dir/var/conf/carbon.conf --pidfile=$install_dir/var/run/carbon.pid --logdir=$install_dir/logs";
    }
);

sub generateConfig {
    generate_local_settings();
    generate_dashboard_settings();
    generate_carbon_config();
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
    $tags{'graphite_host'} = "$Config{'monitoring'}{'graphite_host'}";
    $tags{'graphite_port'} = "$Config{'monitoring'}{'graphite_port'}";
    $tags{'db_host'}       = $Config{'database'}{'host'};
    $tags{'db_port'}       = $Config{'database'}{'port'};
    $tags{'db_graphite_database'}   = $Config{'monitoring'}{'db'};
    $tags{'db_username'}   = $Config{'database'}{'user'};
    $tags{'db_password'}   = $Config{'database'}{'pass'};

    parse_template( \%tags, "$tags{'template'}", "$install_dir/var/conf/local_settings.py" );
}

sub generate_dashboard_settings { 
    my %tags;
    $tags{'template'}    = "$conf_dir/monitoring/dashboard.conf";

    parse_template( \%tags, "$tags{'template'}", "$install_dir/var/conf/dashboard.conf" );
}

sub generate_carbon_Config {
    my %tags;
    $tags{'template'}    = "$conf_dir/monitoring/carbon.conf";
    $tags{'install_dir'} = "$install_dir";
    $tags{'management_ip'}
        = defined( $management_network->tag('vip') )
        ? $management_network->tag('vip')
        : $management_network->tag('ip');
    $tags{'graphite_host'} = "$Config{'monitoring'}{'graphite_host'}";
    $tags{'graphite_port'} = "$Config{'monitoring'}{'graphite_port'}";

    parse_template( \%tags, "$tags{'template'}", "$install_dir/var/conf/carbon.conf" );
}

