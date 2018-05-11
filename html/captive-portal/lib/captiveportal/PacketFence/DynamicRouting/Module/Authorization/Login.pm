package captiveportal::PacketFence::DynamicRouting::Module::Authorization::Login;

=head1 NAME

captiveportal::DynamicRouting::Module::Authorization::Login

=head1 DESCRIPTION

Login registration

=cut

use Moose;
#extends 'captiveportal::PacketFence::DynamicRouting::Module::Authorization';
#extends 'captiveportal::DynamicRouting::Module::Authentication';
extends 'captiveportal::DynamicRouting::Module::Authorization';
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

has '+pid_field' => (default => sub { "username" });

has '+sources' => (isa => 'ArrayRef['.join('|', @{sources_classes()}).']');

has '+multi_source_object_classes' => (default => sub{sources_classes()});

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
    return ["username"];
}

=head2 execute_child

Execute this module

=cut

sub execute_child {
    my ($self) = @_;
    if($self->app->request->method eq "POST"){
        $self->authorize();
    }
    elsif (defined($self->username) && $self->username eq 'default') {
        $self->prompt_fields();
    } else {
        $self->authorize();
    }
};

=head2 authorize

Authorize the POSTed username

=cut

sub authorize {
    my ($self) = @_;
    my $username = $self->request_fields->{$self->pid_field} || $self->username;

    my ($stripped_username, $realm) = strip_username($username);

    my $sources = filter_authentication_sources($self->sources, $stripped_username, $realm);
    get_logger->info("Authenticating user using sources : ", join(',', (map {$_->id} @{$sources})));

    unless(@{$sources}){
        get_logger->info("No sources found for $username");
        $self->app->flash->{error} = "No authentication source found for this username";
        $self->prompt_fields();
        return;
    }

    # If all sources use the stripped username, we strip it
    # Otherwise, we leave it as is
    my $use_stripped = all { isenabled($_->{stripped_user_name}) } @{$sources};
    if($use_stripped){
        $username = $stripped_username;
    }

    if ($self->app->reached_retry_limit("login_retries", $self->app->profile->{'_login_attempt_limit'})) {
        $self->app->flash->{error} = $GUEST::ERRORS{$GUEST::ERROR_MAX_RETRIES};
        $self->prompt_fields();
        return;
    }

    my $mac       = $self->current_mac;
    my $node_info = node_view($mac);
    $realm = lc($pf::constants::realm::NULL) unless(defined($realm));
    get_logger->info("Authorize with username '$username' and realm '$realm'");

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
        username => $username,
        connection_type => $node_info->{'last_connection_type'},
        SSID => $node_info->{'last_ssid'},
        stripped_user_name => $username,
        rule_class => 'authentication',
        realm => $node_info->{'realm'},
    };
    my $source_id;
    my $role = pf::authentication::match([@{$source}], $params, $Actions::SET_ROLE, \$source_id);

    if ( defined($role) ) {
        $self->username($username);
        $self->source(pf::authentication::getAuthenticationSource($source_id));
        while(my ($action, $params) = each %{$self->actions}){
            if ($action eq 'custom') {
                my @action = split('=',@{$params}[0]);
                if ($role eq $action[0]) {
                    $self->app->session->{'sub_root_module_id'} = $action[1];
                    $self->redirect_root();
                    return;
                }
            }
            if ($action eq 'on_success') {
                 $self->app->session->{'sub_root_module_id'} = @{$params}[0];
                 $self->redirect_root();
                 return;
            }
        }
        $self->done();
    }
    else {
        pf::auth_log::record_auth(join(',',map { $_->id } @{$sources}), $self->current_mac, $username, $pf::auth_log::FAILED);
        while(my ($action, $params) = each %{$self->actions}){
            if ($action eq 'on_failure') {
                 $self->app->session->{'sub_root_module_id'} = @{$params}[0];
                 $self->redirect_root();
                 return;
            }
        }
        $self->prompt_fields();
        return;
    }
}

=head2 clean_username

=cut

sub clean_username {
    my ($self, $username) = @_;
    return $username;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
