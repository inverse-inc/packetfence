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

sub start {
    my ($self) = @_;
    my $return = systemctl("start", $self->param('system_service_id'));
    return $self->render(json => {message => ($return ? "Service couldn't be started" : "Service has been started")}, status => ($return ? 500 : 200));
}

sub stop {
    my ($self) = @_;
    my $return = systemctl("stop", $self->param('system_service_id'));
    return $self->render(json => {message => ($return ? "Service couldn't be stopped" : "Service has been stopped")}, status => ($return ? 500 : 200));
}

sub restart {
    my ($self) = @_;
    my $return = systemctl("restart", $self->param('system_service_id'));
    return $self->render(json => {message => ($return ? "Service couldn't be restarted" : "Service has been restarted")}, status => ($return ? 500 : 200));
}

sub enable {
    my ($self) = @_;
    my $return = systemctl("enable", $self->param('system_service_id'));
    return $self->render(json => {message => ($return ? "Service couldn't be enabled" : "Service has been enabled")}, status => ($return ? 500 : 200));
}

sub disable {
    my ($self) = @_;
    my $return = systemctl("enable", $self->param('system_service_id'));
    return $self->render(json => {message => ($return ? "Service couldn't be disabled" : "Service has been disabled")}, status => ($return ? 500 : 200));
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
