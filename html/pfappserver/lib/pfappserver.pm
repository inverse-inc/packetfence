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
    +pfappserver::Authentication::Store::PacketFence
    Authentication
    Session
    Session::Store::File
    Session::State::Cookie
    StackTrace
/;

use Try::Tiny;

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
    static => {
        mime_types => {
            woff => 'font/woff'
        },
        # Include static content from captive portal in order to render previews of
        # remediation pages (see pfappserver::Controller::Violation)
        include_path => [
            pfappserver->config->{root},
            INSTALL_DIR . '/html/captive-portal',
            INSTALL_DIR . '/html',
        ],
        ignore_dirs => [
            'captive-portal',
            'admin',
            'pfappserver',
            'templates',
            'violations',
        ],
        ignore_extensions => [ qw/cgi php inc tt html xml/ ],
    },

    'Plugin::Session' => {
        storage => '/usr/local/pf/var/session'
    },

    'View::JSON' => {
       # TODO to discuss: always add to exposed stash or use a standard 'resultset' instead?
       expose_stash    => [ qw(status status_msg error interfaces networks switches config services success) ], # defaults to everything
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
             class => '+pfappserver::Authentication::Store::PacketFence',
           }
         }
       }
     },

);

sub pf_hash_for {
    my ($self,@args) = @_;
    my $uri = $self->uri_for(@args);
    my $path = "";
    if($uri) {
        $path =$uri->path();
        $path =~ s!^/!!;
    }
    else {
        $self->log->error("Invalid args to pf_hash_for");
    }
    return "#$path";
}

# Logging
# TODO define a logging strategy that would fit both catalyst and our core
# application. For now, it's all basic and it logs to logs/packetfence.log.
__PACKAGE__->log(Log::Log4perl::Catalyst->new(INSTALL_DIR . '/conf/log.conf'));
# Handle warnings from Perl as error log messages
$SIG{__WARN__} = sub { __PACKAGE__->log->error(@_); };

# pfappserver::Model::Config::IniStyleBackend initialization
after setup_finalize => sub {
    __PACKAGE__->log->info("==== READING CONFIGURATION FILES ====");
    foreach my $module (pfappserver::Model::Config::IniStyleBackend->getConfigurationModules) {
        my $module_path = 'pfappserver::Model::Config::' . $module;
        try {
            my $module_handler = new $module_path;
            $module_handler->readConfig;
        } catch {
            chomp($_);
            __PACKAGE__->log->error("Told to load module $module but this one does not seems to exist. Passing by...");
        };
    }
    __PACKAGE__->log->info("==== FINISH READING CONFIGURATION FILES ====");
};

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
