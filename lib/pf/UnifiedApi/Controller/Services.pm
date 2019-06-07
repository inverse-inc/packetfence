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

sub resource {
    my ($self) = @_;

    my $service_id = $self->param('service_id');

    my $class = $self->_get_service_class($service_id);

    return 1 if defined($class);
    $self->render_error(404, { message => $self->status_to_error_msg(404) });
    return undef;
}

sub cluster_status {
    my ($self) = @_;
    my @services = @pf::services::ALL_MANAGERS;
    my @servers = $self->param('server') ? (pf::cluster::find_server_by_hostname($self->param('server')) // ()) : pf::cluster::enabled_servers;

    unless(@servers) {
        return $self->render_error(404, "No servers to fetch status from. If you supplied the server parameter, ensure that this host exists in the cluster.");
    }

    my @results;
    for my $server (@servers) {
        print "$server->{management_ip} \n";
        my $client = pf::api::unifiedapiclient->new;
        $client->host($server->{management_ip});
        my $stat = $client->call("GET", "/api/v1/services/status_all", {});
        push @results, { host => $server->{host}, services => $stat->{items} };
    }

    $self->render(json => { items => \@results });
}

sub list {
    my ($self) = @_;
    $self->render(json => { items => [ map {$_->name} grep { $_->name ne 'pf' } @pf::services::ALL_MANAGERS ] });
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

sub start {
    my ($self) = @_;
    my $service = $self->_get_service_class($self->param('service_id'));
    if ($service) {
        return $self->render(json => { start => $service->start(), pid => $service->pid() });
    }
}

sub stop {
    my ($self) = @_;
    my $service = $self->_get_service_class($self->param('service_id'));
    if ($service) {
        return $self->render(json => { stop => $service->stop() });
    }
}

sub restart {
    my ($self) = @_;
    my $service = $self->_get_service_class($self->param('service_id'));
    if ($service) {
        return $self->render(json => { restart => $service->restart(), pid => $service->pid() });
    }
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
