package captiveportal::PacketFence::Controller::WirelessProfile;
use Moose;
use namespace::autoclean;
use File::Slurp qw(read_file);
use pf::constants;
use pf::util qw (isenabled);

BEGIN { extends 'captiveportal::Base::Controller'; }

use pf::config qw($reverse_fqdn);

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
    my $mac = $c->portalSession->clientMac;
    my $user_cache = $c->user_cache;
    my $pki_session = $user_cache->get("pki_session");
    unless ($pki_session) {
        $pki_session = $c->session;
    }
    my $stash = $c->stash;
    my $logger = $c->log;
    my $provisioner = $c->profile->findProvisioner($mac, $c->stash->{application}->root_module->node_info);
    $provisioner->authorize($mac) if (defined($provisioner));
    my $profile_template = $provisioner->profile_template;
    my $psk;
    if (isenabled($provisioner->dpsk)) {
        $psk = $provisioner->generate_dpsk($c->session->{username});
    } else {
        $psk = $provisioner->passcode;
    }

    $c->stash(
        template         => $profile_template,
        current_view     => 'MobileConfig',
        provisioner      => $provisioner,
        username         => $c->session->{username} ? $c->session->{username} : '',
        cert_content     => $pki_session->{b64_cert},
        cert_cn          => $pki_session->{certificate_cn},
        for_windows      => ($provisioner->{type} eq 'windows'),
        for_android      => ($provisioner->{type} eq 'android'),
        ca_cn            => $pki_session->{ca_cn},
        server_cn        => $pki_session->{server_cn},
        server_content   => $pki_session->{server_content},
        ca_content       => $pki_session->{ca_content},
        reverse_fqdn     => $reverse_fqdn,
        raw              => $TRUE,
        psk              => $psk,
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
