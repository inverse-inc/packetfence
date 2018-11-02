package captiveportal::PacketFence::DynamicRouting::Module::Provisioning;

=head1 NAME

captiveportal::DynamicRouting::Module::Provisioning

=head1 DESCRIPTION

Provisioning module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module';

use pf::constants;
use pf::constants::eap_type qw($EAP_TLS);
use pf::log;
use captiveportal::DynamicRouting::Module::TLSEnrollment;
use pf::util;
use pf::provisioner;
use pf::node;

has 'skipable' => (is => 'rw', default => sub {'disabled'});

=head2 allowed_urls

The allowed URLs for the module

=cut

sub allowed_urls {[
    '/provisioning',
]}

=head2 next

Handle the next of a child module
This module can have a TLSEnrolment child module, so when that is the case, we continue on the actual provisioning of the device

=cut

sub next {
    my ($self) = @_;
    if($self->is_eap_tls) {
        $self->session->{tls_enrollment_completed} = $TRUE;
        $self->show_provisioning();
    }
}

=head2 get_provisioner

Get the provisioner from the session or the connection profile

=cut

sub get_provisioner {
    my ($self) = @_;
    my $provisioner = defined($self->session->{provisioner_id}) ? 
        pf::factory::provisioner->new($self->session->{provisioner_id}) :
        $self->app->profile->findProvisioner($self->current_mac, $self->node_info);
    if(defined($provisioner)){
        $self->session->{provisioner_id} = $provisioner->id;
    }
    return $provisioner;
}

=head2 is_eap_tls

Check if we are doing EAP-TLS enrollment

=cut

sub is_eap_tls {
    my ($self) = @_;
    my $provisioner = $self->get_provisioner();
    if($provisioner->getPkiProvider && ($provisioner->{eap_type} eq $EAP_TLS) ) {
        return $TRUE;
    }
    return $FALSE;
}

=head2 is_dpsk

Check if we are doing dpsk enrollment

=cut

sub is_dpsk {
    my ($self) = @_;
    my $provisioner = $self->get_provisioner();
    if(ref($provisioner) =~ /dpsk/) {
        return $TRUE;
    }
    return $FALSE;
}

=head2 show_provisioning

Show the provisioner template

=cut

sub show_provisioning {
    my ($self, $arg) = @_;
    $arg = $arg // {},
    my $args = {
        fingerbank_info => pf::node::fingerbank_info($self->current_mac, $self->node_info),
        provisioner => $self->get_provisioner,
        skipable => isenabled($self->skipable),
        title => ["Provisioning : %s",$self->get_provisioner->id],
        %{$arg},
    };
    $self->render($self->get_provisioner->template, $args);
}

=head2 execute_child

Find the provisioner and proceed to the actions related to it

=cut

sub execute_child {
    my ($self) = @_;
    my $provisioner = $self->get_provisioner();
    my $mac = $self->current_mac;

    # Save the new node attributes since the provisioning workflow may bring the user outside of the portal (DPSK, WPA2 provisioning, etc)
    node_modify($mac, %{$self->new_node_info});
    
    unless($provisioner){
        get_logger->info("No provisioner found for $mac. Continuing.");
        $self->done();
        return;
    }
    
    get_logger->info("Found provisioner " . $provisioner->id . " for $mac");
    if( $self->is_eap_tls && !$self->session->{tls_enrollment_completed} ) {
        my $tls_module = captiveportal::DynamicRouting::Module::TLSEnrollment->new(id => $self->id."_pki_module", parent => $self, app => $self->app, pki_provider_id => $provisioner->getPkiProvider()->id);
        $tls_module->execute();
    }
    elsif ($self->is_dpsk) {
        $self->show_provisioning({psk => $provisioner->generate_dpsk($self->username), ssid => $provisioner->ssid});
    }
    elsif ($self->app->request->parameters->{next} && isenabled($self->skipable)){
        $self->done();
    }
    elsif ($provisioner->authorize($mac) == 0) {
        $self->app->flash->{notice} = [ "According to the provisioner %s, your device is not allowed to access the network. Please follow the instruction below.", $provisioner->description ];
        $self->show_provisioning();
    }
    elsif ($provisioner->authorize($mac) == $TRUE || $provisioner->authorize($mac) == $pf::provisioner::COMMUNICATION_FAILED) {
        $self->done();
    }
    else {
        $self->show_provisioning();
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

