package pf::Portal::Session;

=head1 NAME

pf::Portal::Session

=cut

=head1 DESCRIPTION

pf::Portal::Session wraps several parameter we often need from the captive
portal.

=cut
use strict;
use warnings;

use CGI;
# TODO reconsider logging or showing generic error instead of this..
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;
use Log::Log4perl;

use pf::iplog qw(ip2mac);
use pf::Portal::ProfileFactory;
# TODO we should aim to get rid of these deps (see other TODO tasks in _initialize)
use pf::web;
# called last to allow redefinitions
use pf::web::custom;

=head1 METHODS

=over

=item new

=cut
sub new {
    my ( $class, %argv ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $logger->debug("instantiating new ". __PACKAGE__ . " object");

    my $self = bless {}, $class;
    
    $self->_initialize();
    return $self;
}

=item _initialize

=cut
# Warning: this task must be the least expensive possible since it will be
# run on every portal hit. We should profile then re-architect to store
# in session expensive components to look for.
sub _initialize {
    my ($self) = @_;

    $self->{'_cgi'} = new CGI;
    $self->{'_cgi'}->charset("UTF-8");

    $self->{'_session'} = new CGI::Session(undef, $self->getCgi, {Directory=>'/tmp'});

    # TODO inline this work here once there's no other pf::web::get_client_ip callers
    $self->{'_client_ip'} = pf::web::get_client_ip($self->getCgi);
    $self->{'_client_mac'} = ip2mac($self->getClientIp);

    # TODO inline this work here once there's no other pf::web::get_destination_url callers
    $self->{'_destination_url'} = pf::web::get_destination_url($self->getCgi);

    # XXX pass mac here
    $self->{'_profile'} = pf::Portal::ProfileFactory->instantiate();
}

=item getCgi

Returns the CGI object.

=cut
sub getCgi {
    my ($self) = @_;
    return $self->{'_cgi'};
}

=item getSession

Returns the CGI::Session object.

=cut
sub getSession {
    my ($self) = @_;
    return $self->{'_session'};
}

=item getClientIp

Returns the IP of the client behind the captive portal. We do proper header
lookups for Proxy bypass and load balancers instead of looking at local TCP
from CGI.

=cut
sub getClientIp {
    my ($self) = @_;
    return $self->{'_client_ip'};
}

=item getClientMac

Returns the MAC of the captive portal client.

=cut
sub getClientMac {
    my ($self) = @_;
    return $self->{'_client_mac'};
}

=item getDestinationUrl

Returns the original destination URL requested by the client.

=cut
# TODO we could store this in session and return from session if it exists
sub getDestinationUrl {
    my ($self) = @_;
    return $self->{'_destination_url'};
}

=item getProfile

Returns the proper captive portal profile for the current session.

=cut
sub getProfile {
    my ($self) = @_;
    return $self->{'_profile'};
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
