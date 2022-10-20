package captiveportal::PacketFence::DynamicRouting::Module::RootSession;

=head1 NAME

DynamicRouting::RootModule

=head1 DESCRIPTION

Root module for Dynamic Routing

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module::Chained';
with 'captiveportal::Role::Routed';

has '+route_map' => (default => sub {
    tie my %map, 'Tie::IxHash', (
        '/logout' => \&logout,
        '/access' => \&release,
        '/record_destination_url' => \&record_destination_url,
    );
    return \%map;

});

use pf::log;
use pf::node;
use pf::config qw($default_pid);
use pf::constants qw($TRUE $FALSE);
use pf::util;
use pf::Portal::Session;
use pf::CHI;

sub cache { return pf::CHI->new(namespace => 'portaladmin'); }

has '+parent' => (required => 0);

=head2 around done

Once this is done, we release the user on the network

=cut

around 'done' => sub {
    my ($orig, $self) = @_;
    if($self->execute_actions()){
        $self->release();
    }
    else {
        $self->app->reset_session();
        $self->redirect_root();
    }
};

=head2 logout

Logout of the captive portal

=cut

sub logout {
    my ($self) = @_;
    $self->app->reset_session;
    $self->redirect_root();
}

=head2 release

Reevaluate the access of the user and show the release page

=cut

sub release {
    my ($self) = @_;

    my $lang = $self->app->session->{lang} // "";
    return $self->app->redirect($self->app->session->{callback}."/?token=".$self->uuid);
}

=head2 execute_child

Execute the flow for this module

=cut

sub execute_child {
    my ($self) = @_;
    if ($self->app->request->param('callback')) {
        $self->app->session->{callback} = $self->app->request->param('callback');
    }

    $self->SUPER::execute_child();
}

=head2 execute_actions

Register the device and apply the new node info

=cut

sub execute_actions {
    my ($self) = @_;
    my $ug    = Data::UUID->new;
    my $uuid = pf::util::get_uuid();
    cache->set($uuid, $self->new_node_info);
    $self->{uuid} = $uuid;
}

=head2 record_destination_url

Record the destination URL wanted by the user

=cut

sub record_destination_url {
    my ($self) = @_;
    $self->app->session->{user_destination_url} = $self->app->request->param('destination_url');
    $self->app->response_code(200);
    $self->app->template_output('');
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2022 Inverse inc.

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

