package pfappserver::Controller::Service;

=head1 NAME

pfappserver::Controller::Node - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use POSIX;

use pf::services;

BEGIN { extends 'pfappserver::Base::Controller'; }

=head1 SUBROUTINES

=head2 object

Service controller dispatcher

=cut

sub index : Local : Path {
    my ($self, $c) = @_;
    $c->go('status');
}

sub object :Chained('/') :PathPart('service') :CaptureArgs(1) {
    my ( $self, $c, $service ) = @_;
    $c->stash(
        service => $service,
        model => $c->model("Services")
    );
}

=head2 status

=cut

sub status :Chained('object') :PathPart('') :Args(0) {
    my ($self, $c) = @_;
    $self->_process_model_results($c,$c->stash->{model},'status',$c->stash->{service});
}

=head2 stop

=cut

sub stop :Chained('object') :PathPart :Args(0) {
    my ( $self, $c ) = @_;
    $self->_process_model_results_as_json($c,$c->stash->{model},'service_stop',$c->stash->{service});
}

=head2 start_all

=cut

sub start_all :Local {
    my ( $self, $c ) = @_;
    $self->_process_model_results_as_json($c,$c->model("Services"),'start',$c->stash->{service});
}

=head2 stop_all

=cut

sub stop_all :Local {
    my ( $self, $c ) = @_;
    $self->_process_model_results_as_json($c,$c->model("Services"),'stop_all',$c->stash->{service});
}


=head2 start

=cut

sub start :Chained('object') :PathPart :Args(0) {
    my ( $self, $c ) = @_;
    $self->_process_model_results_as_json($c,$c->stash->{model},'service_start',$c->stash->{service});
}

=head2 restart

=cut

sub restart :Chained('object') :PathPart :Args(0) {
    my ( $self, $c ) = @_;
    $self->_process_model_results_as_json($c,$c->stash->{model},'service_restart',$c->stash->{service});
}

sub _process_model_results_as_json {
    my ($self,$c,$model,$func, @args) = @_;
    $c->stash(current_view => 'JSON');
    my ($status,$result) = $model->$func(@args);
    if(is_success($status)) {
        $c->stash(%$result);
    } else {
        $c->stash->{status_msg} = $result;
    }
    $c->response->status($status);
}

sub _process_model_results {
    my ($self,$c,$model,$func, @args) = @_;
    my ($status,$result) = $model->$func(@args);
    if(is_success($status)) {
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

Copyright (C) 2012 Inverse inc.

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

__PACKAGE__->meta->make_immutable;

1;
