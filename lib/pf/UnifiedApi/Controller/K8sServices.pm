package pf::UnifiedApi::Controller::K8sServices;

=head1 NAME

pf::UnifiedApi::Controller::K8sServices -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::K8sServices

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pf::error qw(is_error);
use pf::util qw(isenabled);
use pf::constants qw($TRUE);
use pf::k8s;
use pf::AtFork;

my $k8s_deployments;
my $k8s_pods;

sub CLONE {
    if (!isenabled($ENV{PF_SAAS}) ) {
        return;
    }

    $k8s_deployments = pf::k8s->env_build()->api_module("pf::k8s::deployments");
    $k8s_pods = pf::k8s->env_build()->api_module("pf::k8s::pods");
}

pf::AtFork->add_to_child(\&CLONE);
CLONE();

sub allowed {
    my ($self) = @_;
    if (isenabled($ENV{PF_SAAS})) {
        return $TRUE;
    }

    return $self->render_error(401, "Kubernetes services are not enabled");
}

sub resource {
    my ($self) = @_;
    return 1;
}

sub list {
    my ($self) = @_;
    my ($success, $res) = $k8s_deployments->list();
    if($success) {
        $self->render(json => {items => [map {$_->{metadata}->{name}} @{$res->{items}}]});
    }
    else {
        $self->k8s_api_error($res);
    }
}

sub status_all {
    my ($self) = @_;
    my ($success, $res) = $k8s_deployments->list();
    if($success) {
        my $items = {};
        for my $deployment (@{$res->{items}}) {
            $items->{$deployment->{metadata}->{name}} = $self->_service_status($deployment);
        }
        $self->render(json => {items => $items});
    }
    else {
        $self->k8s_api_error($res);
    }
}

sub status {
    my ($self) = @_;
    my $service_id = $self->param('service_id');
    my ($success, $res) = $k8s_deployments->get($service_id);
    if($success) {
        $self->render(json => $self->_service_status($res));
    }
    else {
        $self->k8s_api_error($res);
    }
}

sub restart {
    my ($self) = @_;
    my $service_id = $self->param('service_id');
    my ($success, $res) = $k8s_deployments->rollout_restart($service_id);
    if($success) {
        $self->render(json => {accepted => $self->json_true});
    }
    else {
        $self->k8s_api_error($res);
    }
}

sub _service_status {
    my ($self, $deployment) = @_;
    my $status = $deployment->{status};
    return {
        available => (($status->{availableReplicas} >= 1) ? $self->json_true : $self->json_false),
        total_replicas => $status->{replicas},
        updated_replicas => $status->{updatedReplicas},
        is_fully_updated => (($status->{updatedReplicas} == $status->{replicas}) ? $self->json_true : $self->json_false),
    };
}

sub k8s_api_error {
    my ($self, $err) = @_;
    $self->render_error(500, $err);
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
