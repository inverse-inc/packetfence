package pfappserver;

=head1 Name pfappserver

=cut

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
    ConfigLoader
    Static::Simple
    I18N
    Authentication
    +pfappserver::Authentication::Store::PacketFence
    Session
    Session::Store::CHI
    Session::State::Cookie
    StackTrace
/;

use Try::Tiny;

BEGIN {
    use constant INSTALL_DIR => '/usr/local/pf';
    use lib INSTALL_DIR . "/lib";
    use lib qw(/usr/local/fingerbank/lib);
    use pf::log 'service' => 'httpd.admin', reinit => 1;
}
use pf::CHI;
use pf::CHI::Request;
use pf::web::util;
use pf::SwitchFactory;
pf::SwitchFactory->preloadAllModules();

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
    default_view =>  'HTML',
    use_request_uri_for_path => 1,
    setup_components => {
        search_extra => [ qw(::Form ::F) ],
    },
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
    'Plugin::Static::Simple' => {
        mime_types => {
            woff => 'font/woff'
        },
        # Include static content from captive portal in order to render previews of
        # remediation pages (see pfappserver::Controller::Violation)
        include_path => [
            pfappserver->config->{root},
            INSTALL_DIR . '/html/pfappserver/root',
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
        cookie_secure => use_secure_cookie(),
        #chi will set the expire time
        chi_class => 'pf::CHI',
        chi_args => {
            namespace => 'httpd.admin',
        }
    },

    'View::JSON' => {
       # TODO to discuss: always add to exposed stash or use a standard 'resultset' instead?
       expose_stash    => [ qw(status status_msg error interfaces networks switches config services success items time_offset) ], # defaults to everything
    },

    'View::HTML' => {
        INCLUDE_PATH => [
            INSTALL_DIR . '/html/pfappserver/root-custom',
            INSTALL_DIR . '/html/pfappserver/root',
        ]
    },

    'View::Admin' => {
        INCLUDE_PATH => [
            INSTALL_DIR . '/html/pfappserver/root-custom',
            INSTALL_DIR . '/html/pfappserver/root',
        ]
    },

    'View::Configurator' => {
        INCLUDE_PATH => [
            INSTALL_DIR . '/html/pfappserver/root-custom',
            INSTALL_DIR . '/html/pfappserver/root',
        ]
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
         },
         configurator => {
           credential => {
             class => 'Password',
             password_type => 'none'
           },
            store => {
                class => 'Minimal',
                users => {
                    _PF_CONFIGURATOR => {
                        roles => [qw/ALL/],
                    }
                }
            }
         },
         proxy => {
           credential => {
             class => '+pfappserver::Authentication::Credential::Proxy',
           },
           store => {
             class => '+pfappserver::Authentication::Store::PacketFence',
           }
        }
       }
     },
);


=head2 use_secure_cookie

use secure cookie

=cut

sub use_secure_cookie {
    return $ENV{CATALYST_DEBUG} ? 0 : 1;
}

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

=head2 $c->form($name)

Gets a L<HTML::FormHandler> instance by name.

    $c->form('Foo')->do_stuff;

Any extra arguments are directly passed to the constructor of the Form the ctx is automatically added to the constructor

If the name is omitted, it will look for
 - a form object in $c->stash->{current_form_instance}, then
 - a form name in $c->stash->{current_form}, then
 - a config setting 'default_form', or
 - check if there is only one form, and return it if that's the case.

If you want to search for forms, pass in a regexp as the argument.

    # find all forms that start with Foo
    my @foo_forms = $c->form(qr{^Foo});

=cut

sub form {
    my ( $c, $name, @args ) = @_;
    my $appclass = ref($c) || $c;
    if( $name ) {
        unless ( ref($name) ) { # Direct component hash lookup to avoid costly regexps
            my $comps = $c->components;
            my $check = $appclass."::Form::".$name;
            return $c->_filter_component( $comps->{$check}, @args ) if exists $comps->{$check};
        }
        my @result = $c->_comp_search_prefixes( $name, qw/Form F/ );
        return map { $c->_filter_component( $_, @args ) } @result if ref $name;
        return $c->_filter_component( $result[ 0 ], @args );
    }

    if (ref $c) {
        return $c->stash->{current_form_instance}
          if $c->stash->{current_form_instance};
        return $c->form( $c->stash->{current_form} )
          if $c->stash->{current_form};
        return $c->form( $c->action->{form} )
          if $c->action->{form};
    }
    return $c->form( $appclass->config->{default_form} )
      if $appclass->config->{default_form};

    my( $comp, $rest ) = $c->_comp_search_prefixes( undef, qw/Form F/);

    if( $rest ) {
        $c->log->warn( Carp::shortmess('Calling $c->form() will return a random form unless you specify one of:') );
        $c->log->warn( '* $c->config(default_form => "the name of the default form to use")' );
        $c->log->warn( '* $c->stash->{current_form} # the name of the form to use for this request' );
        $c->log->warn( '* $c->stash->{current_form_instance} # the instance of the form to use for this request' );
        $c->log->warn( 'NB: in version 5.81, the "random" behavior will not work at all.' );
    }

    return $c->_filter_component( $comp );
}

=head2 $c->uri_for( $action, \@captures?, \@args?, \%query_values? )

Accepts an array reference for the list of arguments (\@args).

This was overridden since we did not have a way to dereference arrays in the template toolkit.

=cut

sub uri_for {
    my ($self, @args) = @_;
    my $query = pop @args if (ref($args[-1]) eq 'HASH');
    my $args_ref =  ( @args > 1 && ref($args[-1]) eq 'ARRAY' && ref($args[-2]) eq 'ARRAY') ? pop @args : [] ;
    @args = (@args, @$args_ref);
    push(@args, $query) if (defined $query);

    return $self->SUPER::uri_for(@args);
}

=head2 forms

Returns the available names which can be passed to $c->forms

=cut

sub forms {
    my ($c) = @_;
    return $c->_comp_names(qw/Form F/);
}

before handle_request => sub {
    pf::log::reset_log_context();
    pf::CHI::Request::clear_all();
};

after finalize => sub {
    my ($c) = @_;
    if(ref($c)) {
        my $deferred_actions = delete $c->stash->{_deferred_actions} || [];
        foreach my $action (@$deferred_actions) {
            eval {
                $action->();
            };
            if($@) {
                $c->log->error("Error with a deferred action: $@");
            }
        }
    }
};

sub add_deferred_actions {
    my ($c,@args) = @_;
    if(ref($c)) {
        my $deferred_actions = $c->stash->{_deferred_actions} ||= [];
        push @$deferred_actions,@args;
    }
}


sub pf_localize {
    my ($c,$msg) = @_;
    my @args;
    my $ref_type = ref($msg);
    return $msg if $ref_type eq 'HASH';
    unless ($ref_type) {
        @args = ($msg);
    } else {
        @args = @$msg;
    }
    return $c->localize(@args);
}


=head2 user_allowed_in_admin

Checks to see if the user is allowed in admin

=cut

sub user_allowed_in_admin {
    my ($c) = @_;
    return $c->user_in_realm('admin') || $c->user_in_realm('proxy') || $c->authenticate({}, 'proxy');
}

=head2 generate_doc_link

Generate the HTML link to a section of documentation

=cut

sub generate_doc_link {
    my ($c, $section, $guide) = @_;
    return pf::web::util::generate_doc_link($section, $guide);
}

=head2 generate_doc_url

Generate the URL to a section of documentation

=cut

sub generate_doc_url {
    my ($c, $section, $guide) = @_;
    return pf::web::util::generate_doc_url($section, $guide);
}

=head2 csp_server_headers

Return CSP (Content-Security-Policy) headers

=cut

sub csp_server_headers {
    my ($c) = @_;

    # Allow context-specific directive values (script-src, worker-src, img-src and style-src)
    my $headers = $c->stash->{csp_headers} || {};
    $c->response->header
      ('Content-Security-Policy' =>
       sprintf("default-src 'none'; script-src 'self'%s; connect-src 'self'; img-src 'self'%s; style-src 'self'%s; font-src 'self'; child-src 'self'; frame-src 'self'",
               $headers->{script}? ' ' . $headers->{script} : '',
               $headers->{img}   ? ' ' . $headers->{img}    : '',
               $headers->{style} ? ' ' . $headers->{style}  : ''
              )
      );
}

# Logging
__PACKAGE__->log(Log::Log4perl::Catalyst->new(INSTALL_DIR . '/conf/log.conf.d/httpd.admin.conf',watch_delay => 5 * 60));

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

1;
