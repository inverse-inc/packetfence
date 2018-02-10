package pf::UnifiedApi::Controller::Services;

=head1 NAME

pf::UnifiedApi::Controller::Services -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Services

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::Crud';
use pf::services;


sub status {
    my ($self) = @_;
    my $class = "pf::services::manager::".$self->param('service');
    if(not $class->can('new') or not $class->can('status')){
        return $self->render(400, json => { message => $self->status_to_error_msg(400)});
    }
    my $service = $class->new();
    $self->render(json => { 
        alive => $service->isAlive(),
        managed => $service->isManaged(),
        enabled => $service->isEnabled(),
        pid => $service->pid(), 
    });
}

sub start {
    my ($self) = @_;
    my $class = "pf::services::manager::".$self->param('service');
    if(not $class->can('new') or not $class->can('start')){
        return $self->render(400, json => { message => $self->status_to_error_msg(400)});
    }
    my $service = $class->new();
    $self->render(json => { start => $service->start(), pid => $service->pid() });
}

sub stop {
    my ($self) = @_;
    my $class = "pf::services::manager::".$self->param('service');
    if(not $class->can('new') or not $class->can('stop')){
        return $self->render(400, json => { message => $self->status_to_error_msg(400)});
    }
    my $service = $class->new();
    $self->render(json => { stop => $service->stop() });
}

sub restart {
    my ($self) = @_;
    my $class = "pf::services::manager::".$self->param('service');
    if(not $class->can('new') or not $class->can('restart')){
        return $self->render(400, json => { message => $self->status_to_error_msg(400)});
    }
    my $service = $class->new();
    $self->render(json => { restart => $service->restart(), pid => $service->pid() });
}

sub enable {
    my ($self) = @_;
    my $class = "pf::services::manager::".$self->param('service');
    if(not $class->can('new') or not $class->can('sysdEnable')){
        return $self->render(400, json => { message => $self->status_to_error_msg(400)});
    }
    my $service = $class->new();
    $self->render(json => { enable => $service->sysdEnable() });
}

sub disable {
    my ($self) = @_;
    my $class = "pf::services::manager::".$self->param('service');
    if(not $class->can('new') or not $class->can('sysdDisable')){
        return $self->render(400, json => { message => $self->status_to_error_msg(400)});
    }
    my $service = $class->new();
    $self->render(json => { disable => $service->sysdDisable() });
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
