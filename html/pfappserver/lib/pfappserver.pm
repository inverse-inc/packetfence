package pfappserver;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;
use Log::Log4perl::Catalyst;

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use Catalyst qw/
    -Debug
    ConfigLoader
    Static::Simple
    I18N

    Authentication
    Session
    Session::Store::File
    Session::State::Cookie
    StackTrace
/;

use constant INSTALL_DIR => '/usr/local/pf';
use lib INSTALL_DIR . "/lib";

extends 'Catalyst';

our $VERSION = '0.01';
$VERSION = eval $VERSION;

# Configure the application.
#
# Note that settings in pfappserver.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
    name => 'pfappserver',
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,

    'Plugin::Session' => {
        storage => '/usr/local/pf/var/session'
    },

    'View::JSON' => {
       allow_callback  => 1,    # defaults to 0
       callback_param  => 'cb', # defaults to 'callback'
       # TODO to discuss: always add to exposed stash or use a standard 'resultset' instead?
       expose_stash    => [ qw(status_msg error interfaces networks switches config services) ], # defaults to everything
    },

    'Plugin::Authentication' => {
       default_realm => 'admin',
       realms => {
         admin => {
           credential => {
             class => 'Password',
             password_field => 'password',
             password_type => 'self_check',
           },
           store => {
             class => 'Htpasswd',
             file => '/usr/local/pf/conf/admin.conf', # must exist
           }
         }
       }
     },
);

# Logging
# TODO define a logging strategy that would fit both catalyst and our core 
# application. For now, it's all basic and it logs to logs/packetfence.log.
__PACKAGE__->log(Log::Log4perl::Catalyst->new(INSTALL_DIR . '/conf/log.conf'));
# Handle warnings from Perl as error log messages
$SIG{__WARN__} = sub { __PACKAGE__->log->error(@_); };

# Start the application
__PACKAGE__->setup();

=head1 NAME

pfappserver - Catalyst based application

=head1 SYNOPSIS

    script/pfappserver_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<pfappserver::Controller::Root>, L<Catalyst>

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
