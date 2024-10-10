package pf::UnifiedApi::Controller::SystemServices;

=head1 NAME

pf::UnifiedApi::Controller::SystemServices -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::SystemServices

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pf::util;
use pf::error qw(is_error);
use pf::pfqueue::status_updater::redis;
use pf::util::pfqueue qw(consumer_redis_client);

sub resource {
    return 1;
}

sub quoted_system_service_id {
    my ($id) = @_;
    ($id) =~ s/'/'"'"'/g;
    return "'$id'"
}

sub systemctl {
    my ($command, $service) = @_;
    my $cmd = "sudo systemctl $command ".quoted_system_service_id($service);
    return system($cmd);
}

sub status {
    my ($self) = @_;
    my $service = quoted_system_service_id($self->param("system_service_id"));
    my $pid = `sudo systemctl show -p MainPID $service`;
    chomp $pid;
    $pid = (split(/=/, $pid))[1];
    return $self->render(json => {message => ($pid ? "Service is running" : "Service is not running"), pid => $pid+0}, status => ($pid ? 200 : 500));
}

sub do_action {
    my ($self, @args) = @_;

    my ($status, $data) = $self->get_data();
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    if ($data->{async}) {
        my $task_id = $self->task_id;
        my $subprocess = Mojo::IOLoop->subprocess;
        $subprocess->run(
            sub {
                my ($subprocess) = @_;
                my $updater = pf::pfqueue::status_updater::redis->new( connection => consumer_redis_client(), task_id => $task_id );
                $updater->start;
                my $data = $self->do_systemctl_action(@args);
                $updater->completed($data);
            },
            sub {},
        );

        return $self->render( json => {status => 202, task_id => $task_id }, status => 202);
    }

    my $results = $self->do_systemctl_action(@args);
    return $self->render(json => $results, status => $results->{status});
}

sub start {
    my ($self) = @_;
    $self->do_action('start', 'started');
}

sub stop {
    my ($self) = @_;
    $self->do_action('stop', 'stopped');
}

sub restart {
    my ($self) = @_;
    $self->do_action('restart', 'restarted');
}

sub enable {
    my ($self) = @_;
    $self->do_action('enable', 'enabled');
}

sub disable {
    my ($self) = @_;
    $self->do_action('disable', 'disabled');
}

sub do_systemctl_action {
    my ($self, $action, $info) = @_;
    my $return = systemctl($action, $self->param('system_service_id'));
    return {message => ($return ? "Service couldn't be $info" : "Service has been $info"), status => ($return ? 500 : 200)};
}

sub do_start {
    my ($self, $action, $info) = @_;
    my $return = systemctl($action, $self->param('system_service_id'));
    return {message => ($return ? "Service couldn't be $info" : "Service has been $info"), status => ($return ? 500 : 200)};
}

sub get_data {
    my ($self) = @_;
    my $body = $self->req->body();
    if (!defined $body || $body eq '') {
        return 200, {}
    }

    return $self->parse_json($body);
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
