package pf::services::manager::kafka;

=head1 NAME

pf::services::manager::kafka -

=head1 DESCRIPTION

pf::services::manager::kafka

=cut

use strict;
use warnings;

use pf::file_paths qw(
    $generated_conf_dir
    $conf_dir
    $kafka_config_file
    $kafka_config_dir
);

use pf::IniFiles;
use Sys::Hostname;

use Template;
use pf::constants qw($TRUE $FALSE);
use pfconfig::cached_hash;
tie our %ConfigKafka, 'pfconfig::cached_hash', "config::Kafka";

use Moo;
extends 'pf::services::manager';
has '+name' => (default => sub { 'kafka' } );

sub generateConfig {
    my ($self) = @_;
    my $tt = Template->new(
        ABSOLUTE => 1,
    );
    $self->generateEnvFile($tt);
    $self->generateAuthFile($tt);
    return 1;
}

sub generateAuthFile {
    my ($self, $tt) = @_;
    $tt->process(
        "${kafka_config_dir}/kafka_server_jaas.conf.tt",
        \%ConfigKafka,
        "${kafka_config_dir}/kafka_server_jaas.conf",
    ) or die $tt->error();
}

sub generateEnvFile {
    my ($self, $tt) = @_;
    my $vars = {
       env_dict => $self->env_vars,
    };
    $tt->process(
        "/usr/local/pf/containers/environment.template",
        $vars,
        $generated_conf_dir . "/" . $self->name . ".env"
    ) or die $tt->error();
}

sub env_vars {
    my ($self) = @_;
    my %env;
    my $hostname = hostname();
    for my $top ('cluster', $hostname) {
        while (my ($k, $v) = each %{$ConfigKafka{$top}}) {
            $env{$k} = $v;
        }
    }

    return \%env;
}

sub isManaged {
    my ($self) = @_;
    my $hostname = hostname();
    ($self->SUPER::isManaged && exists $ConfigKafka{$hostname}) ? $TRUE : $FALSE
}

=head1 AUTHOR

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

1;

