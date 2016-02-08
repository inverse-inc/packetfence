package captiveportal::DynamicRouting::AuthModule::SMS;

=head1 NAME

DynamicRouting::AuthModule::SMS

=head1 DESCRIPTION

SMS authentication module

=cut

use Moose;
extends "captiveportal::DynamicRouting::AuthModule";
with 'captiveportal::DynamicRouting::FieldValidation';

use pf::activation;
use pf::log;
use pf::constants;
use pf::sms_carrier;
use pf::web::guest;

has '+pid_field' => (default => sub { "telephone" });

sub required_fields_child {
    return ["telephone", "mobileprovider"];
}

sub execute_child {
    my ($self) = @_;

    if($self->app->request->method eq "POST" && defined($self->app->request->param("pin"))){
        $self->validation();
    }
    elsif(pf::activation::activation_has_entry($self->current_mac,'sms')){
        $self->prompt_pin();
    }
    elsif($self->app->request->method eq "POST"){
        $self->validate_info();
    }
    else {
        $self->prompt_fields();
    }
}

sub prompt_fields {
    my ($self) = @_;

    my @carriers = map { { label => $_->{name}, value => $_->{id} } } @{sms_carrier_view_all($self->source)};
    $self->SUPER::prompt_fields({
        sms_carriers => \@carriers, 
    });
}

sub prompt_pin {
    my ($self) = @_;
    $self->render("sms/validate.html");
}

sub validate_info {
    my ($self) = @_;

    my $telephone = $self->request_fields->{telephone};
    my $pid = $self->request_fields->{$self->pid_field};
    my $mobileprovider = $self->request_fields->{mobileprovider};
    
    if ($self->app->reached_retry_limit('sms_request_limit', $self->app->profile->{_sms_request_limit})) {
        $self->app->flash->{error} = $GUEST::ERRORS{$GUEST::ERROR_MAX_RETRIES};
        $self->prompt_fields();
        return 0;
    }

    $self->update_person_from_fields();
    pf::activation::sms_activation_create_send( $self->current_mac, $pid, $telephone, $self->app->profile->getName, $mobileprovider );

    $self->username($pid);
    $self->session->{telephone} = $telephone;
    $self->session->{mobileprovider} = $mobileprovider;

    $self->session->{fields} = $self->request_fields;

    $self->prompt_pin();
}

sub validate_pin {
    my ($self, $pin) = @_;

    get_logger->debug("Mobile phone number validation attempt");

    if (my $record = pf::activation::validate_code($pin)) {
        return ($TRUE, 0, $record);
    }
    else {
        return ($FALSE, $GUEST::ERROR_INVALID_PIN);
    }
}

sub validation {
    my ($self) = @_;
        
    if ($self->app->reached_retry_limit('sms_retries', $self->app->profile->{_sms_pin_retry_limit})) {
        $self->app->flash->{error} = $GUEST::ERRORS{$GUEST::ERROR_MAX_RETRIES};
        $self->prompt_pin();
        return;
    }

    my $pin = $self->app->hashed_params->{'pin'};
    unless($pin){
        $self->app->flash->{error} = $self->app->i18n("No PIN provided.");
        $self->prompt_pin;
        return;
    }
    my ($status, $reason, $record) = $self->validate_pin($pin);
    if($status){
        pf::activation::set_status_verified($pin);
        $self->done();
    }
    else {
        $self->app->flash->{error} = $GUEST::ERRORS{$reason};
        $self->prompt_pin();
    }
}

sub auth_source_params {
    my ($self) = @_;
    return {
        username => $self->app->session->{username},
        telephone => $self->session->{telephone}
    };
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

