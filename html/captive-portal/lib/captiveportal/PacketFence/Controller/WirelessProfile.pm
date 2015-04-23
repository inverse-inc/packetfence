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
    my $stash = $c->stash;
    use Data::Dumper;
    my $logger = $c->log;
    my $provisioner = $c->profile->findProvisioner($mac);
    $provisioner->authorize($mac) if (defined($provisioner));
    $c->stash(
        template     => 'wireless-profile.xml',
        current_view => 'MobileConfig',
        provisioner  => $provisioner,
        username     => $username,
        certdata     => $c->session->{b64_cert},#$c->session->{cert_data},
        certcn       => $c->session->{certificate_cn},
        fingerprint  => $c->session->{fingerprint},
        for_windows  => ($provisioner->{type} eq 'windows'),
        for_ios      => ($provisioner->{type} eq 'mobileconfig'),
        cacn         => $c->session->{cacn},
        svrcn        => $c->session->{svrcn},
        svrdata      => $c->session->{svrdata},
        cadata       => $c->session->{cadata},
        #filesid      => $c->session->{filesid},
    );
    #if ($provisioner->{type} eq 'windows'){
    #    my ($self,$c) = @_;
    #    my $sid = $c->session->{sid};
    #    my $filename = "/usr/local/pf/html/captive-portal/content/packetfence-windows-agent.exe";
    #    my $newfile = "/usr/local/pf/html/captive-portal/content/packetfence-$sid.exe";
    #    my $magicfile = "/usr/local/pf/html/captive-portal/content/packetfence-\*.exe";
    #    rename $magicfile, $filename;
    #    rename $filename, $newfile;
    #    $c->stash( filesid => $newfile );
    #}
}

sub download :Path('mail.mobileconfig') {
    my ( $self, $c ) = @_;

    my $template = $c->stash->{template};

    my $filename = $c->forward('get_temp_filename');
    my $filename_signed = "$filename-signed";

    $template->process($c->config->{install_dir}."html/captive-portal/profile-templates/eaptls/wireless-profile.mobileconfig", 
                        $c->stash(), $filename);

    my $cmd = "bash ".$c->config->{install_dir}."addons/sign.sh $filename $filename_signed";
    my $result = `$cmd`;
    
    my $signed_profile = read_file( "$filename_signed" ) ;

    $c->response->body($signed_profile);

    $result = `rm -f $filename`;
    $result = `rm -f $filename_signed`;

    my $headers = $c->response->headers;
    $headers->content_type('application/x-apple-aspen-config; chatset=utf-8');
    $headers->header( 'Content-Disposition',
        'attachment; filename="wireless-profile.mobileconfig"' );

}

sub profile_xml : Path('/profile.xml') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{filename} = 'profile.xml';
    $c->forward('index');
}  

sub get_temp_filename :Private {
    my $fh = File::Temp->new(
        TEMPLATE => 'tempXXXXX',
        DIR      => '/tmp',
        SUFFIX   => '.dat',
    );

    return $fh->filename;
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
