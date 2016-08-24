package pf::services::manager::collectd;

=head1 NAME

pf::services::manager::collectd

=cut

=head1 DESCRIPTION

pf::services::manager::collectd
collectd daemon manager module for PacketFence.

=cut

use strict;
use warnings;
use pf::file_paths qw(
    $install_dir
    $conf_dir
    $log_dir
    $generated_conf_dir
);
use pf::util;
use pf::config qw(
    %Config
    $OS
    $management_network
);
use Moo;
use Sys::Hostname;
use Template;
extends 'pf::services::manager';

has '+name'     => ( default => sub {'collectd'} );
has '+optional' => ( default => sub {1} );
has startDependsOnServices => ( is => 'ro', default => sub { [qw(carbon-cache carbon-relay)] } );

has '+launcher' => (
    default => sub {
        "sudo %1\$s -P $install_dir/var/run/collectd.pid -C $install_dir/var/conf/collectd.conf";
    }
);

sub generateConfig {
    my ($self) = @_;
    $self->generateCollectd();
    $self->generateTypes();
}

sub generateCollectd {
    my ($self) = @_;
    my %vars;
    $vars{'template'}    = "$conf_dir/monitoring/collectd.conf.$OS";
    $vars{'install_dir'} = "$install_dir";
    $vars{'log_dir'}     = "$log_dir";
    $vars{'management_ip'}
        = defined( $management_network->tag('vip') )
        ? $management_network->tag('vip')
        : $management_network->tag('ip');
    $vars{'graphite_host'} = "$Config{'monitoring'}{'graphite_host'}";
    $vars{'graphite_port'} = "$Config{'monitoring'}{'graphite_port'}";
    $vars{'hostname'}      = hostname;
    $vars{'db_host'}       = "$Config{'database'}{'host'}";
    $vars{'db_username'}   = "$Config{'database'}{'user'}";
    $vars{'db_password'}   = "$Config{'database'}{'pass'}";
    $vars{'db_database'}   = "$Config{'database'}{'db'}";
    $vars{'httpd_portal_modstatus_port'} = "$Config{'ports'}{'httpd_portal_modstatus'}";

    my $tt = Template->new(ABSOLUTE => 1);
    $tt->process($vars{'template'}, \%vars, "$install_dir/var/conf/collectd.conf") or die $tt->error();
    
    return 1;
}

sub generateTypes {
    my ($self) = @_;
    my %vars;
    $vars{'template'}    = "$conf_dir/monitoring/types.db";
    $vars{'install_dir'} = "$install_dir";
    my $tt = Template->new(ABSOLUTE => 1);
    $tt->process($vars{'template'}, \%vars, "$install_dir/var/conf/types.db") or die $tt->error();
    
    return 1;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
