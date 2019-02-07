package captiveportal::PacketFence::DynamicRouting::Module::Authentication;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication

=head1 DESCRIPTION

Base authentication module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module';

use Tie::IxHash;
use List::MoreUtils qw(uniq);
use pf::constants qw($FALSE $TRUE);
use pf::config qw(%Config);
use pf::person;
use pf::util;
use pf::log;
use captiveportal::Form::Authentication;
use pf::locationlog;
use captiveportal::Base::Actions;
use pf::constants::realm;

has 'source' => (is => 'rw', isa => 'pf::Authentication::Source|Undef');

has 'source_id' => (is => 'rw', trigger => \&_build_source);

has 'required_fields' => (is => 'rw', isa => 'ArrayRef[Str]', builder => '_build_required_fields', lazy => 1);

has 'custom_fields' => (is => 'rw', isa => 'ArrayRef[Str]', default => sub {[]});

has 'request_fields' => (is => 'rw', traits => ['Hash'], builder => '_build_request_fields', lazy => 1);

has 'pid_field' => ('is' => 'rw', default => sub {'email'});

has 'with_aup' => ('is' => 'rw', default => sub {1});

has 'aup_template' => (is => 'rw', default => sub {'aup_text.html'});

has '+actions' => (default => sub {{"on_success" => [], "on_failure" => [], "destination_url" => [], "role_from_source" => [], "unregdate_from_source" => [], "time_balance_from_source" => [], "bandwidth_balance_from_source" => []}});

has 'signup_template' => ('is' => 'rw', default => sub {'signin.html'});

has 'fields_to_save'  => (is => 'rw', isa => 'ArrayRef[Str]', default => sub {[]});

use pf::authentication;
use pf::Authentication::constants qw($LOCAL_ACCOUNT_UNLIMITED_LOGINS);
use captiveportal::Base::Actions;

=head2 available_actions

Lists the actions that can be applied to this module

=cut

sub available_actions {
    my ($self) = @_;
    return [
        @{$self->SUPER::available_actions()},
        'unregdate_from_source',
        'role_from_source',
        'time_balance_from_source',
        'bandwidth_balance_from_source',
        'on_failure',
        'on_success',
    ];
}

=head2 allowed_urls

The URLs that are allowed

=cut

sub allowed_urls {
    my ($self) = @_;
    return [
        '/signup',
        @{$self->allowed_urls_auth_module()},
    ];
}

=head2 allowed_urls_auth_module

The URLs that are allowed in the subclasses. Meant to be overriden

=cut

sub allowed_urls_auth_module {[]}

=head2 form

The form for this module

=cut

sub form {
    my ($self) = @_;
    my $params = defined($self->app->request->parameters()) ? $self->app->request->parameters() : {};
    my $i18n = captiveportal::Base::I18N->new;
    my $form = captiveportal::Form::Authentication->new(language_handle => $i18n, app => $self->app, module => $self);
    $form->process(params => $params);
    return $form;
}

=head2 _build_request_fields

Builder for the request fields

=cut

sub _build_request_fields {
    my ($self) = @_;
    my $fields = [keys(%{$self->app->hashed_params()->{fields}})];
    my %request_fields;
    foreach my $field (@$fields) {
        # grab the value from the form to apply any transformations that are done in it.
        $request_fields{$field} = $self->form->field("fields[$field]")->value;
    }
    return \%request_fields;
}

=head2 _build_source

Builder for the source using the source_id attribute

=cut

sub _build_source {
    my ($self) = @_;
    $self->source(pf::authentication::getAuthenticationSource($self->{source_id}));
}

=head2 execute_actions

Actions to execute once the module has completed
Will assign a role and unregdate in the new_node_info
Will also create the local account if necessary

=cut

sub execute_actions {
    my ($self) = @_;

    $self->SUPER::execute_actions();

    unless(defined($self->new_node_info->{category}) && ( defined($self->new_node_info->{time_balance}) || defined($self->new_node_info->{bandwidth_balance}) || defined($self->new_node_info->{unregdate}))){
        $self->app->flash->{error} = "You do not have permission to register a device with this username";

        # Make sure the current source is not remembered since it failed...
        $self->session->{source_id} = undef;

        return $FALSE;
    }

    $self->app->session->{source} = $self->source;
    if(isenabled($self->source->{create_local_account})){
        $self->create_local_account();
    }

    get_logger->debug(sub { use Data::Dumper; "new_node_info after auth module actions : ".Dumper($self->new_node_info) });
    return $TRUE;
}

=head2 _build_required_fields

Build the required fields based on the PID field, the custom fields and the mandatory fields of the source

=cut

sub _build_required_fields {
    my ($self) = @_;
    my @fields;
    push @fields, 'aup' if($self->with_aup);
    push @fields, $self->pid_field if(defined($self->pid_field));
    push @fields, 'email' if(defined($self->source) && isenabled($self->source->{create_local_account}));
    push @fields, (defined($self->source) ? $self->source->mandatoryFields() : (), @{$self->required_fields_child}, @{$self->custom_fields});

    @fields = uniq(@fields);

    # Remove 'username' and 'password' fields from required fields if 'reuseDot1x' feature is enabled
    if ( isenabled($self->app->profile->reuseDot1xCredentials) ) {
        @fields = grep { $_ ne "username" } @fields;
        @fields = grep { $_ ne "password" } @fields;
    }

    foreach my $key (keys %{$self->app->session->{saved_fields}}) {
        @fields = grep { $_ ne $key } @fields;
    }

    return [@fields];
}

=head2 required_fields_child

Required fields by the child authentication module. Meant to be overriden

=cut

sub required_fields_child {[]}

=head2 required_fields_child

Merge the required fields with the values provided in the request

=cut

sub merged_fields {
    my ($self) = @_;
    tie my %merged, 'Tie::IxHash';
    foreach my $field (@{$self->required_fields}){
        $merged{$field} = $self->request_fields->{$field};
    }
    return \%merged;
}

=head2 transfer_saving_fields

Transfer $self->app->session->{saving_fields} in $self->app->session->{saved_fields}

=cut

sub transfer_saving_fields {
    my ($self) = @_;

    foreach my $key (keys %{$self->app->session->{saving_fields}}) {
        if (grep { $_ eq $key } @{$self->fields_to_save}) {
            $self->app->session->{saved_fields}->{$key} = $self->app->session->{saving_fields}->{$key};
        }
    }
    delete $self->app->session->{saving_fields};
}

=head2 auth_source_params

The params for the authentication source

=cut

sub auth_source_params {
    my ($self) = @_;
    my $locationlog_entry = locationlog_view_open_mac($self->current_mac);
    return {
        username => $self->username(),
        mac => $self->current_mac,
        connection_type => $locationlog_entry->{'connection_type'},
        SSID => $locationlog_entry->{'ssid'},
        realm => $locationlog_entry->{'realm'},
        context => $pf::constants::realm::PORTAL_CONTEXT,
        %{$self->auth_source_params_child()},
    }
}

=head2 auth_source_params_child

Meant for child modules to define their params

=cut

sub auth_source_params_child { {} }

=head2 create_local_account

Create a local account using the email in the session

=cut

sub create_local_account {
    my ( $self, %options ) = @_;

    my $password = $options{password};
    my $actions = $options{actions};

    my $auth_params = $self->auth_source_params();

    my $email = $self->session->{fields}->{email} // $self->session->{email} // $self->app->session->{email};
    unless($email){
        get_logger->error("Can't create account since there is no user e-mail in the session.");
        return;
    }

    get_logger->debug("External source local account creation is enabled for this source. We proceed");

    # We create a "password" (also known as a user account) using the pid
    # with different parameters coming from the authentication source (ie.: expiration date)
    $actions = $actions // pf::authentication::match( $self->source->id, $auth_params, undef, $self->session->{extra} );

    my $login_amount = ($self->source->local_account_logins eq $LOCAL_ACCOUNT_UNLIMITED_LOGINS) ? undef : $self->source->local_account_logins;
    $password = pf::password::generate($self->app->session->{username}, $actions, $password, $login_amount, $self->source);

    # We send the guest and email with the info of the local account
    my %info = (
        'pid'       => $self->app->session->{username},
        'password'  => $password,
        'email'     => $email,
        'subject'   => $self->app->i18n_format(
            "%s: Guest account creation information", $Config{'general'}{'domain'}
        ),
    );
    $self->app->session->{local_account_info} = {
        local_user => pf::password::view($info{pid}),
        actions => $actions,
        pid => $info{pid},
        email => $info{email},
        password => $password,
    };
    pf::web::guest::send_template_email(
            $pf::web::guest::TEMPLATE_EMAIL_LOCAL_ACCOUNT_CREATION, $info{'subject'}, \%info
    );

    get_logger->info("Local account for external source " . $self->source->id . " created with PID " . $self->app->session->{username});
}

=head2 prompt_fields

Prompt for the necessary fields

=cut

sub prompt_fields {
    my ($self, $args) = @_;
    $args //= {};
    my %saved_fields = %{$self->app->session->{saved_fields}} if (defined ($self->app->session->{saved_fields}) );

    if($self->with_aup && scalar(@{$self->required_fields}) == 1) {
        get_logger->debug("Only AUP is required, will not prompt for any fields");
        $args->{aup_only} = $TRUE;
    }

    $self->render($self->signup_template, {
        previous_request => $self->app->request->parameters(),
        fields => $self->merged_fields,
        form => $self->form,
        title => defined($self->source) ? $self->source->description : $self->description,
        %{$args},
        %saved_fields,
    });
}

=head2 update_person_from_fields

Update the person using the fields that have been collected

=cut

sub update_person_from_fields {
    my ($self, %options) = @_;
    $options{additionnal_fields} //= {};
    my $lang = clean_locale($self->app->session->{locale});
    
    # we assume we use 'username' field as the PID when using 'reuseDot1x' feature
    if ( isenabled($self->app->profile->reuseDot1xCredentials) ) {
        $options{pid} //= $self->username;
    }
    elsif (ref($self) eq 'captiveportal::DynamicRouting::Module::Authentication::Password') {
        $options{pid} //= $self->username;
    } else {
        $options{pid} //= $self->request_fields->{$self->pid_field} // $self->username;
    }

    # not sure we should set the portal + source here...
    person_modify($options{pid}, %{ $self->request_fields }, portal => $self->app->profile->getName, source => $self->source->id, lang => $lang, %{$options{additionnal_fields}});
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

