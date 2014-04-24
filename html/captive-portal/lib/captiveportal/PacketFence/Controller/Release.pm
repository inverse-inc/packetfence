package captiveportal::PacketFence::Controller::Release;
use Moose;
use namespace::autoclean;
use pf::config;
use URI::Escape qw(uri_escape uri_unescape);
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

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
