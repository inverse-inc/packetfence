package captiveportal::PacketFence::DynamicRouting::Module::Authentication::Email;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication::Email

=head1 DESCRIPTION

Login registration

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module::Authentication';
with 'captiveportal::Role::FieldValidation';

has '+source' => (isa => 'pf::Authentication::Source::EmailSource');

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

=head2 execute_child

Execute this module

=cut

sub execute_child {
    my ($self) = @_;
    if($self->app->request->method eq "POST"){
        $self->do_email_registration();
    }
    else{
        $self->prompt_fields();
    }
};

sub required_fields_child {['email_instructions']}

=head2 do_email_registration

Perform the e-mail registration using the provided info

=cut

sub do_email_registration {
    my ($self) = @_;
    my $logger = get_logger;

    # fetch role for this user
    my $source = $self->source;
    my $pid = $self->request_fields->{$self->pid_field};
    my $email = $self->request_fields->{email};

    my ( $status, $status_msg ) = $source->authenticate($pid);
    unless ( $status ) {
        $self->app->flash->{error} = $status_msg;
        $self->prompt_fields();
        return;
    }

    my %info;
    $info{'activation_domain'} = $source->{activation_domain} if (defined($source->{activation_domain}));
    $info{'activation_timeout'} = normalize_time($source->{email_activation_timeout});

    # form valid, adding person (using modify in case person already exists)
    my $note = 'email activation. Date of arrival: ' . time2str("%Y-%m-%d %H:%M:%S", time);
    $self->update_person_from_fields(notes => $note);

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

    pf::auth_log::record_guest_attempt($source->id, $self->current_mac, $pid, $self->app->profile->name);
    #CUSTOM: remove me once the auth_log is properly closed on email activation
    pf::auth_log::record_completed_guest($source->id, $self->current_mac, $pf::auth_log::COMPLETED, $self->app->profile->name);

    if($self->app->preregistration) {
        # Mark the registration as completed as the email doesn't have to be validated
        pf::auth_log::record_completed_guest($source->id, $self->current_mac, $pf::auth_log::COMPLETED, $self->app->profile->name);
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

    # Don't make the user leave the portal in preregistration
    if(!$self->app->preregistration) {
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

