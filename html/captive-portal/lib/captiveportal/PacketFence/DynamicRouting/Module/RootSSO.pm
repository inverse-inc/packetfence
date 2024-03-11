package captiveportal::PacketFence::DynamicRouting::Module::RootSSO;

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
    );
    return \%map;

});

use pf::log;
use pf::util;
use pf::CHI;
use pf::constants qw($TRUE);
use Bytes::Random::Secure;

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
    my $callback = $self->app->session->{callback};
    $self->app->reset_session;
    $self->app->redirect($callback."?error=canceled");
}

=head2 release

Reevaluate the access of the user and show the release page

=cut

sub release {
    my ($self) = @_;
    return $self->app->redirect($self->app->session->{callback}."?token=".$self->{root_session_token});
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
    my $rand = Bytes::Random::Secure->new(
            Bits        => 64,
            NonBlocking => 1,
        );
    my $token = unpack("H*", $rand->bytes(32));
    cache->set($token, $self->new_node_info);
    $self->{root_session_token} = $token;
    return $TRUE;
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

