package captiveportal::PacketFence::DynamicRouting::Module::Authentication::Email;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication::Email

=head1 DESCRIPTION

Login registration

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module::Authentication';
with 'captiveportal::Role::FieldValidation';

has '+source' => (
    isa => 'pf::Authentication::Source::EmailSource',
    lazy => 1,
    builder => '_build_source',
);

use pf::activation;
use pf::auth_log;
use pf::config qw(%Config);
use pf::constants qw($TRUE $FALSE);
use pf::log;
use pf::authentication;
use pf::Authentication::constants;
use Date::Format qw(time2str);
use pf::util;
use pf::node;
use pf::enforcement;
use POSIX;

=head2 allowed_urls_auth_module

The allowed URLs in this module

=cut

sub allowed_urls_auth_module {
    return [
        '/email/check',
    ];
}

=head2 execute_child

Execute this module

=cut

sub execute_child {
    my ($self) = @_;
    if($self->app->request->path eq "email/check"){
        $self->check_activation();
    }
    elsif($self->app->request->method eq "POST"){
        $self->do_email_registration();
    }
    elsif($self->source->waitForActivation && $self->session_activation_pending()){
        $self->waiting_room();
    }
    elsif($self->session->{email_activated}){
        # Cleared before done() so that if the actions fail, the user gets the
        # form back instead of looping on done() with an already verified code
        delete $self->session->{email_activated};
        delete $self->session->{activation_code};
        $self->done();
    }
    else{
        $self->prompt_fields();
    }
};

=head2 check_session_activation

If the activation entry cannot be restored from the session, it will redirect to signup after invalidating any previous codes

=cut

sub check_session_activation {
    my ($self) = @_;
    unless($self->session->{activation_code}){
        get_logger->error("Cannot restore activation code from user session.");
        pf::activation::invalidate_codes_for_mac($self->current_mac, $pf::activation::GUEST_ACTIVATION);
        $self->app->redirect("/signup");
        $self->detach();
    }
}

=head2 session_activation_pending

Whether the activation code stored in the session is still waiting to be
clicked (unverified and not expired). Other codes of the same device are
ignored: they may belong to another registration that invalidated this one.

=cut

sub session_activation_pending {
    my ($self) = @_;
    my $code = $self->session->{activation_code};
    return $FALSE unless $code;
    return defined(pf::activation::find_unverified_code($pf::activation::GUEST_ACTIVATION, $code)) ? $TRUE : $FALSE;
}

=head2 check_activation

Polled by the waiting room. Answers 200 once the activation link has been
clicked (or once the code can no longer be activated, so the user is sent
back to the signup form), 401 while the code is still pending.

=cut

sub check_activation {
    my ($self) = @_;

    $self->check_session_activation();

    my $record = pf::activation::view_by_code($pf::activation::GUEST_ACTIVATION, $self->session->{activation_code});
    if(defined($record) && $record->{status} eq $pf::activation::VERIFIED){
        get_logger->info("Activation record has been validated.");
        $self->session->{email_activated} = $TRUE;
        $self->app->response_code(200);
        $self->app->template_output('');
    }
    elsif(!$self->source->waitForActivation){
        get_logger->info("The source no longer waits for the activation on the portal. Sending the user back to the signup form.");
        $self->app->response_code(200);
        $self->app->template_output('');
    }
    elsif(!$self->session_activation_pending()){
        get_logger->info("Activation record has expired or was invalidated. Sending the user back to the signup form.");
        $self->app->flash->{error} = "The activation link has expired. Please register again.";
        $self->app->response_code(200);
        $self->app->template_output('');
    }
    else {
        get_logger->debug("Activation record has not yet been validated");
        $self->app->response_code(401);
        $self->app->template_output('');
    }
}

=head2 waiting_room

Keep the user on the portal until the activation link is clicked

=cut

sub waiting_room {
    my ($self) = @_;
    $self->render("waiting.html", {
        email_activation => $TRUE,
        check_url => '/email/check',
        email => $self->app->session->{email},
        %{$self->_release_args()},
    });
}

sub required_fields_child {['email_instructions']}

my @auto_included = qw(firstname lastname);
my %auto_included = map { $_ => 1 } @auto_included;

=head2 do_email_registration

Perform the e-mail registration using the provided info

=cut

sub do_email_registration {
    my ($self) = @_;
    my $logger = get_logger;

    # fetch role for this user
    my $source = $self->source;
    my $request_fields = $self->request_fields;
    my $pid = $request_fields->{$self->pid_field};
    my $email = $request_fields->{email};

    my ( $status, $status_msg ) = $source->authenticate($pid);
    unless ( $status ) {
        $self->app->flash->{error} = $status_msg;
        $self->prompt_fields();
        return;
    }

    my %info;
    $info{'activation_domain'} = $source->{activation_domain} if (defined($source->{activation_domain}));
    $info{'activation_timeout'} = normalize_time($source->{email_activation_timeout});
    $info{'wait_for_activation'} = $source->waitForActivation;

    # form valid, adding person (using modify in case person already exists)
    my $note = 'email activation. Date of arrival: ' . time2str("%Y-%m-%d %H:%M:%S", time);
    $self->update_person_from_fields(notes => $note);

    my @additional_fields;
    $info{additional_fields} = \@additional_fields;
    for my $key ( grep { !exists $auto_included{$_} && exists $pf::person::ALLOWED_PROMPTABLE_FIELDS{$_} } @{$self->required_fields // []}) {
        my $value = $request_fields->{$key};
        next unless defined $value;
        push @additional_fields, { label => ucfirst($key), value => $value };
        $info{$key} = $value;
    }
    $info{lang} = clean_locale(setlocale(POSIX::LC_MESSAGES));

    $info{'firstname'} = $self->request_fields->{firstname};
    $info{'lastname'} = $self->request_fields->{lastname};
    $info{'telephone'} = $self->request_fields->{telephone};
    $info{'company'} = $self->request_fields->{company};
    $info{'subject'} = $self->app->i18n_format("%s: Email activation required", $Config{'general'}{'domain'});
    $info{source_id} = $source->id;
    utf8::decode($info{'subject'});

    $self->session->{fields} = $self->request_fields;
    $self->app->session->{email} = $email;
    $self->username($pid);

    pf::auth_log::record_guest_attempt($source->id, $source->type, $self->current_mac, $pid, $self->app->profile->name);
    # When waiting for the activation, the registration is only completed once the link is clicked
    pf::auth_log::record_completed_guest($source->id, $source->type, $self->current_mac, $pf::auth_log::COMPLETED, $self->app->profile->name) unless $source->waitForActivation;

    if($self->app->preregistration) {
        # Mark the registration as completed as the email doesn't have to be validated
        pf::auth_log::record_completed_guest($source->id, $source->type, $self->current_mac, $pf::auth_log::COMPLETED, $self->app->profile->name);
        $self->done();
    }
    else {
        # Report a source whose rules cannot register the device now, while the
        # user can still act on it, rather than after the link has been clicked
        unless($self->rules_allow_registration()) {
            get_logger->warn("The rules of source ".$source->id." do not allow $pid to register a device, no activation email sent");
            $self->app->flash->{error} = "You do not have permission to register a device with this username";
            $self->session->{source_id} = undef;
            $self->prompt_fields();
            return;
        }

        # TODO this portion of the code should be throttled to prevent malicious intents (spamming)
        my ( $auth_return, $err, $activation_code ) =
          pf::activation::create_and_send_activation_code(
            $self->current_mac,
            $pid, $email,
            $pf::web::guest::TEMPLATE_EMAIL_GUEST_ACTIVATION,
            $pf::activation::GUEST_ACTIVATION,
            $self->app->profile->getName,
            %info,
          );

        $self->session->{activation_code} = $activation_code;

        if($source->waitForActivation) {
            # No temporary access: the device stays on the portal until the
            # link is clicked (typically from another device). The waiting
            # room polls /email/check and done() is called once verified.
            unless($auth_return && defined($activation_code)) {
                get_logger->error("Unable to create or send the activation code for $email, the device cannot wait for an activation that will never come");
                if(defined($activation_code)) {
                    my $record = pf::activation::view_by_code($pf::activation::GUEST_ACTIVATION, $activation_code);
                    pf::activation::modify_status($record->{code_id}, $pf::activation::INVALIDATED) if $record;
                }
                delete $self->session->{activation_code};
                $self->app->flash->{error} = "Unable to send the activation email. Please try again later.";
                $self->prompt_fields();
                return;
            }
            $self->waiting_room();
            return;
        }

        # We compute the data and release the user
        # He will come back afterwards.
        $self->execute_actions();
        $self->new_node_info->{status} = "reg";
        $self->app->root_module->apply_new_node_info();
        $self->app->root_module->release();
    }
}

=head2 rules_allow_registration

Dry run of the actions to know if the source's rules can register the device
(a role and an unregdate, time balance or bandwidth balance).
Only the actions themselves are run: the local account is not created and the
computed node info and session values are restored afterwards.

=cut

sub rules_allow_registration {
    my ($self) = @_;
    my $session = $self->app->session;
    my @session_keys = qw(destination_url portal_module_force_destination_url mfa_id);
    my %saved_session = map { exists($session->{$_}) ? ($_ => $session->{$_}) : () } @session_keys;
    my %saved_node_info = %{$self->new_node_info};

    $self->captiveportal::DynamicRouting::Module::execute_actions();
    my $allowed = ($self->app->isRootSSO && defined($self->new_node_info->{access_level}))
        || $self->new_node_info_allows_registration();

    %{$self->new_node_info} = %saved_node_info;
    foreach my $key (@session_keys) {
        if(exists($saved_session{$key})) {
            $session->{$key} = $saved_session{$key};
        }
        else {
            delete $session->{$key};
        }
    }
    return $allowed ? $TRUE : $FALSE;
}

=head2 execute_actions

Override the actions since there is an activation timeout for the unregdate.

=cut

after 'execute_actions' => sub {
    my ($self) = @_;

    # Don't make the user leave the portal in preregistration.
    # When waiting for the activation on the portal, the actions are only
    # executed once the link has been clicked, so the real unregdate applies.
    if(!$self->app->preregistration && !$self->source->waitForActivation) {
        # we record the unregdate to reuse it after
        pf::activation::set_unregdate($pf::activation::GUEST_ACTIVATION, $self->session->{activation_code}, $self->new_node_info->{unregdate});

        get_logger->debug("Source ".$self->source->id." has an activation timeout of ".$self->source->{email_activation_timeout});
        # Use the activation timeout to set the unregistration date
        my $timeout = normalize_time( $self->source->{email_activation_timeout} );
        my $unregdate = POSIX::strftime( "%Y-%m-%d %H:%M:%S",localtime( time + $timeout ) );
        get_logger->debug( "Registration for guest ".$self->app->session->{username}." is valid until $unregdate (delay of $timeout s)" );

        $self->new_node_info->{unregdate} = $unregdate;
    }
    return $TRUE;
};

=head2 auth_source_params_child

The parameters available for source matching

=cut

sub auth_source_params_child {
    my ($self) = @_;
    return {
        user_email => $self->app->session->{email},
    };
}

sub _build_source {
    my ($self) = @_;
    return $self->app->profile->getSourceByType('Email');
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

