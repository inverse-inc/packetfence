package captiveportal::DynamicRouting::RootModule;

=head1 NAME

DynamicRouting::RootModule

=head1 DESCRIPTION

Root module for Dynamic Routing

=cut

use Moose;
extends 'captiveportal::DynamicRouting::AndModule';

use pf::node;
use pf::config;

has '+parent' => (required => 0);

sub done {
    my ($self) = @_;
    $self->execute_actions();
    $self->release();
}

sub release {
    my ($self) = @_;
    my $args = {
        timer         => $Config{'trapping'}{'redirtimer'},
        destination_url  => $self->app->session->{destination_url} || $self->app->profile->getRedirectURL(),
        initial_delay => $CAPTIVE_PORTAL{'NET_DETECT_INITIAL_DELAY'},
        retry_delay   => $CAPTIVE_PORTAL{'NET_DETECT_RETRY_DELAY'},
        external_ip => $Config{'captive_portal'}{'network_detection_ip'},
        auto_redirect => $Config{'captive_portal'}{'network_detection'},
        image_path => $Config{'captive_portal'}{'image_path'},
    };
    $self->render("release.html", $args);
}

sub execute_child {
    my ($self) = @_;
    my $node = node_view($self->current_mac);
    if($node->{status} eq "reg"){
        $self->app->flash->{notice} = "Your network access should already be enabled.";
        $self->release();
    }
    $self->SUPER::execute_child();
}

sub execute_actions {
    my ($self) = @_;
    $self->new_node_info->{status} = "reg";
    $self->apply_new_node_info();
}

sub apply_new_node_info {
    my ($self) = @_;
    node_modify($self->current_mac, %{$self->new_node_info()});
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

