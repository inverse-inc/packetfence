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
);

use pf::IniFiles;
use Sys::Hostname;

use Template;

use Moo;
extends 'pf::services::manager';
has '+name' => (default => sub { 'kafka' } );

sub generateConfig {
    my ($self) = @_;
    my $tt = Template->new(
        ABSOLUTE => 1,
    );
    my $vars = {
       env_dict => $self->env_vars,
    };
    $tt->process(
        "/usr/local/pf/containers/environment.template",
        $vars,
        $generated_conf_dir . "/" . $self->name . ".env"
    ) or die $tt->error();
    return 1;
}

sub env_vars {
    my ($self) = @_;
    my %env;
    my $config = $self->config();
    my $hostname = hostname();
    for my $top ('cluster', $hostname) {
        while (my ($k, $v) = each %{$config->{$top}}) {
            $env{$k} = $v;
        }
    }

    return \%env;
}




sub config {
    tie my %ini, 'pf::IniFiles', (-file=> $kafka_config_file) or die "Cannot open config file $kafka_config_file";
    return {%ini}
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2023 Inverse inc.

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

