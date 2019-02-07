package pf::Authentication::Source::LinkedInSource;

=head1 NAME

pf::Authentication::Source::LinkedInSource

=head1 DESCRIPTION

=cut

use WWW::Curl::Easy;
use JSON::MaybeXS qw( decode_json );
use Moose;
use pf::person;
extends 'pf::Authentication::Source::OAuthSource';
with 'pf::Authentication::CreateLocalAccountRole';

has '+type' => (default => 'LinkedIn');
has '+class' => (default => 'external');
has 'client_id' => (isa => 'Str', is => 'rw', required => 1);
has 'client_secret' => (isa => 'Str', is => 'rw', required => 1);
has 'site' => (isa => 'Str', is => 'rw', default => 'https://www.linkedin.com');
has 'authorize_path' => (isa => 'Str', is => 'rw', default => '/oauth/v2/authorization');
has 'access_token_path' => (isa => 'Str', is => 'rw', default => '/oauth/v2/accessToken');
has 'access_token_param' => (isa => 'Str', is => 'rw', default => 'code');
has 'protected_resource_url' => (isa => 'Str', is => 'rw', default => 'https://api.linkedin.com/v1/people/~/email-address');
has 'redirect_url' => (isa => 'Str', is => 'rw', required => 1, default => 'https://<hostname>/oauth2/callback');
has 'domains' => (isa => 'Str', is => 'rw', required => 1, default => 'www.linkedin.com,api.linkedin.com,*.licdn.com,platform.linkedin.com');

=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::OAuth::LinkedIn' }

=head2 lookup_from_provider_info

Lookup the person information from the authentication hash received during the OAuth process

=cut

sub lookup_from_provider_info {
    my ( $self, $pid, $info ) = @_;
    person_modify( $pid, email => $info->{email} );
}

=head2 additional_client_attributes

Supply a state variable for the client

=cut

sub additional_client_attributes {
    my ($self) = @_;
    return (state => $self->id);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
