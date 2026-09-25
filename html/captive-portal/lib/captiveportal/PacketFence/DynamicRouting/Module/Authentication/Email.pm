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
use pf::constants qw($TRUE);
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
    elsif($self->source->waitForActivation && pf::activation::activation_has_entry($self->current_mac, $pf::activation::GUEST_ACTIVATION)){
        $self->check_session_activation();
        $self->waiting_room();
    }
    elsif($self->session->{email_activated}){
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
    elsif(!pf::activation::activation_has_entry($self->current_mac, $pf::activation::GUEST_ACTIVATION)){
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
    pf::auth_log::record_completed_guest($source->id, $source->type, $self->current_mac, $pf::auth_log::COMPLETED, $self->app->profile->name);

    if($self->app->preregistration) {
        # Mark the registration as completed as the email doesn't have to be validated
        pf::auth_log::record_completed_guest($source->id, $source->type, $self->current_mac, $pf::auth_log::COMPLETED, $self->app->profile->name);
        $self->done();
    }
    else {
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
            unless($auth_return) {
                get_logger->error("Unable to send the activation email to $email, the device cannot wait for an activation that will never come");
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

