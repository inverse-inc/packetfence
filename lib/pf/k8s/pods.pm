package pf::k8s::pods;

=head1 NAME

pf::k8s::pods

=cut

=head1 DESCRIPTION

Module to manage access to the pods API of a K8S control plane

=cut


use pf::constants qw($TRUE);
use HTTP::Request::Common;

use Moo;
extends "pf::k8s";

sub list {
    my ($self, $params) = @_;
    return $self->execute_request(HTTP::Request::Common::GET($self->build_uri("/api/v1/namespaces/".$self->namespace."/pods", $params)));
}

sub delete {
    my ($self, $pod_name) = @_;
    return $self->execute_request(HTTP::Request::Common::DELETE($self->build_uri("/api/v1/namespaces/".$self->namespace."/pods/$pod_name")));
}

sub run_all_pods {
    my ($self, $list_params, $container_name, $on_ready, $on_not_ready) = @_;

    my ($success, $res) = $self->list($list_params);

    return ($success, $res) unless($success);

    for my $pod (@{$res->{items}}) {
        for my $containerStatus (@{$pod->{status}->{containerStatuses}}) {
            if($containerStatus->{name} eq $container_name) {
                if($containerStatus->{ready}) {
                    my ($status, $res) = $on_ready->($pod);
                    return ($status, $res) unless($status);
                }
                else {
                    my ($status, $res) = $on_not_ready->($pod);
                    return ($status, $res) unless($status);
                }
            }
        }
    }
    return ($TRUE);
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

