package captiveportal::PacketFence::Controller::LostStolen;
use Moose;
use namespace::autoclean;
use pf::security_event;
use pf::constants::security_event qw($LOST_OR_STOLEN);
use pf::node;
use pf::util qw(strip_username);

BEGIN { extends 'captiveportal::Base::Controller'; }

=head1 NAME

captiveportal::PacketFence::Controller::LostStolen - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(1) {
    my ( $self, $c, $mac ) = @_;
    my $node = node_view($mac);
    my $owner = lc($node->{pid});
    my $stripped_owner = strip_username($owner);
    my $username = lc($c->user_session->{username});
    my $stripped_username = strip_username($username);

    $c->stash(
        mac => $mac,
        template => 'lost_stolen.html',
    );
    if ( $stripped_username eq $stripped_owner ) {
        my $trigger = security_event_add($mac, $LOST_OR_STOLEN);

        if ($trigger) {
            $c->stash(
                status => 'success',
            );
        } else {
            $c->stash(
                status => 'error',
            );
        }
    } else {
        $c->stash(
            status => 'notowned',
        );
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
