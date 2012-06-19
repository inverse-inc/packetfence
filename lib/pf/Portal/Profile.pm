package pf::Portal::Profile;

=head1 NAME

pf::Portal::Profile

=cut

=head1 DESCRIPTION

pf::Portal::Profile wraps captive portal configuration in a way that we can
provide several differently configured (behavior and template) captive 
portal from the same server.

=cut
use strict;
use warnings;

use Log::Log4perl;

use pf::config;

=head1 METHODS

=over

=item new

=cut
sub new {
    my ( $class, %argv ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $logger->debug("instantiating new ". __PACKAGE__ . " object");

    my $this = bless {}, $class;

    # default values
    $this->{'_name'} = 'default';

    return $this;
}

=item getName

Returns the name of the captive portal profile.

=cut
sub getName {
    my ($self) = @_;
    return $self->{'_name'};
}

=item getLogo

Returns the logo for the current captive portal profile.

=cut
sub getLogo {
    # XXX hardcoded for now: proof of concept
    return $Config{'general'}{'logo'};
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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
