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

use pf::util;
use pf::log;
use pf::config::util;
use List::MoreUtils qw(all);
use pf::auth_log;
use pf::person;
use pf::Authentication::constants qw($LOGIN_SUCCESS $LOGIN_FAILURE $LOGIN_CHALLENGE);
use pf::web::guest;

has '+pid_field' => (default => sub { "username" });

has '+sources' => (isa => 'ArrayRef['.join('|', @{sources_classes()}).']');

has '+multi_source_object_classes' => (default => sub{sources_classes()});

has 'challenge_template' => (is => 'ro', default => sub { "challenge.html" } );

has 'challenge_data' => (is => 'rw', builder => '_build_challenge_data', lazy => 1, trigger => \&_trigger_challenge_data);

sub _build_challenge_data {
    my ($self) = @_;
    return $self->app->session->{challenge_data};
}

sub _trigger_challenge_data {
    my ($self, $data, $old_data) = @_;
    $self->app->session->{challenge_data} = $data;
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
    my ($self) = @_;
    my $username = $self->request_fields->{$self->pid_field};
    my $password = $self->request_fields->{password};

    my ($stripped_username, $realm) = strip_username($username);

    my @sources = get_user_sources($self->sources, $stripped_username, $realm);
    get_logger->info("Authenticating user using sources : ", join(',', (map {$_->id} @sources)));

    unless(@sources){
        get_logger->info("No sources found for $username");
        $self->app->flash->{error} = "No authentication source found for this username";
        $self->prompt_fields();
        return;
    }

    # If all sources use the stripped username, we strip it
    # Otherwise, we leave it as is
    my $use_stripped = all { isenabled($_->{stripped_user_name}) } @sources;
    if($use_stripped){
        $username = $stripped_username;
    }

    if ($self->app->reached_retry_limit("login_retries", $self->app->profile->{'_login_attempt_limit'})) {
        $self->app->flash->{error} = $GUEST::ERRORS{$GUEST::ERROR_MAX_RETRIES};
        $self->prompt_fields();
        return;
    }

    if(isenabled($self->app->profile->reuseDot1xCredentials)) {
        my $mac       = $self->current_mac;
        my $node_info = node_view($mac);
        $username = strip_username($node_info->{'last_dot1x_username'});
        get_logger->info("Reusing 802.1x credentials. Gave username ; $username");
    } else {
        # validate login and password
        my ( $return, $message, $source_id ) =
          pf::authentication::authenticate( { 'username' => $username, 'password' => $password, 'rule_class' => $Rules::AUTH }, @sources );
        if (!defined $return || $return == $LOGIN_FAILURE) {
            pf::auth_log::record_auth(join(',',map { $_->id } @sources), $self->current_mac, $username, $pf::auth_log::FAILED);
            $self->app->flash->{error} = $message;
            $self->prompt_fields();
            return;
        }
        $self->username($username);
        $self->source(pf::authentication::getAuthenticationSource($source_id));
        if ( $return == $LOGIN_SUCCESS ) {

            if($self->source->type eq "SQL"){
                unless(pf::password::consume_login($username)){
                    $self->app->flash->{error} = "Account has used all of its available logins";
                    $self->prompt_fields();
                    return;
                }
            }

            pf::auth_log::record_auth($source_id, $self->current_mac, $username, $pf::auth_log::COMPLETED);
            # Logging USER/IP/MAC of the just-authenticated user
            get_logger->info("Successfully authenticated ".$username);
        } elsif ($return == $LOGIN_CHALLENGE) {
            $self->challenge_data($message);
            $self->display_challenge();
            return;
        }
    }

    $self->update_person_from_fields();
    $self->done();
}

sub challenge {
    my ($self) = @_;
    my $password = $self->request_fields->{password};
    my ($results, $message) = $self->source->challenge($self->username, $password, $self->challenge_data);
    if ($results == $LOGIN_FAILURE) {
        $self->app->flash->{error} = $message;
        $self->display_challenge();
        return;
    }
    if ($results == $LOGIN_CHALLENGE) {
        $self->challenge_data($message);
        $self->display_challenge();
        return;
    }
    $self->challenge_data(undef);
    $self->done();

}

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

sub allowed_urls_auth_module { ['/challenge'] }

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
