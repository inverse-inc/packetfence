package Catalyst::Plugin::Session::State::MAC;
use Moose;
use namespace::autoclean;
use pf::util;

extends 'Catalyst::Plugin::Session::State::Cookie';

our $VERSION = "0.01";

around 'get_session_id' => sub {
    my $orig = shift;
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

around 'update_session_cookie' => sub {
    my ( $orig, $c, $updated ) = @_;

    unless ( $c->cookie_is_rejecting( $updated ) ) {
        my $cookie_name = $c->_session_plugin_config->{cookie_name};
        # We create the cookie using the browser_session_id which will contain a previously created session ID
        $c->response->cookies->{$cookie_name} = $c->make_session_cookie($c->browser_session_id());
    }
};

1;
