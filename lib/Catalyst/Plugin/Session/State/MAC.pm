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
        $c->request->cookie('CGISESSION')->value();
    }
    elsif($c->stash->{browser_session_id}) {
        return $c->stash->{browser_session_id};
    }
    else {
        $c->stash->{browser_session_id} = $c->generate_session_id(); 
        return $c->stash->{browser_session_id};
    }
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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
