package captiveportal::PacketFence::Controller::WirelessProfile;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }
use pf::config;

__PACKAGE__->config( namespace => 'wireless-profile.mobileconfig', );

=head1 NAME

captiveportal::PacketFence::Controller::WirelessProfile - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $username = $c->session->{username} || 'admin';
    if ( defined $username ) {
        $c->stash(
            template     => 'wireless-profile.xml',
            current_view => 'MobileConfig',
            ssid         => $Config{'provisioning'}{'ssid'},
            username     => $username
        );
    } else {
        $c->detach( CaptivePortal => 'error' );
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
