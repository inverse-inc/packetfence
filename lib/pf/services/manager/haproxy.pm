package pf::services::manager::haproxy;
=head1 NAME

pf::services::manager::haproxy add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::haproxy

=cut

use strict;
use warnings;
use Moo;
use IPC::Cmd qw[can_run run];
use List::MoreUtils qw(uniq);
use POSIX;
use pf::config qw(
    %Config
    $OS
    @listen_ints
    @dhcplistener_ints
    $management_network
    @portal_ints
);
use pf::file_paths qw(
    $generated_conf_dir
    $install_dir
    $conf_dir
    $var_dir
    $captiveportal_templates_path
);
use pf::log;
use pf::util;
use pf::cluster;
use Template;
use pf::authentication;
use pf::dal::tenant;


extends 'pf::services::manager';

has 'haproxy_config_template' => (is => "rw");

sub _cmdLine {
    my $self = shift;
    $self->executable . " -f $generated_conf_dir/".$self->name.".conf -p $install_dir/var/run/".$self->name.".pid";
}

has '+shouldCheckup' => ( default => sub { 0 }  );

sub executable {
    my ($self) = @_;
    my $service = ( $Config{'services'}{$self->name."_binary"} || "$install_dir/sbin/haproxy" );
    return $service;
}

sub preStartSetup {
    my ($self,$quick) = @_;
    $self->SUPER::preStartSetup($quick);
    return 1;
}

sub stop {
    my ($self,$quick) = @_;
    my $result = $self->SUPER::stop($quick);
    return $result;
}

=head1 AUTHOR

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

1;
