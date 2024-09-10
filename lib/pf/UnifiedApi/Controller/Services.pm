package pf::UnifiedApi::Controller::Services;

=head1 NAME

pf::UnifiedApi::Controller::Services -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Services

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pf::services;
use pf::error qw(is_error);
use pf::pfqueue::status_updater::redis;
use pf::util::pfqueue qw(consumer_redis_client);
use POSIX qw(setsid);
use pf::file_paths qw($pfperl_api_restart_task);

sub resource {
    my ($self) = @_;
    my $service_id = $self->param('service_id');
    my $class = $self->_get_service_class($service_id);
    if (defined $class) {
        $self->stash->{item} = $class;
        return 1;
    }

    $self->render_error(404, $self->status_to_error_msg(404));
    return undef;
}

sub list {
    my ($self) = @_;
    $self->render(json => { items => [ map {$_->name} grep { $_->name ne 'pf' } @pf::services::ALL_MANAGERS ] });
}

sub update_systemd {
    my ($self) = @_;
    return $self->do_action('do_update_systemd');
}

sub do_update_systemd {
    my ($self) = @_;
    
    my $service = $self->_get_service_class($self->param('service_id'));
    my $name = $service->name;
    my $services = $name eq 'pf' ? [ grep {$_ ne 'pf'} @pf::services::ALL_SERVICES ] : [ $name ];
    my @managers = pf::services::getManagers( $services );

    for my $manager (@managers) {
        if ( $manager->isManaged ) {
            $manager->sysdEnable();
        }
        else {
            $manager->sysdDisable();
        }
    }

    return {message => "Updated systemd for $name"};
}

sub status {
    my ($self) = @_;
    my $service = $self->_get_service_class($self->param('service_id'));
    if ($service) {
        return $self->render(json => $self->service_info($service));
    }
}

=head2 service_info

service_info

=cut

sub service_info {
    my ($self, $service) = @_;
    return {
        id => $service->name,
        alive => $service->isAlive(),
        managed => $service->isManaged(),
        enabled => $service->isEnabled(),
        pid => $service->pid(),
    };
}

=head2 status_all

status_all

=cut

sub status_all {
    my ($self) = @_;
    my @services = map {$self->service_info($_) } grep { $_->name ne 'pf' } @pf::services::ALL_MANAGERS;
    return $self->render(json => { items => \@services });
}

sub get_data {
    my ($self) = @_;
    my $body = $self->req->body();
    if (!defined $body || $body eq '') {
        return 200, {}
    }

    return $self->parse_json($body);
}

sub start {
    my ($self) = @_;
    return $self->do_action('do_start');
}

sub stop {
    my ($self) = @_;
    return $self->do_action('do_stop');
}

sub restart {
    my ($self) = @_;
    return $self->do_action('do_restart');
}

sub do_action {
    my ($self, $action) = @_;
    my ($status, $data) = $self->get_data();
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $subprocess = Mojo::IOLoop->subprocess;
    if ($data->{async}) {
        my $task_id = $self->task_id;
        $subprocess->run(
            sub {
                my ($subprocess) = @_;
                my $updater = pf::pfqueue::status_updater::redis->new( connection => consumer_redis_client(), task_id => $task_id );
                $updater->start;
                my $service_id = $self->param('service_id');
                # Marking the restart of pfperl-api as complete since it will be complete when running in a container
                if ($action eq 'do_restart' && $service_id eq 'pfperl-api') {
                    if (open(my $fh, ">", $pfperl_api_restart_task)) {
                        print $fh $task_id;
                        close($fh);
                    }
                }
                my $data = $self->$action();
                $updater->completed($data);
            },
            sub {},
        );

        return $self->render( json => {status => 202, task_id => $task_id }, status => 202);
    }

    $subprocess->run(
        sub {
            my ($subprocess) = @_;
            my $results = $self->$action();
            return $results;
        },
        sub {
            my ($subprocess, $err, $results) = @_;
            return $self->render(json => $results);
         },
    );
}

sub do_start {
    my ($self) = @_;
    my $service = $self->stash->{item};
    return { start => $service->start(), pid => $service->pid() };
}

sub do_stop {
    my ($self) = @_;
    my $service = $self->stash->{item};
    return { stop => $service->stop() };
}

sub do_restart {
    my ($self) = @_;
    my $service = $self->stash->{item};
    return { restart => $service->restart(), pid => $service->pid() };
}

sub enable {
    my ($self) = @_;
    my $service = $self->_get_service_class($self->param('service_id'));
    if ($service) {
        return $self->render(json => { enable => $service->sysdEnable() });
    }
}

sub disable {
    my ($self) = @_;
    my $service = $self->_get_service_class($self->param('service_id'));
    if ($service) {
        return $self->render(json => { disable => $service->sysdDisable() });
    }
}

sub _decode_service_id {
    my ($self, $service_id) = @_;
    $service_id =~ tr/-/_/; 
    $service_id =~ tr/\./_/;
    return $service_id;
}

sub _get_service_class {
    my ($self, $service_id) = @_;
    my $class = $pf::services::ALL_MANAGERS{$service_id};
    if(defined($class) && $class->can('new')){
        return $class;
    }
    else {
        $self->log->error("Unable to find a service manager by the name of $service_id");
        return undef;
    }
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
