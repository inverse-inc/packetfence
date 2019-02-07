package captiveportal::PacketFence::DynamicRouting::Module::Authentication::SMS;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication::SMS

=head1 DESCRIPTION

SMS authentication module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module::Authentication';
with 'captiveportal::Role::FieldValidation';

use pf::activation qw($SMS_ACTIVATION);
use pf::util qw(normalize_time);
use pf::log;
use pf::constants;
use pf::sms_carrier;
use pf::web::guest;
use pf::auth_log;

has '+pid_field' => (default => sub { "telephone" });

has '+source' => (isa => 'pf::Authentication::Source::SMSSource|pf::Authentication::Source::TwilioSource|pf::Authentication::Source::ClickatellSource');

=head2 allowed_urls_auth_module

The allowed URLs in this module

=cut

sub allowed_urls_auth_module {
    return [
        '/activate/sms',
    ];
}

=head2 _build_required_fields

Build the required fields based on the PID field, the custom fields and the mandatory fields of the source
Will remove the mobileprovider field from the required fields if there is only one choice available

=cut

sub _build_required_fields {
    my ($self) = @_;
    
    my @fields = @{$self->SUPER::_build_required_fields()};
    if(scalar(@{$self->carriers}) == 1) {
        @fields = (grep {$_ ne 'mobileprovider' } @fields);
        return \@fields;
    }
    else {
        return \@fields;
    }
}

=head2 execute_child

Execute the module

=cut

sub execute_child {
    my ($self) = @_;

    if ($self->app->request->param("no-pin")) {
        $self->no_pin();
    }
    elsif ($self->app->request->method eq "POST" && $self->app->request->path eq "activate/sms" && defined($self->app->request->param("pin"))){
        $self->validation();
    }
    elsif (pf::activation::activation_has_entry($self->current_mac, $SMS_ACTIVATION)) {
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
    if($self->app->preregistration) {
        get_logger->info("Invalidating codes for PID ".$self->session->{telephone});
        pf::activation::invalidate_codes(undef, $self->session->{telephone}, $self->session->{telephone});
    }
    else {
        get_logger->info("Invalidating codes for MAC address ".$self->current_mac);
        pf::activation::invalidate_codes_for_mac($self->current_mac, $SMS_ACTIVATION);
    }
    $self->redirect_root();
}

=head2 carriers

The SMS carriers based on the source

=cut

sub carriers {
    my ($self) = @_;
    if ( $self->source->meta->get_attribute('sms_carriers') ) {
        my @carriers = map { { label => $_->{name}, value => $_->{id} } } @{sms_carrier_view_all($self->source)};
        return \@carriers;
    }
    else {
        return [];
    }
}

=head2 prompt_fields

Prompt fields with source specific SMS carriers

=cut

sub prompt_fields {
    my ($self) = @_;

    if ( $self->source->meta->get_attribute('sms_carriers') ) {
        $self->SUPER::prompt_fields({
            sms_carriers => $self->carriers, 
        });
    } else {
        $self->SUPER::prompt_fields();
    }
}

=head2 prompt_pin

Prompt for the activation PIN

=cut

sub prompt_pin {
    my ($self) = @_;
    $self->render("sms/validate.html", {title => "Confirm Mobile Phone Number"});
}

=head2 validate_info

Validate the provided informations during the signup

=cut

sub validate_info {
    my ($self) = @_;

    my $telephone = $self->request_fields->{telephone};
    my $pid = $self->request_fields->{$self->pid_field};
    $pid =~ s/[\(\) \-]//g;
    my @carriers = @{$self->carriers};
    my $mobileprovider = (scalar(@carriers) == 1) ? $carriers[0]->{"value"} : $self->request_fields->{mobileprovider};
    
    if ($self->app->reached_retry_limit('sms_request_limit', $self->app->profile->{_sms_request_limit})) {
        $self->app->flash->{error} = $GUEST::ERRORS{$GUEST::ERROR_MAX_RETRIES};
        $self->prompt_fields();
        return 0;
    }

    $self->update_person_from_fields();

    my %args = (
        mac         => $self->current_mac,
        pid         => $pid,
        pending     => $telephone,
        type        => "sms",
        portal      => $self->app->profile->getName,
        provider_id => $mobileprovider,
        timeout     => normalize_time($self->source->{sms_activation_timeout}),
        source      => $self->source,
        message     => $self->app->i18n($self->source->message),
        style       => 'digits',
        code_length => $self->source->pin_code_length,
    );
    my ( $status, $message ) = pf::activation::sms_activation_create_send( %args );
    unless ( $status ) {
        $self->app->flash->{error} = $message;
        $self->prompt_fields();
        return;
    };

    pf::auth_log::record_guest_attempt($self->source->id, $self->current_mac, $pid, $self->app->profile->name);

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
    if (pf::activation::is_expired($pin)) {
        pf::auth_log::change_record_status($self->source->id, $self->current_mac, $pf::auth_log::FAILED);
        return ($FALSE, $self->app->i18n($GUEST::ERROR_EXPIRED_PIN));
    }
    my $mac = $self->current_mac;
    if (my $record = pf::activation::validate_code_with_mac($SMS_ACTIVATION, $pin, $mac)) {
        $self->transfer_saving_fields();
        return ($TRUE, 0, $record);
    }
    pf::auth_log::change_record_status($self->source->id, $mac, $pf::auth_log::FAILED, $self->app->profile->name);
    return ($FALSE, $self->app->i18n($GUEST::ERROR_INVALID_PIN));
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
        $self->app->flash->{error} = "No PIN provided";
        $self->prompt_pin;
        return;
    }
    my ($status, $reason, $record) = $self->validate_pin($pin);
    if($status){
        $self->username($record->{pid});
        my $mac = $self->current_mac;
        pf::activation::set_status_verified_by_mac($SMS_ACTIVATION, $pin, $mac);
        pf::auth_log::record_completed_guest($self->source->id, $mac, $pf::auth_log::COMPLETED, $self->app->profile->name);
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

