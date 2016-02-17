package pf::Authentication::Source::GoogleSource;

=head1 NAME

pf::Authentication::Source::GoogleSource

=head1 DESCRIPTION

=cut

use pf::person;
use Moose;
extends 'pf::Authentication::Source::OAuthSource';

has '+type' => (default => 'Google');
has '+class' => (default => 'external');
has '+unique' => (default => 1);
has '+dynamic_routing_module' => (default => 'AuthModule::OAuth::Google');
has 'client_id' => (isa => 'Str', is => 'rw', required => 1, default => 'YOUR_API_ID.apps.googleusercontent.com');
has 'client_secret' => (isa => 'Str', is => 'rw', required => 1);
has 'site' => (isa => 'Str', is => 'rw', default => 'https://accounts.google.com');
has 'authorize_path' => (isa => 'Str', is => 'rw', default => '/o/oauth2/auth');
has 'access_token_path' => (isa => 'Str', is => 'rw', default => '/o/oauth2/token');
has 'access_token_param' => (isa => 'Str', is => 'rw', default => 'oauth_token');
has 'scope' => (isa => 'Str', is => 'rw', default => 'https://www.googleapis.com/auth/userinfo.email');
has 'protected_resource_url' => (isa => 'Str', is => 'rw', default => 'https://www.googleapis.com/oauth2/v2/userinfo');
has 'redirect_url' => (isa => 'Str', is => 'rw', required => 1, default => 'https://<hostname>/oauth2/google');
has 'domains' => (isa => 'Str', is => 'rw', required => 1, default => '*.google.com,*.gstatic.com,googleapis.com,accounts.youtube.com');
has 'create_local_account' => (isa => 'Str', is => 'rw', default => 'no');

=head2 lookup_from_provider_info

Lookup the person information from the authentication hash received during the OAuth process

=cut

sub lookup_from_provider_info {
    my ( $self, $pid, $info ) = @_;
    person_modify( $pid, firstname => $info->{given_name}, lastname => $info->{family_name}, email => $info->{email} );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

__PACKAGE__->meta->make_immutable;
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
