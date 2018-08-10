package captiveportal::PacketFence::Controller::Node::Manager;

use Moose;
use namespace::autoclean;
use pf::constants;
use pf::config qw(%ConfigSelfService);
use pf::node;
use pf::enforcement qw(reevaluate_access);
use List::MoreUtils qw(any);

BEGIN {extends 'captiveportal::Base::Controller'; }

=head1 NAME

captiveportal::PacketFence::Controller::Node::Manager - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 unreg

=cut

sub unreg :Local :Args(1) {
    my ($self, $c, $mac) = @_;
    my $node = node_view($mac);
    my $username = lc($c->user_session->{username});
    my $owner = lc($node->{pid});
              
    my $device_reg_profile = $c->profile->{'_self_service'};
    my @allowed_roles = @{$ConfigSelfService{$device_reg_profile}{'roles_allowed_to_unregister'}};
    # Only validate the roles if there are some in the list
    if(scalar(@allowed_roles) > 0) {
        unless(any { $_ eq $node->{category} } @allowed_roles) {
            $c->stash( status_msg_error => "The role assigned to this device prevents it from being unregistered using this service.");
            $c->detach(Status => 'index');
        }
    }

    if ($username && $node) {
        $c->log->info("'$username' attempting to unregister $mac owned by '$owner'");
        if (($username ne $default_pid && $username ne $admin_pid ) && $username eq $owner) {
            node_deregister($mac, %$node);
            reevaluate_access($mac, "node_modify");
            $c->response->redirect("/status");
            $c->detach;
        } else {
            $self->showError($c,"Not allowed to deregister $mac");
        }

    } else {
        $self->showError($c,"Not logged in or node ID $mac is not known");
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
