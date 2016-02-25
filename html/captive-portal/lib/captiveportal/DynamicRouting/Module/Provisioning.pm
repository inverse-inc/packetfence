package captiveportal::DynamicRouting::Module::Provisioning;

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

has 'skipable' => (is => 'rw', default => sub {'disabled'});

sub allowed_urls {[
    '/provisioning',
]}

sub next {
    my ($self) = @_;
    if($self->is_eap_tls) {
        $self->session->{tls_enrollment_completed} = $TRUE;
        $self->show_provisioning();
    }
}

sub get_provisioner {
    my ($self) = @_;
    $self->session->{provisioner} //= $self->app->profile->findProvisioner($self->current_mac);
    return $self->session->{provisioner};
}

sub is_eap_tls {
    my ($self) = @_;
    my $provisioner = $self->get_provisioner();
    if($provisioner->getPkiProvider && ($provisioner->{eap_type} eq $EAP_TLS) ) {
        return $TRUE;
    }
    return $FALSE;
}

sub show_provisioning {
    my ($self) = @_;
    my $args = {provisioner => $self->get_provisioner, skipable => isenabled($self->skipable)};
    $self->render($self->get_provisioner->template, $args);
}

sub execute_child {
    my ($self) = @_;
    my $provisioner = $self->get_provisioner();
    my $mac = $self->current_mac;
    
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
    elsif ($provisioner->authorize($mac) == 0) {
        $self->show_provisioning();
    }
    elsif ($self->app->request->parameters->{next} && isenabled($self->skipable)){
        $self->done();
    }
    else {
        $self->show_provisioning();
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

