package captiveportal::PacketFence::DynamicRouting::Module::Authentication::SMS;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication::SMS

=head1 DESCRIPTION

SMS authentication module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module::Authentication';
with 'captiveportal::Role::FieldValidation';

use pf::activation;
use pf::log;
use pf::constants;
use pf::sms_carrier;
use pf::web::guest;
use pf::auth_log;

has '+pid_field' => (default => sub { "telephone" });

has '+source' => (isa => 'pf::Authentication::Source::SMSSource');

=head2 allowed_urls_auth_module

The allowed URLs in this module

=cut

sub allowed_urls_auth_module {
    return [
        '/activate/sms',
    ];
}

=head2 execute_child

Execute the module

=cut

sub execute_child {
    my ($self) = @_;

    if($self->app->request->param("no-pin")){
        $self->no_pin();
    }
    elsif($self->app->request->method eq "POST" && $self->app->request->path eq "activate/sms" && defined($self->app->request->param("pin"))){
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

=head2 no_pin

User has no PIN, so we invalidate all of them and redirect back to the beginning

=cut

sub no_pin {
    my ($self) = @_;
    pf::activation::invalidate_codes_for_mac($self->current_mac, "sms");
    $self->app->redirect("/captive-portal");
}

=head2 prompt_fields

Prompt fields with source specific SMS carriers

=cut

sub prompt_fields {
    my ($self) = @_;

    my @carriers = map { { label => $_->{name}, value => $_->{id} } } @{sms_carrier_view_all($self->source)};
    $self->SUPER::prompt_fields({
        sms_carriers => \@carriers, 
    });
}

=head2 prompt_pin

Prompt for the activation PIN

=cut

sub prompt_pin {
    my ($self) = @_;
    $self->render("sms/validate.html");
}

=head2 validate_info

Validate the provided informations during the signup

=cut

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

    $self->session->{telephone} = $telephone;
    $self->session->{mobileprovider} = $mobileprovider;

    $self->session->{fields} = $self->request_fields;

    $self->prompt_pin();
}

=head2 validate_pin

Validate the provided PIN

=cut

sub validate_pin {
    my ($self, $pin) = @_;

    get_logger->debug("Mobile phone number validation attempt");

    if (my $record = pf::activation::validate_code($pin)) {
        return ($TRUE, 0, $record);
    }
    else {
        pf::auth_log::change_record_status($self->source->id, $self->current_mac, $pf::auth_log::FAILED);
        return ($FALSE, $GUEST::ERROR_INVALID_PIN);
    }
}

=head2 validation

Validate the provided PIN, check the retry limit and handle actions if its valid

=cut

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
        $self->username($record->{pid});
        pf::activation::set_status_verified($pin);
        pf::auth_log::record_completed_guest($self->source->id, $self->current_mac, $pf::auth_log::COMPLETED);
        $self->done();
    }
    else {
        $self->app->flash->{error} = $GUEST::ERRORS{$reason};
        $self->prompt_pin();
    }
}

=head2 auth_source_params_child

The parameters available for source matching

=cut

sub auth_source_params_child {
    my ($self) = @_;
    return {
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

