package pfappserver::PacketFence::Controller::Service;

=head1 NAME

pfappserver::PacketFence::Controller::Service - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use POSIX;
use pf::cluster;

use pf::services;

BEGIN { extends 'pfappserver::Base::Controller'; }

=head1 METHODS

=head2 index

=cut

sub index : Local : Path {
    my ($self, $c) = @_;
    $c->go('status');
}

=head2 service

Service controller dispatcher

=cut

sub service :Chained('/') :PathPart('service') :CaptureArgs(1) {
    my ($self, $c, $service) = @_;
    $c->stash(
        service => $service,
        model => $c->model("Services")
    );
}

=head2 status

=cut

sub status :Chained('service') :PathPart('') :Args(0) :AdminRole('SERVICES') {
    my ($self, $c) = @_;
    $self->_process_model_results($c, $c->stash->{model}->status);
    $c->stash->{'server_hostname'}  = $c->model('Admin')->server_hostname();
}

=head2 cluster_status

=cut

sub cluster_status :Local :AdminRole('SERVICES') {
    my ($self, $c) = @_;
    $c->stash->{servers} = [pf::cluster::config_enabled_hosts()];
    $c->stash->{config_cluster} = \%ConfigCluster;
    $c->stash->{services} = {};
    foreach my $server (pf::cluster::config_enabled_hosts()){
        my ($status, $result) = $c->model('Services')->server_status($server);
        if(is_success($status)) {
            my $services = $result->{services};
            foreach my $service (keys %$services) {
                $c->stash->{services}->{$service} //= {};
                $c->stash->{services}->{$service}->{$server} = $services->{$service};
            }
        }
        else {
            $c->log->error("Error while getting status for server $server : $result");
        }
    }
    # Ensure all services have a status for all servers
    foreach my $service (keys %{$c->stash->{services}}) {
        foreach my $server (pf::cluster::config_enabled_hosts()) {
            $c->stash->{services}->{$service}->{$server} //= "unknown";
        }
    }
}

=head2 start

=cut

sub start :Chained('service') :PathPart :Args(0) :AdminRole('SERVICES') {
    my ($self, $c) = @_;
    $self->_process_model_results_as_json( $c, $c->stash->{model}->service_cmd($c->stash->{service}, "start") );
}

=head2 stop

=cut

sub stop :Chained('service') :PathPart :Args(0) :AdminRole('SERVICES') {
    my ($self, $c) = @_;
    $self->_process_model_results_as_json( $c, $c->stash->{model}->service_cmd($c->stash->{service}, "stop") );
}

=head2 restart

=cut

sub restart :Chained('service') :PathPart :Args(0) :AdminRole('SERVICES') {
    my ($self, $c) = @_;
    $self->_process_model_results_as_json( $c, $c->stash->{model}->service_cmd($c->stash->{service}, "restart") );
}

=head2 pf_start

=cut

sub pf_start :Local :Path('pf/start') :AdminRole('SERVICES') {
    my ($self, $c) = @_;
    $c->stash->{service} = 'pf';
    $self->_process_model_results_as_json( $c, $c->model('Services')->service_cmd_background(qw(pf start)) );
}

=head2 pf_stop

=cut

sub pf_stop :Local :Path('pf/stop') :AdminRole('SERVICES') {
    my ($self, $c) = @_;
    $c->stash->{service} = 'pf';
    $self->_process_model_results_as_json( $c, $c->model('Services')->service_cmd_background(qw(pf stop)) );
}

=head2 pf_restart

=cut

sub pf_restart :Local :Path('pf/restart') :AdminRole('SERVICES') {
    my ($self, $c) = @_;
    $c->stash->{service} = 'pf';
    $self->_process_model_results_as_json( $c, $c->model('Services')->service_cmd_background(qw(pf restart)) );
}

=head2 httpd_admin_restart

=cut

sub httpd_admin_restart :Local : Path('httpd.admin/restart') :AdminRole('SERVICES') {
    my ($self, $c) = @_;
    $c->stash->{service} = 'httpd.admin';
    $self->_process_model_results_as_json( $c, $c->model('Services')->service_cmd_background("httpd.admin", "restart") );
}

=head2 httpd_admin_stop

=cut

sub httpd_admin_stop :Local : Path('httpd.admin/stop') :AdminRole('SERVICES') {
    my ($self, $c) = @_;
    $c->stash->{service} = 'httpd.admin';
    $self->_process_model_results_as_json( $c, $c->model('Services')->service_cmd_background("httpd.admin", "stop") );
}


sub _process_model_results_as_json {
    my ($self, $c, $status, $result) = @_;
    $self->audit_current_action($c, status => $status);
    $c->stash(current_view => 'JSON');
    if (is_success($status)) {
        $c->stash(%$result);
    } else {
        $c->stash->{status_msg} = $result;
    }
    $c->response->status($status);
}

sub _process_model_results {
    my ($self, $c, $status, $result) = @_;
    if (is_success($status)) {
        $c->stash(%$result);
    } else {
        $c->stash(
            current_view => 'JSON',
            status_msg => $result
        );
    }
    $c->response->status($status);
}

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
