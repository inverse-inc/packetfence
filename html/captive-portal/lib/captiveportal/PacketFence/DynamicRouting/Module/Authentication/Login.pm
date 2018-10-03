package captiveportal::PacketFence::DynamicRouting::Module::Authentication::Login;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication::Login

=head1 DESCRIPTION

Login registration

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module::Authentication';
with 'captiveportal::Role::FieldValidation';
with 'captiveportal::Role::MultiSource';

use pf::constants::realm;
use pf::util;
use pf::log;
use pf::config::util;
use List::MoreUtils qw(all);
use pf::auth_log;
use pf::person;
use pf::Authentication::constants qw($LOGIN_SUCCESS $LOGIN_FAILURE $LOGIN_CHALLENGE);
use pf::web::guest;
use pf::node qw(node_view);
use pf::lookup::person;
use pf::constants::realm;

has '+pid_field' => (default => sub { "username" });

has '+sources' => (isa => 'ArrayRef['.join('|', @{sources_classes()}).']');

has '+multi_source_object_classes' => (default => sub{sources_classes()});

has 'challenge_template' => (is => 'ro', default => sub { "challenge.html" } );

has 'challenge_data' => (is => 'rw', builder => '_build_challenge_data', lazy => 1, trigger => \&_trigger_challenge_data);

=head2 _build_challenge_data

Get the challenge data from the session cache

=cut

sub _build_challenge_data {
    my ($self) = @_;
    return $self->session->{challenge_data};
}

=head2 _trigger_challenge_data

Set the challenge data in the session cache

=cut

sub _trigger_challenge_data {
    my ($self, $data, $old_data) = @_;
    $self->session->{challenge_data} = $data;
}

sub sources_classes {
    return [
        "pf::Authentication::Source::SQLSource",
        "pf::Authentication::Source::LDAPSource",
        "pf::Authentication::Source::HtpasswdSource",
        "pf::Authentication::Source::KerberosSource",
        "pf::Authentication::Source::EAPTLSSource",
        "pf::Authentication::Source::HTTPSource",
        "pf::Authentication::Source::RADIUSSource",
        "pf::Authentication::Source::PotdSource",
    ];
}

=head2 required_fields_child

Username and password are required for login

=cut

sub required_fields_child {
    return ["username", "password"];
}

=head2 execute_child

Execute this module

=cut

sub execute_child {
    my ($self) = @_;
    if($self->app->request->method eq "POST"){
        if($self->app->request->path eq "challenge") {
            if( defined $self->challenge_data){
                $self->challenge();
            }
            else {
                $self->prompt_fields();
            }
        } else {
            $self->authenticate();
        }
    }
    else {
        if( defined $self->challenge_data){
            $self->display_challenge();
        }
        else {
            $self->prompt_fields();
        }
    }
};

=head2 authenticate

Authenticate the POSTed username and password

=cut

sub authenticate {
    my ($self, $user) = @_;
    my $username = $user || $self->request_fields->{$self->pid_field};
    my $password = $self->request_fields->{password};

    my ($stripped_username, $realm) = strip_username($username);

    my $sources = filter_authentication_sources($self->sources, $stripped_username, $realm);
    get_logger->info("Authenticating user using sources : ", join(',', (map {$_->id} @{$sources})));

    unless(@{$sources}){
        get_logger->info("No sources found for $username");
        $self->app->flash->{error} = "No authentication source found for this username";
        $self->prompt_fields();
        return;
    }

    if ($self->app->reached_retry_limit("login_retries", $self->app->profile->{'_login_attempt_limit'})) {
        $self->app->flash->{error} = $GUEST::ERRORS{$GUEST::ERROR_MAX_RETRIES};
        $self->prompt_fields();
        return;
    }

    if ( isenabled($self->app->profile->reuseDot1xCredentials) ) {
        my $mac       = $self->current_mac;
        my $node_info = node_view($mac);
        ($username,$realm) = strip_username($node_info->{'last_dot1x_username'});
        $realm = lc($pf::constants::realm::NULL) unless(defined($realm));
        get_logger->info("Reusing 802.1x credentials with username '$username' and realm '$realm'");

        # Fetch appropriate source to use with 'reuseDot1xCredentials' feature
        my $source = pf::config::util::get_realm_authentication_source($username, $realm, \@{$sources});
        
        # No source found for specified realm
        unless ( ref($source) eq 'ARRAY' ) {
            get_logger->error("Unable to find an authentication source for the specified realm '$realm' while using reuseDot1xCredentials");
            $self->app->flash->{error} = "Cannot find a valid authentication source for '" . $node_info->{'last_dot1x_username'} . "'";

            $self->prompt_fields();
            return;
        }

        # Trying to match credentials with the source
        my $params = {
            username => $node_info->{'last_dot1x_username'},
            connection_type => $node_info->{'last_connection_type'},
            SSID => $node_info->{'last_ssid'},
            stripped_user_name => $username,
            rule_class => 'authentication',
            realm => $node_info->{'realm'},
            context => $pf::constants::realm::PORTAL_CONTEXT,
        };
        my $source_id;
        my $role = pf::authentication::match([@{$source}], $params, $Actions::SET_ROLE, \$source_id);

        if ( defined($role) ) {
            $self->source(pf::authentication::getAuthenticationSource($source_id));
            $self->username($username);
            $self->transfer_saving_fields();
        }
        else {
            get_logger->error("Unable to find a match in the '$realm' realm authentication source for credentials '" . $node_info->{'last_dot1x_username'} . "' while using reuseDot1xCredentials");
            $self->app->flash->{error} = "Cannot find a valid authentication source for '" . $node_info->{'last_dot1x_username'} . "'";

            $self->prompt_fields();
            return;
        }

    }

    else {
        $username = $self->clean_username($username);

        # validate login and password
        my ( $return, $message, $source_id, $extra ) =
          pf::authentication::authenticate( { 
                  'username' => $username, 
                  'password' => $password, 
                  'rule_class' => $Rules::AUTH,
                  'context' => $pf::constants::realm::PORTAL_CONTEXT,
              }, @{$sources} );
        if (!defined $return || $return == $LOGIN_FAILURE) {
            pf::auth_log::record_auth(join(',',map { $_->id } @{$sources}), $self->current_mac, $username, $pf::auth_log::FAILED, $self->app->profile->name);
            $self->on_action('on_failure');
            $self->app->flash->{error} = $message;
            $self->prompt_fields();
            return;

        }
        $self->session->{extra} = $extra if defined($extra);
        $self->username($username);
        $self->source(pf::authentication::getAuthenticationSource($source_id));
        if ( $return == $LOGIN_SUCCESS ) {
            $self->transfer_saving_fields();
            if($self->source->type eq "SQL"){
                unless(pf::password::consume_login($username)){
                    $self->app->flash->{error} = "Account has used all of its available logins";
                    $self->prompt_fields();
                    return;
                }
            }

            pf::auth_log::record_auth($source_id, $self->current_mac, $username, $pf::auth_log::COMPLETED, $self->app->profile->name);
            # Logging USER/IP/MAC of the just-authenticated user
            get_logger->info("Successfully authenticated ".$username);
            $self->on_action('on_success');
        } elsif ($return == $LOGIN_CHALLENGE) {
            $self->challenge_data($message);
            $self->display_challenge();
            return;
        }
    }

    pf::lookup::person::async_lookup_person($username,$self->source->id,$pf::constants::realm::PORTAL_CONTEXT);
    $self->update_person_from_fields();
    $self->done();
}

=head2 challenge

Handle the challenge request

=cut

sub challenge {
    my ($self) = @_;
    my $password = $self->request_fields->{password};
    my ($result, $message) = $self->source->challenge($self->username, $password, $self->challenge_data);
    if ($result == $LOGIN_FAILURE) {
        $self->app->flash->{error} = $message;
        $self->display_challenge();
        return;
    }
    if ($result == $LOGIN_CHALLENGE) {
        $self->challenge_data($message);
        $self->display_challenge();
        return;
    }
    $self->challenge_data(undef);
    $self->done();

}

=head2 display_challenge

Display the challenge form

=cut

sub display_challenge {
    my ($self, $args) = @_;
    $args //= {};
    $self->render($self->challenge_template, {
        previous_request => $self->app->request->parameters(),
        fields => {password => ''},
        form => $self->form,
        title => $self->challenge_data->{message},
        %{$args},
    });
}

=head2 clean_username

=cut

sub clean_username {
    my ($self, $username) = @_;
    return $username;
}


=head2 allowed_urls_auth_module

=cut

sub allowed_urls_auth_module { ['/challenge'] }

=head2 on_action

change the root portal module if an action is define

=cut

sub on_action {
    my ($self, $action) = @_;
    if ($self->actions->{$action} && @{$self->actions->{$action}} > 0) {
        $self->app->session->{'sub_root_module_id'} = @{$self->actions->{$action}}[0];
        $self->redirect_root();
        $self->detach;
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
