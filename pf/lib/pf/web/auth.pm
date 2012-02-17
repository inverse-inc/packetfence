package pf::web::auth;

=head1 NAME

pf::web::auth

=head1 SYNOPSIS

Two responsabilities:

=over

=item Object interface for captive portal authentication modules

=item Class methods act as a singleton holding utilities for authentication modules

=back

=head1 CONFIGURATION AND ENVIRONMENT

Subclasses controlled by site administrator at F<conf/authentication/>.

=head1 BUGS AND LIMITATIONS

=cut

use strict;
use warnings;

use Log::Log4perl;
use Try::Tiny;

use pf::config;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(list_enabled_auth_types instantiate initialize);
}

our $initialized = $FALSE;
our $pretty_names_ref_cache;

=head1 CLASS METHODS

=over

=item initialize

Initializes the web::auth subsystem. 
We import all enabled authentication modules. 
Doing this only once gives us appreciable performance gains.

=cut
sub initialize {
    my $logger = Log::Log4perl::get_logger("pf::web::auth");

    my @auth_types = split( /\s*,\s*/, $Config{'registration'}{'auth'} );
    foreach my $auth_type (@auth_types) {
        try {
            # try to import module and re-throw the error to catch if there's one
            eval "use authentication::$auth_type $AUTHENTICATION_API_LEVEL";
            die($@) if ($@);

        } catch {
            $logger->error("Initialization of authentication module authentication::$auth_type failed: $_");
        };
    }

    $initialized = $TRUE;
}

=item list_enabled_auth_types

Returns an hashref { auth name => pretty name } for all enabled modules.
Will cache the returned list for faster subsequent retrieval.

=cut
sub list_enabled_auth_types {
    initialize() if (!$initialized);

    # cache hit
    return $pretty_names_ref_cache if (defined($pretty_names_ref_cache));

    my @auth_types = split( /\s*,\s*/, $Config{'registration'}{'auth'} );
    
    my $pretty_names_ref = {};
    foreach my $auth_type (@auth_types) {
        my $auth = instantiate($auth_type);
        next if (!defined($auth));
        $pretty_names_ref->{$auth_type} = $auth->getName();
    }

    # Cache
    $pretty_names_ref_cache = $pretty_names_ref;

    return $pretty_names_ref;
}

=item instantiate

Returns the proper authentication::.. object requested. 

=cut
sub instantiate {
    my ($auth_type) = @_;
    my $logger = Log::Log4perl::get_logger("pf::web::auth");
    $logger->trace("authentication module $auth_type requested");

    initialize() if (!$initialized);

    # create the object
    my $auth_obj;
    try {
        $auth_obj = "authentication::$auth_type"->new();
    } catch {
        $logger->error("Creation of authentication module authentication::$auth_type failed: $_");
    };

    return $auth_obj if (defined($auth_obj));
    # return undef on failure
    return;
}

=back

=head1 OBJECT METHODS

=over

=item new

get a new instance of the pf::web::auth object
 
=cut
sub new {
    my $logger = Log::Log4perl::get_logger("pf::web::auth");
    $logger->debug("instantiating new pf::web::auth object");
    my ( $class, %argv ) = @_;
    my $this = bless {}, $class;
    $this->init();
    return $this;
}

=item init

Initializes the object.

This default implementation sets the name attribute with the "our $name" as configured inside the package of the object.

Uses some perl wizardry to reduce the boilerplate to a minimum for the users to configure the authautenication modules.

=cut
sub init {
    my ($this) = @_;

    {
        no strict 'refs';
        my $module = ref($this);
        # read: set name to $authentication::local::name if it's defined
        $this->{'name'} = ${"${module}::name"} if (defined(${"${module}::name"}));
    }
}

=item _setLastError

Stores last error encountered by authentication module.
Errors are meant to be presented to the user. 
They should be cleaned out of any information that could help an attacker.
Use logging to store errors that should help troubleshooting.

=cut
sub _setLastError {
    my ($this, $error_string) = @_;
    $this->{_lastError} = $error_string;
}

=item getLastError

Fetches the last error encountered by authentication. 
Errors to be presented to the user.
Troubleshooting-type errors are logged.

=cut
sub getLastError {
    my ($this) = @_;
    return $this->{_lastError} if (defined($this->{_lastError}));
}

=item authenticate( $login, $password )

True if successful, false otherwise. If unsuccessful error is available in getLastError().

=cut
sub authenticate {
    my $logger = Log::Log4perl::get_logger("pf::web::auth");
    $logger->warn("authentication module misconfiguration: authenticate not implemented");
    return $FALSE;
}

=item getName

Pretty name of the authentication module. 
Displayed on the portal if a choice is given to the users.

This default implementation returns the name as initialized in init().
If $name is not definied inside that package the package name is returned.

=cut
sub getName {
    my ($this) = @_;

    return $this->{name} if (defined($this->{name}));

    # return blessed object's package name otherwise
    return ref($this);
}

=item getNodeAttributes

Authentication module can provide additional node information to the captive portal.
Returns a 'node info' style hash. See L<pf::node>'s node_view.

For example, LDAP can return a group that can be used to set a category.

    return ( category => $ldap_category );

Default implementation returns an empty list. Meant to be overridden.

=cut
sub getNodeAttributes {
    return ();
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set tabstop=4:
# vim: set backspace=indent,eol,start:
