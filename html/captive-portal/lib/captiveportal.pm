package captiveportal;
use Moose;
use Moose::Util qw(apply_all_roles);
use namespace::autoclean;
use Log::Log4perl::Catalyst;

use Catalyst::Runtime 5.80;

# Set flags and add plugins for the application.
#
# Note that ORDERING IS IMPORTANT here as plugins are initialized in order,
# therefore you almost certainly want to keep ConfigLoader at the head of the
# list if you're using it.
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use Catalyst qw/
  ConfigLoader
  Static::Simple
  I18N
  Authentication
  Session
  Session::Store::CHI
  Session::State::Cookie
  StackTrace
  Unicode::Encoding
  /;

use Try::Tiny;


BEGIN {
    use constant INSTALL_DIR => '/usr/local/pf';
    use lib INSTALL_DIR . "/lib";
    use pf::log service => 'httpd.portal', reinit => 1;
}

use captiveportal::Role::Request;
use pf::config::cached;
use pf::file_paths;
use pf::CHI;
use CHI::Driver::SubNamespace;

extends 'Catalyst';

Catalyst::Request->meta->make_mutable;

#Apply a role for the Catalyst::Request object
apply_all_roles('Catalyst::Request','captiveportal::Role::Request');

Catalyst::Request->meta->make_immutable;

our $VERSION = '0.01';

# Configure the application.
#
# Note that settings in captive_portal.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
    name         => 'captiveportal',
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
    'static'                                    => {
        mime_types => { woff => 'font/woff' },

        # Include static content from captive portal in order to render previews of
        # remediation pages (see pfappserver::Controller::Violation)
        include_path => [
            \&loadCustomStatic,
            INSTALL_DIR . '/html/captive-portal',
            INSTALL_DIR . '/html/common',
            INSTALL_DIR . '/html',
        ],
        ignore_dirs => [
            qw(
              pfappserver templates
              t profile-templates lib script
              )
        ],
        ignore_extensions => [qw/cgi php inc tt html xml pl pm/],
    },
    'Plugin::Session'          => {
        chi_class => 'pf::CHI',
        chi_args => {
            namespace => 'httpd.portal',
        },
        cookie_name => 'CGISESSION',
    },
    default_view               => 'HTML',
);

before handle_request => sub {
    pf::config::cached::ReloadConfigs();
};

sub loadCustomStatic {
    my ($c)           = @_;
    my $dirs          = [];
    my $portalSession = $c->portalSession;
    if ($portalSession) {
        $dirs = $portalSession->templateIncludePath;
    }
    return $dirs;
}

=head2 user_cache

Returns the user/mac specific cache

=cut

sub user_cache {
    my ($c) = @_;
    return CHI->new(
        driver     => 'SubNamespace',
        chi_object => pf::CHI->new(namespace => 'httpd.portal'),
        namespace  => $c->portalSession->clientMac
    );
}

has portalSession => (
    is => 'rw',
    lazy => 1,
    builder => '_build_portalSession',
);

sub _build_portalSession {
    my ($c) = @_;
    return $c->model('Portal::Session');
}

has profile => (
    is => 'rw',
    lazy => 1,
    builder => '_build_profile',
);

sub _build_profile {
    my ($c) = @_;
    return $c->portalSession->profile;
}

after finalize => sub {
    my ($c) = @_;
    if ( ref($c) ) {
        my $deferred_actions = delete $c->stash->{_deferred_actions} || [];
        foreach my $action (@$deferred_actions) {
            eval { $action->(); };
            if ($@) {
                $c->log->error("Error with a deferred action: $@");
            }
        }
    }
};

sub add_deferred_actions {
    my ( $c, @args ) = @_;
    if ( ref($c) ) {
        my $deferred_actions = $c->stash->{_deferred_actions} ||= [];
        push @$deferred_actions, @args;
    }
}

sub has_errors {
    my ($c) = @_;
    return scalar @{$c->error};
}

__PACKAGE__->log(Log::Log4perl::Catalyst->new);

# Handle warnings from Perl as error log messages
$SIG{__WARN__} = sub { __PACKAGE__->log->error(@_); };

# Start the application
__PACKAGE__->setup();


=head1 NAME

captiveportal - Catalyst based application

=head1 SYNOPSIS

    script/captive_portal_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<captiveportal::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

1;
