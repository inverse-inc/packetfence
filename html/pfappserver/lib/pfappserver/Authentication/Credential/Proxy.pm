package pfappserver::Authentication::Credential::Proxy;

=head1 NAME

pfappserver::Authentication::Credential::Proxy -

=cut

=head1 DESCRIPTION

pfappserver::Authentication::Credential::Proxy

=cut

use strict;
use warnings;
use Moose;
use namespace::autoclean;
use pfappserver::Authentication::Store::PacketFence::User;
use pf::authentication;
use List::Util qw(first);
use pf::constants::realm;

has realm => (is => 'rw');
has _config => (is => 'rw');

=head2 BUILDARGS

=cut

sub BUILDARGS {
    my ($class, $config, $app, $realm) = @_;

    return { _config => $config, realm => $realm};
}

=head2 authenticate

authenticate using an admin proxy

=cut

sub authenticate {
    my ($self, $c, $realm, $authinfo) = @_;

    #Find the first AdminProxy if none reject
    my @sources = grep { $_->{type} eq 'AdminProxy' } @{getAllAuthenticationSources()};
    return unless @sources;
    my $request = $c->req;
    my $address = $request->address;
    my $headers = $request->headers;
    #Use the address headers as the username and password refactor this to just pass a hash instead authenticate({},@sources)
    my ($result, $message, $source_id, $extra) = &pf::authentication::authenticate({username => $address, password => $headers, 'rule_class' => $Rules::ADMIN}, @sources);
    unless ($result) {
        $c->log->debug(sub { "Unable to authenticate in realm " . $realm->name . " Error $message" });
        return;
    }
    my $source = getAuthenticationSource($source_id);
    my $username = $source->getUserFromHeader($headers);
    unless (defined $username) {
        $c->log->error("Cannot extract the user name from the headers for source $source_id");
        return;
    }
    my $group = $source->getGroupFromHeader($headers);
    my $value = &pf::authentication::match($source_id, {username => $username, group_header => $group, 'rule_class' => $Rules::ADMIN, 'context' => $pf::constants::realm::ADMIN_CONTEXT}, $Actions::SET_ACCESS_LEVEL, undef, $extra);
    # No roles found cannot login
    return unless $value;
    my $roles = [split /\s*,\s*/,$value] if defined $value;
    $c->session->{user_roles} = $roles;
    my $user = $realm->find_user( { username => $username }, $c  );
    return $user;
}

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

