package captiveportal::PacketFence::Controller::NetworkLogoff;
use Moose;
use namespace::autoclean;
use pf::node;
use pf::constants::node qw($STATUS_REGISTERED);
use pf::enforcement qw(reevaluate_access);
use pf::util;

BEGIN { extends 'captiveportal::Base::Controller'; }

=head1 NAME

captiveportal::PacketFence::Controller::NetworkLogoff - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    if(isdisabled($c->portalSession->profile->{_network_logoff})) {
        $self->showError($c, "This feature is currently disabled. Please contact your network administrator for more details.");
        $c->detach();
    }

    unless($c->portalSession->clientMac) {
        $self->showError($c, "This feature cannot be accessed because the system is not able to find your MAC address. Please contact your network administrator for more details.");
        $c->detach();
    }

    my $mac = $c->portalSession->clientMac;
    my $node = $c->stash->{node} = node_view($mac);

    $c->stash(
        title => "Network Logoff",
        template => 'networklogoff.html',
    );

    if($node->{status} ne $STATUS_REGISTERED) {
        $c->log->info("Node is unregistered, user has already logged off or access has expired.");
    }
    elsif($c->request->method eq "POST") {
        $c->log->info("User has initiated termination of his network access");
        node_deregister($mac);
        reevaluate_access($mac, 'manage_deregister');
        # Reload the node
        $node = $c->stash->{node} = node_view($mac);
    }
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

