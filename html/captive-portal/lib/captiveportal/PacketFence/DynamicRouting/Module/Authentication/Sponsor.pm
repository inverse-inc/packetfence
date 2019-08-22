package captiveportal::PacketFence::DynamicRouting::Module::Authentication::Sponsor;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication::Sponsor

=head1 DESCRIPTION

Sponsoring module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module::Authentication';
with 'captiveportal::Role::FieldValidation';

use pf::log;
use pf::constants qw($TRUE);
use pf::config qw(%Config);
use Date::Format qw(time2str);
use List::MoreUtils qw(any);
use pf::Authentication::constants;
use pf::activation;
use pf::web::guest;
use pf::auth_log;
use pf::util qw(normalize_time);
use pf::constants::realm;

has '+source' => (isa => 'pf::Authentication::Source::SponsorEmailSource');

has 'forced_sponsor' => ('is' => 'rw');

=head2 allowed_urls_auth_module

The allowed URLs in this module

=cut

sub allowed_urls_auth_module {
    return [
        '/sponsor/check',
    ];
}

=head2 _build_required_fields

Build the required fields based on the PID field, the custom fields and the mandatory fields of the source
Will remove the sponsor field from the required fields if there is a forced sponsor

=cut

sub _build_required_fields {
    my ($self) = @_;
    
    my @fields = @{$self->SUPER::_build_required_fields()};
    if($self->forced_sponsor) {
        @fields = (grep {$_ ne 'sponsor'  } @fields);
        return \@fields;
    }
    else {
        return \@fields;
    }
}

=head2 before done

We record the completed sponsorship in the auth_log

=cut

before 'done' => sub {
    my ($self) = @_;
    pf::auth_log::record_completed_guest($self->source->id, $self->current_mac, $pf::auth_log::COMPLETED, $self->app->profile->name);
};

=head2 execute_child

Execute the module

=cut

sub execute_child {
    my ($self) = @_;
    if($self->app->request->path eq "sponsor/check"){
        $self->check_activation();
    }
    elsif($self->app->request->method eq "POST"){
        $self->do_sponsor_registration();
    }
    elsif(pf::activation::activation_has_entry($self->current_mac,'sponsor')){
        $self->check_session_activation();
        $self->waiting_room();
    }
    elsif($self->session->{sponsor_activated}){
        $self->done();
    }
    else{
        $self->prompt_fields();
    }
}

=head2 check_session_activation

If the activation entry cannot be restored from the session, it will redirect to signup after invalidating any previous codes

=cut

sub check_session_activation {
    my ($self) = @_;
    unless($self->session->{activation_code}){
        get_logger->error("Cannot restore activation code from user session.");
        pf::activation::invalidate_codes_for_mac($self->current_mac, "sponsor");
        $self->app->redirect("/signup");
        $self->detach();
    }
}

=head2 check_activation

Check if the access has been approved

=cut

sub check_activation {
    my ($self) = @_;
    
    $self->check_session_activation();

    my $record = pf::activation::view_by_code($pf::activation::SPONSOR_ACTIVATION, $self->session->{activation_code});
    if($record->{status} eq "verified"){
        get_logger->info("Activation record has been validated.");
        $self->session->{sponsor_activated} = $TRUE;
        $self->session->{unregdate} = $record->{'unregdate'};
        $self->app->response_code(200);
        $self->app->template_output('');
    }
    else {
        get_logger->debug("Activation record has not yet been validated");
        $self->app->response_code(401);
        $self->app->template_output('');
    }
}

=head2 do_sponsor_registration

Handle the signup and create the sponsor request

=cut

sub do_sponsor_registration {
    my ($self) = @_;
    my %info;
    my $logger = get_logger();
    $logger->info("registering guest through a sponsor");
    my $source = $self->source;
    my $pid = $self->request_fields->{$self->pid_field};
    my $email = $self->request_fields->{email};
    $info{'pid'} = $pid;
    my ( $status, $status_msg ) = $source->authenticate($pid);
    unless ( $status ) {
        $self->app->flash->{error} = $status_msg;
        $self->prompt_fields();
        return;
    }

    if ((any { $_ eq 'email' } @{$self->required_fields // []}) && !$source->isEmailAllowed($email)) {
        $logger->warn("EmailSource ($source->{id}) failed to authenticate PID '$email' is banned");
        $self->app->flash->{error} = $pf::constants::authentication::messages::EMAIL_UNAUTHORIZED;
        $self->prompt_fields();
        return;
    }

    my $sponsor = $self->forced_sponsor || $self->request_fields->{sponsor};
    return unless($self->_validate_sponsor($sponsor));

    # form valid, adding person (using modify in case person already exists)
    my $note = 'sponsored confirmation Date of arrival: ' . time2str("%Y-%m-%d %H:%M:%S", time);
    $logger->info( "Adding guest person $pid" );

    $info{'bcc'} = $source->{sponsorship_bcc};
    $info{'activation_domain'} = $source->{activation_domain} if (defined($source->{activation_domain}));
    $info{'activation_timeout'} = normalize_time($source->{email_activation_timeout});
    # fetch more info for the activation email
    # this is meant to be overridden in pf::web::custom with customer specific needs
    foreach my $key (qw(firstname lastname telephone company)) {
        $info{$key} = $self->request_fields->{$key};
    }

    $info{'sponsor'} = $sponsor;
    $info{'subject'} = ["%s: Guest access request", $Config{'general'}{'domain'}];
    $info{'source_id'} = $source->id;
    $info{'lang'} = $source->lang  // $Config{'advanced'}{'language'};

    # TODO this portion of the code should be throttled to prevent malicious intents (spamming)
    my ( $auth_return, $err, $activation_code ) =
      pf::activation::create_and_send_activation_code(
        $self->current_mac,
        $pid,
        $info{'sponsor'},
        $pf::web::guest::TEMPLATE_EMAIL_SPONSOR_ACTIVATION,
        $pf::activation::SPONSOR_ACTIVATION,
        $self->app->profile->getName,
        %info,
      );

    pf::auth_log::record_guest_attempt($source->id, $self->current_mac, $pid, $self->app->profile->name);

    $self->session->{activation_code} = $activation_code;
    $self->app->session->{email} = $email;
    $self->username($email);

    $self->update_person_from_fields(additionnal_fields => {notes => $note});

    $self->waiting_room();
}

=head2 waiting_room

Push the user in a waiting room where he will wait for the access to be activated

=cut

sub waiting_room {
    my ($self) = @_;
    $self->render("waiting.html", $self->_release_args());
}

=head2 _validate_sponsor

Validate the provided sponsor is allowed to do sponsoring

=cut

sub _validate_sponsor {
    my ($self, $sponsor_email) = @_;
    # Putting no context to that authentication request as no stripping has to be done here since its an email
    my @sources;
    foreach my $source (@{$self->source->sources}) {
        push @sources, pf::authentication::getAuthenticationSource($source);
    }
    @sources = @{pf::authentication::getInternalAuthenticationSources()} if !(scalar @sources);

    my $value = pf::authentication::match( \@sources, { email => $sponsor_email, 'rule_class' => $Rules::ADMIN , 'context' => $pf::constants::realm::NO_CONTEXT}, $Actions::MARK_AS_SPONSOR );

    if (!defined $value) {
        $self->app->flash->{error} = [ $GUEST::ERRORS{$GUEST::ERROR_SPONSOR_NOT_ALLOWED}, $sponsor_email ];
        $self->prompt_fields();
        return 0;
    }
    return 1;
}

=head2 auth_source_params_child

The parameters available for source matching

=cut

sub auth_source_params_child {
    my ($self) = @_;
    return {
        user_email => $self->app->session->{email},
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

