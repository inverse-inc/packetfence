package Catalyst::Plugin::Session::State::MAC;

=head1 NAME

Catalyst::Plugin::Session::State::MAC

=cut

=head1 DESCRIPTION

Overrides the cookie session state in order to keep use the MAC as the real session ID while keeping the cookie session ID as well

=cut

use Moose;
use namespace::autoclean;
use pf::util;

extends 'Catalyst::Plugin::Session::State::Cookie';

our $VERSION = "0.01";

=head2 get_session_id

Get the session ID for the session
In our case, if there is a MAC we use it
Otherwise we take the value in the session cookie
If all fails we generate a session ID

=cut

sub get_session_id {
    my $c = shift;

    my $mac = $c->portalSession->clientMac;
    if(valid_mac($mac)){
        $mac =~ s/\://g;
        return $mac;
    }
    elsif(my $cookie = $c->get_session_cookie) {
        return $cookie->value;
    }
    else {
        return $c->browser_session_id();
    }
};

=head2 update_session_cookie

Update the session cookie by making sure we put the browser_session_id in it instead of the MAC address

=cut

sub update_session_cookie {
    my ( $c, $updated ) = @_;

    unless ( $c->cookie_is_rejecting( $updated ) ) {
        my $cookie_name = $c->_session_plugin_config->{cookie_name};
        # We create the cookie using the browser_session_id which will contain a previously created session ID
        $c->response->cookies->{$cookie_name} = $c->make_session_cookie($c->browser_session_id());
    }
};

=head2 browser_session_id

Get the browser session ID (not tied to MAC address)

=cut

sub browser_session_id {
    my ($c) = @_;
    if($c->request->cookie('CGISESSION')){
        return $c->request->cookie('CGISESSION')->value();
    }
    elsif($c->stash->{browser_session_id}) {
        return $c->stash->{browser_session_id};
    }
    else {
        $c->stash->{browser_session_id} = $c->generate_session_id(); 
        return $c->stash->{browser_session_id};
    }
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

