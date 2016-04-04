package Catalyst::Plugin::Session::State::MAC;
use Moose;
use namespace::autoclean;

extends 'Catalyst::Plugin::Session::State';

use MRO::Compat;
use Catalyst::Utils ();

our $VERSION = "0.17";

has _deleted_session_id => ( is => 'rw' );

sub setup_session {
    my $c = shift;

    $c->maybe::next::method(@_);

    $c->_session_plugin_config->{cookie_name}
        ||= Catalyst::Utils::appprefix($c) . '_session';
}

sub extend_session_id {
    my ( $c, $sid, $expires ) = @_;

    if ( my $cookie = $c->get_session_cookie ) {
        $c->update_session_cookie( $c->make_session_cookie( $sid ) );
    }

    $c->maybe::next::method( $sid, $expires );
}

sub set_session_id {
    my ( $c, $sid ) = @_;

    $c->update_session_cookie( $c->make_session_cookie( $sid ) );

    return $c->maybe::next::method($sid);
}

sub update_session_cookie {
    my ( $c, $updated ) = @_;

    unless ( $c->cookie_is_rejecting( $updated ) ) {
        my $cookie_name = $c->_session_plugin_config->{cookie_name};
        $c->response->cookies->{$cookie_name} = $c->make_session_cookie($c->browser_session_id());
    }
}

sub cookie_is_rejecting {
    my ( $c, $cookie ) = @_;

    if ( $cookie->{path} ) {
        return 1 if index '/'.$c->request->path, $cookie->{path};
    }

    return 0;
}

sub make_session_cookie {
    my ( $c, $sid, %attrs ) = @_;

    my $cfg    = $c->_session_plugin_config;
    my $cookie = {
        value => $sid,
        ( $cfg->{cookie_domain} ? ( domain => $cfg->{cookie_domain} ) : () ),
        ( $cfg->{cookie_path} ? ( path => $cfg->{cookie_path} ) : () ),
        %attrs,
    };

    unless ( exists $cookie->{expires} ) {
        $cookie->{expires} = $c->calculate_session_cookie_expires();
    }

    #beware: we have to accept also the old syntax "cookie_secure = true"
    my $sec = $cfg->{cookie_secure} || 0; # default = 0 (not set)
    $cookie->{secure} = 1 unless ( ($sec==0) || ($sec==2) );
    $cookie->{secure} = 1 if ( ($sec==2) && $c->req->secure );

    $cookie->{httponly} = $cfg->{cookie_httponly};
    $cookie->{httponly} = 1
        unless defined $cookie->{httponly}; # default = 1 (set httponly)

    return $cookie;
}

sub calc_expiry { # compat
    my $c = shift;
    $c->maybe::next::method( @_ ) || $c->calculate_session_cookie_expires( @_ );
}

sub calculate_session_cookie_expires {
    my $c   = shift;
    my $cfg = $c->_session_plugin_config;

    my $value = $c->maybe::next::method(@_);
    return $value if $value;

    if ( exists $cfg->{cookie_expires} ) {
        if ( $cfg->{cookie_expires} > 0 ) {
            return time() + $cfg->{cookie_expires};
        }
        else {
            return undef;
        }
    }
    else {
        return $c->session_expires;
    }
}

sub get_session_cookie {
    my $c = shift;

    my $cookie_name = $c->_session_plugin_config->{cookie_name};

    my $mac = $c->portalSession->clientMac;
    if(valid_mac($mac)){
        $mac =~ s/\://g;
        return $mac;
    }
    else {
        $c->generate_session_id();
    }
}

sub get_session_id {
    my $c = shift;

    my $mac = $c->portalSession->clientMac;
    $mac =~ s/\://g;
    return $mac;

    $c->maybe::next::method(@_);
}

sub delete_session_id {
    my ( $c, $sid ) = @_;

    $c->_deleted_session_id(1); # to prevent get_session_id from returning it

    $c->update_session_cookie( $c->make_session_cookie( $sid, expires => 0 ) );

    $c->maybe::next::method($sid);
}

__PACKAGE__

__END__

=pod

=head1 NAME

Catalyst::Plugin::Session::State::Cookie - Maintain session IDs using cookies.

=head1 SYNOPSIS

    use Catalyst qw/Session Session::State::Cookie Session::Store::Foo/;

=head1 DESCRIPTION

In order for L<Catalyst::Plugin::Session> to work the session ID needs to be
stored on the client, and the session data needs to be stored on the server.

This plugin stores the session ID on the client using the cookie mechanism.

=head1 METHODS

=over 4

=item make_session_cookie

Returns a hash reference with the default values for new cookies.

=item update_session_cookie $hash_ref

Sets the cookie based on C<cookie_name> in the response object.

=item calc_expiry

=item calculate_session_cookie_expires

=item cookie_is_rejecting

=item delete_session_id

=item extend_session_id

=item get_session_cookie

=item get_session_id

=item set_session_id

=back

=head1 EXTENDED METHODS

=over 4

=item prepare_cookies

Will restore if an appropriate cookie is found.

=item finalize_cookies

Will set a cookie called C<session> if it doesn't exist or if its value is not
the current session id.

=item setup_session

Will set the C<cookie_name> parameter to its default value if it isn't set.

=back

=head1 CONFIGURATION

=over 4

=item cookie_name

The name of the cookie to store (defaults to C<Catalyst::Utils::apprefix($c) . '_session'>).

=item cookie_domain

The name of the domain to store in the cookie (defaults to current host)

=item cookie_expires

Number of seconds from now you want to elapse before cookie will expire.
Set to 0 to create a session cookie, ie one which will die when the
user's browser is shut down.

=item cookie_secure

If this attribute B<set to 0> the cookie will not have the secure flag.

If this attribute B<set to 1> (or true for backward compatibility) - the cookie
send by the server to the client will got the secure flag that tells the browser
to send this cookies back to the server only via HTTPS.

If this attribute B<set to 2> then the cookie will got the secure flag only if
the request that caused cookie generation was sent over https (this option is
not good if you are mixing https and http in you application).

Default vaule is 0.

=item cookie_httponly

If this attribute B<set to 0>, the cookie will not have HTTPOnly flag.

If this attribute B<set to 1>, the cookie will got HTTPOnly flag that should
prevent client side Javascript accessing the cookie value - this makes some
sort of session hijacking attacks significantly harder. Unfortunately not all
browsers support this flag (MSIE 6 SP1+, Firefox 3.0.0.6+, Opera 9.5+); if
a browser is not aware of HTTPOnly the flag will be ignored.

Default value is 1.

Note1: Many peole are confused by the name "HTTPOnly" - it B<does not mean>
that this cookie works only over HTTP and not over HTTPS.

Note2: This paramater requires Catalyst::Runtime 5.80005 otherwise is skipped.

=item cookie_path

The path of the request url where cookie should be baked.

=back

For example, you could stick this in MyApp.pm:

  __PACKAGE__->config( 'Plugin::Session' => {
     cookie_domain  => '.mydomain.com',
  });

=head1 CAVEATS

Sessions have to be created before the first write to be saved. For example:

	sub action : Local {
		my ( $self, $c ) = @_;
		$c->res->write("foo");
		$c->session( ... );
		...
	}

Will cause a session ID to not be set, because by the time a session is
actually created the headers have already been sent to the client.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Plugin::Session>.

=head1 AUTHORS

Yuval Kogman E<lt>nothingmuch@woobling.orgE<gt>

=head1 CONTRIBUTORS

This module is derived from L<Catalyst::Plugin::Session::FastMmap> code, and
has been heavily modified since.

  Andrew Ford
  Andy Grundman
  Christian Hansen
  Marcus Ramberg
  Jonathan Rockway E<lt>jrockway@cpan.orgE<gt>
  Sebastian Riedel
  Florian Ragwitz

=head1 COPYRIGHT

Copyright (c) 2005 - 2009
the Catalyst::Plugin::Session::State::Cookie L</AUTHORS> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This program is free software, you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
