package captiveportal::PacketFence::Controller::WirelessProfile;
use Moose;
use namespace::autoclean;

BEGIN { extends 'captiveportal::Base::Controller'; }
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
    my $username = $c->session->{username} || '';
    my $mac = $c->portalSession->clientMac;
    my $session = $c->session;
    use Data::Dumper;
    my $logger = $c->log;
    my $provisioner = $c->profile->findProvisioner($mac);
    $provisioner->authorize($mac) if (defined($provisioner));
    $logger->info(Dumper $provisioner);
    $c->stash(
        template     => 'wireless-profile.xml',
        current_view => 'MobileConfig',
        provisioner  => $provisioner,
        username     => $username,
        certdata     => $c->session->{b64_cert},#$c->session->{cert_data},
        certcn       => $c->session->{certificate_cn},
        fingerprint  => $c->session->{fingerprint},
    );
}

sub profile_xml : Path('/profile.xml') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{filename} = 'profile.xml';
    $c->forward('index');
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
