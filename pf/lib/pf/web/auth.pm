package pf::web::auth;

=head1 NAME

pf::web::auth

=head1 SYNOPSIS

Interface for captive portal authentication modules

=head1 CONFIGURATION AND ENVIRONMENT

Subclasses controlled by site administrator at F<conf/authentication/>.

=head1 BUGS AND LIMITATIONS

=cut

use strict;
use warnings;
use diagnostics;

use Log::Log4perl;

use pf::config;

our $VERSION = $AUTHENTICATION_API_LEVEL;

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
