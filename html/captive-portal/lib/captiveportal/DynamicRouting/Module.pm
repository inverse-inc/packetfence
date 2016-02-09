package captiveportal::DynamicRouting::Module;

=head1 NAME

DynamicRouting::Module

=head1 DESCRIPTION

Base Module for Dynamic Routing

=cut

use Moose;
use pf::log;
use pf::config;

has 'id' => (is => 'ro', required => 1);

has session => (is => 'rw', builder => '_build_session');

has new_node_info => (is => 'rw', builder => '_build_new_node_info', lazy => 1);

has app => (is => 'ro', required => 1, isa => 'captiveportal::DynamicRouting::Application');

has parent => (is => 'ro', required => 1, isa => 'captiveportal::DynamicRouting::Module');

has username => (is => 'rw', builder => '_build_username', lazy => 1);

has renderer => (is => 'rw');

sub _build_username {
    my ($self) = @_;
    return $self->app->session->{username};
}

after 'username' => sub {
    my ($self) = @_;
    get_logger->info("User ".$self->{username}." has authenticated on the portal.");
    $self->new_node_info->{pid} = $self->{username};
    $self->app->session->{username} = $self->{username};
};

sub _build_session {
    my ($self) = @_;
    my $module_session_id = "module_".$self->id;
    $self->app->session()->{$module_session_id} = $self->app->session()->{$module_session_id} // {};
    my $module_session = $self->app->session()->{$module_session_id};
    return $module_session;
}

# Validate that the reference will be updated!!!
sub _build_new_node_info {
    my ($self) = @_;
    $self->app->session()->{"new_node_info"} //= {};
    return $self->app->session()->{"new_node_info"};
}

sub current_mac {
    my ($self) = @_;
    return $self->app->session()->{"client_mac"};
}

sub _release_args {
    my ($self) = @_;
    return {
        timer         => $Config{'trapping'}{'redirtimer'},
        destination_url  => $self->app->session->{destination_url} || $self->app->profile->getRedirectURL(),
        initial_delay => $CAPTIVE_PORTAL{'NET_DETECT_INITIAL_DELAY'},
        retry_delay   => $CAPTIVE_PORTAL{'NET_DETECT_RETRY_DELAY'},
        external_ip => $Config{'captive_portal'}{'network_detection_ip'},
        auto_redirect => $Config{'captive_portal'}{'network_detection'},
        image_path => $Config{'captive_portal'}{'image_path'},
    };
}

sub execute {
    my ($self) = @_;
    if($self->parent){
        $self->parent->current_module($self->id);
    }
    $self->execute_child();
}

sub execute_child {
    inner();
}

sub execute_actions {
    # implement me in subclasses
}

sub done {
    my ($self) = @_;
    $self->execute_actions();
    $self->parent->next();
}

sub next {
    my ($self) = @_;
    $self->done();
}

sub render {
    my ($self, @params) = @_;
    if($self->renderer){
        $self->renderer->render(@params);
    }
    else {
        $self->app->render(@params);
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

