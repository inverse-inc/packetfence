package captiveportal::PacketFence::Controller::Release;
use Moose;
use namespace::autoclean;
use pf::config;
use URI::Escape::XS qw(uri_escape uri_unescape);
use pf::util;

BEGIN { extends 'captiveportal::Base::Controller'; }

=head1 NAME

captiveportal::PacketFence::Controller::Release - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $request = $c->request;
    if ( $request->secure ) {
        $c->response->redirect( "http://"
              . $Config{'general'}{'hostname'} . "."
              . $Config{'general'}{'domain'}
              . '/access?destination_url='
              . uri_escape( $c->stash->{destination_url} ) );
    } else {
        $c->stash(
            timer         => $Config{'trapping'}{'redirtimer'},
            redirect_url  => $Config{'trapping'}{'redirecturl'},
            initial_delay => $CAPTIVE_PORTAL{'NET_DETECT_INITIAL_DELAY'},
            retry_delay   => $CAPTIVE_PORTAL{'NET_DETECT_RETRY_DELAY'},
            external_ip => $Config{'captive_portal'}{'network_detection_ip'},
            auto_redirect => $Config{'captive_portal'}{'network_detection'},
            image_path => $Config{'captive_portal'}{'image_path'},
        );

        # override destination_url if we enabled the always_use_redirecturl option
        if ( isenabled( $Config{'trapping'}{'always_use_redirecturl'} ) ) {
            $c->stash->{'destination_url'} =
              $Config{'trapping'}{'redirecturl'};
        }
        $c->stash->{template} = 'release.html';
        $c->detach;
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
