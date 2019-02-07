package captiveportal::PacketFence::Controller::Enabler;
use Moose;
use namespace::autoclean;
use pf::security_event;
use pf::class;

BEGIN { extends 'captiveportal::Base::Controller'; }

=head1 NAME

captiveportal::PacketFence::Controller::Enabler - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $portalSession = $c->portalSession;
    my $mac           = $portalSession->clientMac;

    $c->stash->{'user_agent'} = $c->request->user_agent;

    # check for open security_events
    my $security_event = security_event_view_top($mac);

    if ($security_event) {

        # There is a security_event, redirect the user
        # FIXME: there is not enough validation below
        my $security_event_id   = $security_event->{'security_event_id'};
        my $class = class_view($security_event_id);
        $c->stash(
            security_event_id => $security_event_id,
            enable_text  => $class->{button_text},
            template     => 'enabler.html',
        );
    } else {
        $self->showError( $c, "error: not found in the database" );
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
