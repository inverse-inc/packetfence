package pf::services::manager::redis;
=head1 NAME

pf::services::manager::redis - base class for redis services

=cut

=head1 DESCRIPTION

pf::services::manager::redis

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw(
    $conf_dir
    $generated_conf_dir
    $install_dir
);
use pf::config qw(
    %Config
);
use pf::util;

extends 'pf::services::manager';

has '+launcher' => ( builder => 1, lazy => 1,);

has '+startDependsOnServices' => (is => 'ro', default => sub { [] } );

has configFilePath => (is => 'rw', builder => 1, lazy => 1);

has configTemplateFilePath => (is => 'rw', builder => 1, lazy => 1);

sub _build_launcher {
    my ($self) = @_;
    my $config = $self->redis_config_file;
    return "sudo -u pf %1\$s $config"
}

sub generateConfig {
    my ($self) = @_;
    my $vars = $self->createVars();
    my $tt = Template->new(ABSOLUTE => 1);
    $tt->process($self->configTemplateFilePath, $vars, $self->configFilePath) or die $tt->error();
    return 1;
}

sub createVars {
    my ($self) = @_;
    my %vars = (
        install_dir => $install_dir,
        name => $self->name,
    );
    return \%vars;
}


sub _build_configTemplateFilePath {
    my ($self) = @_;
    my $name = $self->name;
    return "$conf_dir/${name}.conf";

}

sub _build_configFilePath {
    my ($self) = @_;
    my $name = $self->name;
    return "$generated_conf_dir/${name}.conf";
}

sub executable {
    my ($self) = @_;
    my $service = ( $Config{'services'}{"redis_binary"} || "$install_dir/sbin/redis" );
    return $service;
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

