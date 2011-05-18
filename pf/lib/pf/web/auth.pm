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
use diagnostics;

use Log::Log4perl;
use Try::Tiny;

use pf::config;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(list_enabled_auth_types);
}

my %instanciated;

=head1 SUBROUTINES

=over

=cut

=item new 

get a new instance of the pf::web::auth object
 
=cut
sub new {
    my $logger = Log::Log4perl::get_logger("pf::web::auth");
    $logger->debug("instantiating new pf::web::auth object");
    my ( $class, %argv ) = @_;
    my $this = bless {}, $class;
    return $this;
}

=item list_enabled_auth_types

Returns an hashref { auth name => pretty name } for all enabled modules

=cut
sub list_enabled_auth_types {
    my @auth_types = split( /\s*,\s*/, $Config{'registration'}{'auth'} );
    
    my $pretty_names_ref = {};
    foreach my $auth_type (@auth_types) {
        my $auth = _get_or_create($auth_type);
        next if (!defined($auth));
        $pretty_names_ref->{$auth_type} = $auth->getName();
    }

    return $pretty_names_ref;
}

sub _get_or_create {
    my ($auth_type) = @_;
    my $logger = Log::Log4perl::get_logger("pf::web::auth");
    $logger->trace("authentication module requested: performing lookup or creating if not exist");

    if (defined($instanciated{$auth_type}) && ref($instanciated{$auth_type})) {
        return $instanciated{$auth_type};
    } else {
        # create the object
        my $auth_obj;
        try {
            # try to import module and re-throw the error to catch if there's one
            eval "use authentication::$auth_type $AUTHENTICATION_API_LEVEL";
            die($@) if ($@);

            $auth_obj = "authentication::$auth_type"->new();
        } catch {
            $logger->error("Authentication module authentication::$auth_type failed. $_");
        };
        if (defined($auth_obj)) {
            $instanciated{$auth_type} = $auth_obj;
            return $auth_obj;
        }
    }
    return;
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
