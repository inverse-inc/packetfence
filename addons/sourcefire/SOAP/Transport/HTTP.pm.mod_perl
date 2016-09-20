# ======================================================================
#
# Copyright (C) 2000-2004 Paul Kulchenko (paulclinger@yahoo.com)
# SOAP::Lite is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# $Id: HTTP.pm 374 2010-05-14 08:12:25Z kutterma $
#
# ======================================================================

package SOAP::Transport::HTTP;

use strict;

our $VERSION = 0.712;

use SOAP::Lite;
use SOAP::Packager;

# ======================================================================

package SOAP::Transport::HTTP::Client;

use vars qw(@ISA $COMPRESS $USERAGENT_CLASS);
$USERAGENT_CLASS = 'LWP::UserAgent';
@ISA             = qw(SOAP::Client);

$COMPRESS = 'deflate';

my ( %redirect, %mpost, %nocompress );

# hack for HTTP connection that returns Keep-Alive
# miscommunication (?) between LWP::Protocol and LWP::Protocol::http
# dies after timeout, but seems like we could make it work
my $_patched = 0;

sub patch {
    return if $_patched;
    BEGIN { local ($^W) = 0; }
    {
        local $^W = 0;
        sub LWP::UserAgent::redirect_ok;
        *LWP::UserAgent::redirect_ok = sub { 1 }
    }
    {

        package LWP::Protocol;
        local $^W = 0;
        my $collect = \&collect;    # store original
        *collect = sub {
            if ( defined $_[2]->header('Connection')
                && $_[2]->header('Connection') eq 'Keep-Alive' ) {
                my $data = $_[3]->();
                my $next =
                  SOAP::Utils::bytelength($$data) ==
                  $_[2]->header('Content-Length')
                  ? sub { my $str = ''; \$str; }
                  : $_[3];
                my $done = 0;
                $_[3] = sub {
                    $done++ ? &$next : $data;
                };
            }
            goto &$collect;
        };
    }
    $_patched++;
}

sub DESTROY { SOAP::Trace::objects('()') }

sub http_request {
    my $self = shift;
    if (@_) { $self->{'_http_request'} = shift; return $self }
    return $self->{'_http_request'};
}

sub http_response {
    my $self = shift;
    if (@_) { $self->{'_http_response'} = shift; return $self }
    return $self->{'_http_response'};
}

sub new {
    my $class = shift;

    return $class if ref $class;    # skip if we're already object...

    if ( !grep { $_ eq $USERAGENT_CLASS } @ISA ) {
        push @ISA, $USERAGENT_CLASS;
    }

    eval("require $USERAGENT_CLASS")
      or die "Could not load UserAgent class $USERAGENT_CLASS: $@";

    require HTTP::Request;
    require HTTP::Headers;

    patch() if $SOAP::Constants::PATCH_HTTP_KEEPALIVE;

    my ( @params, @methods );
    while (@_) {
        $class->can( $_[0] )
          ? push( @methods, shift() => shift )
          : push( @params,  shift );
    }
    my $self = $class->SUPER::new(@params);

    die
"SOAP::Transport::HTTP::Client must inherit from LWP::UserAgent, or one of its subclasses"
      if !$self->isa("LWP::UserAgent");

    $self->agent( join '/', 'SOAP::Lite', 'Perl',
        $SOAP::Transport::HTTP::VERSION );
    $self->options( {} );

    $self->http_request( HTTP::Request->new() );

    while (@methods) {
        my ( $method, $params ) = splice( @methods, 0, 2 );
        $self->$method( ref $params eq 'ARRAY' ? @$params : $params );
    }

    SOAP::Trace::objects('()');

    return $self;
}

sub send_receive {
    my ( $self, %parameters ) = @_;
    my ( $context, $envelope, $endpoint, $action, $encoding, $parts ) =
      @parameters{qw(context envelope endpoint action encoding parts)};

    $endpoint ||= $self->endpoint;

    my $method = 'POST';
    $COMPRESS = 'gzip';

    $self->options->{is_compress} ||=
      exists $self->options->{compress_threshold}
      && eval { require Compress::Zlib };

    # Initialize the basic about the HTTP Request object
    my $http_request = $self->http_request()->clone();

    # $self->http_request(HTTP::Request->new);
    $http_request->headers( HTTP::Headers->new );

    # TODO - add application/dime
    $http_request->header(
        Accept => ['text/xml', 'multipart/*', 'application/soap'] );
    $http_request->method($method);
    $http_request->url($endpoint);

    no strict 'refs';
    if ($parts) {
        my $packager = $context->packager;
        $envelope = $packager->package( $envelope, $context );
        for my $hname ( keys %{$packager->headers_http} ) {
            $http_request->headers->header(
                $hname => $packager->headers_http->{$hname} );
        }

        # TODO - DIME support
    }

  COMPRESS: {
        my $compressed =
             !exists $nocompress{$endpoint}
          && $self->options->{is_compress}
          && ( $self->options->{compress_threshold} || 0 ) < length $envelope;

        $envelope = Compress::Zlib::memGzip($envelope) if $compressed;

        my $original_encoding = $http_request->content_encoding;

        while (1) {

            # check cache for redirect
            $endpoint = $redirect{$endpoint} if exists $redirect{$endpoint};

            # check cache for M-POST
            $method = 'M-POST' if exists $mpost{$endpoint};

          # what's this all about?
          # unfortunately combination of LWP and Perl 5.6.1 and later has bug
          # in sending multibyte characters. LWP uses length() to calculate
          # content-length header and starting 5.6.1 length() calculates chars
          # instead of bytes. 'use bytes' in THIS file doesn't work, because
          # it's lexically scoped. Unfortunately, content-length we calculate
          # here doesn't work either, because LWP overwrites it with
          # content-length it calculates (which is wrong) AND uses length()
          # during syswrite/sysread, so we are in a bad shape anyway.
          #
          # what to do? we calculate proper content-length (using
          # bytelength() function from SOAP::Utils) and then drop utf8 mark
          # from string (doing pack with 'C0A*' modifier) if length and
          # bytelength are not the same
            my $bytelength = SOAP::Utils::bytelength($envelope);
			if ($] < 5.008) {
				$envelope = pack( 'C0A*', $envelope );
			}
			else {
				require Encode;
				$envelope = Encode::encode('UTF-8', $envelope); 
			}
            #  if !$SOAP::Constants::DO_NOT_USE_LWP_LENGTH_HACK
            #      && length($envelope) != $bytelength;
            $http_request->content($envelope);
            $http_request->protocol('HTTP/1.1');

            $http_request->proxy_authorization_basic( $ENV{'HTTP_proxy_user'},
                $ENV{'HTTP_proxy_pass'} )
              if ( $ENV{'HTTP_proxy_user'} && $ENV{'HTTP_proxy_pass'} );

            # by Murray Nesbitt
            if ( $method eq 'M-POST' ) {
                my $prefix = sprintf '%04d', int( rand(1000) );
                $http_request->header(
                    Man => qq!"$SOAP::Constants::NS_ENV"; ns=$prefix! );
                $http_request->header( "$prefix-SOAPAction" => $action )
                  if defined $action;
            }
            else {
                $http_request->header( SOAPAction => $action )
                  if defined $action;
            }

            #            $http_request->header(Expect => '100-Continue');

            # allow compress if present and let server know we could handle it
            $http_request->header( 'Accept-Encoding' =>
                  [$SOAP::Transport::HTTP::Client::COMPRESS] )
              if $self->options->{is_compress};

            $http_request->content_encoding(
                $SOAP::Transport::HTTP::Client::COMPRESS)
              if $compressed;

            if ( !$http_request->content_type ) {
                $http_request->content_type(
                    join '; ',
                    $SOAP::Constants::DEFAULT_HTTP_CONTENT_TYPE,
                    !$SOAP::Constants::DO_NOT_USE_CHARSET && $encoding
                    ? 'charset=' . lc($encoding)
                    : () );
            }
            elsif ( !$SOAP::Constants::DO_NOT_USE_CHARSET && $encoding ) {
                my $tmpType = $http_request->headers->header('Content-type');

                # $http_request->content_type($tmpType.'; charset=' . lc($encoding));
                my $addition = '; charset=' . lc($encoding);
                $http_request->content_type( $tmpType . $addition )
                  if ( $tmpType !~ /$addition/ );
            }

            $http_request->content_length($bytelength);
            SOAP::Trace::transport($http_request);
            SOAP::Trace::debug( $http_request->as_string );

            $self->SUPER::env_proxy if $ENV{'HTTP_proxy'};

            # send and receive the stuff.
            # TODO maybe eval this? what happens on connection close?
            $self->http_response( $self->SUPER::request($http_request) );
            SOAP::Trace::transport( $self->http_response );
            SOAP::Trace::debug( $self->http_response->as_string );

            # 100 OK, continue to read?
            if ( (
                       $self->http_response->code == 510
                    || $self->http_response->code == 501
                )
                && $method ne 'M-POST'
              ) {
                $mpost{$endpoint} = 1;
            }
            elsif ( $self->http_response->code == 415 && $compressed ) {

                # 415 Unsupported Media Type
                $nocompress{$endpoint} = 1;
                $envelope = Compress::Zlib::memGunzip($envelope);
                $http_request->headers->remove_header('Content-Encoding');
                redo COMPRESS;    # try again without compression
            }
            else {
                last;
            }
        }
    }

    $redirect{$endpoint} = $self->http_response->request->url
      if $self->http_response->previous
          && $self->http_response->previous->is_redirect;

    $self->code( $self->http_response->code );
    $self->message( $self->http_response->message );
    $self->is_success( $self->http_response->is_success );
    $self->status( $self->http_response->status_line );

    # Pull out any cookies from the response headers
    $self->{'_cookie_jar'}->extract_cookies( $self->http_response )
      if $self->{'_cookie_jar'};

    my $content =
      ( $self->http_response->content_encoding || '' ) =~
      /\b$SOAP::Transport::HTTP::Client::COMPRESS\b/o
      && $self->options->{is_compress}
      ? Compress::Zlib::memGunzip( $self->http_response->content )
      : ( $self->http_response->content_encoding || '' ) =~ /\S/ ? die
"Can't understand returned Content-Encoding (@{[$self->http_response->content_encoding]})\n"
      : $self->http_response->content;

    return $self->http_response->content_type =~ m!^multipart/!i
      ? join( "\n", $self->http_response->headers_as_string, $content )
      : $content;
}

# ======================================================================

package SOAP::Transport::HTTP::Server;

use vars qw(@ISA $COMPRESS);
@ISA = qw(SOAP::Server);

use URI;

$COMPRESS = 'deflate';

sub DESTROY { SOAP::Trace::objects('()') }

sub new {
    require LWP::UserAgent;
    my $self = shift;
    return $self if ref $self;    # we're already an object

    my $class = $self;
    $self = $class->SUPER::new(@_);
    $self->{'_on_action'} = sub {
        ( my $action = shift || '' ) =~ s/^(\"?)(.*)\1$/$2/;
        die
"SOAPAction shall match 'uri#method' if present (got '$action', expected '@{[join('#', @_)]}'\n"
          if $action
              && $action ne join( '#', @_ )
              && $action ne join( '/', @_ )
              && ( substr( $_[0], -1, 1 ) ne '/'
                  || $action ne join( '', @_ ) );
    };
    SOAP::Trace::objects('()');

    return $self;
}

sub BEGIN {
    no strict 'refs';
    for my $method (qw(request response)) {
        my $field = '_' . $method;
        *$method = sub {
            my $self = shift->new;
            @_
              ? ( $self->{$field} = shift, return $self )
              : return $self->{$field};
        };
    }
}

sub handle {
    my $self = shift->new;

    SOAP::Trace::debug( $self->request->content );

    if ( $self->request->method eq 'POST' ) {
        $self->action( $self->request->header('SOAPAction') || undef );
    }
    elsif ( $self->request->method eq 'M-POST' ) {
        return $self->response(
            HTTP::Response->new(
                510,    # NOT EXTENDED
"Expected Mandatory header with $SOAP::Constants::NS_ENV as unique URI"
            ) )
          if $self->request->header('Man') !~
              /^"$SOAP::Constants::NS_ENV";\s*ns\s*=\s*(\d+)/;
        $self->action( $self->request->header("$1-SOAPAction") || undef );
    }
    else {
        return $self->response(
            HTTP::Response->new(405) )    # METHOD NOT ALLOWED
    }

    my $compressed =
      ( $self->request->content_encoding || '' ) =~ /\b$COMPRESS\b/;
    $self->options->{is_compress} ||=
      $compressed && eval { require Compress::Zlib };

    # signal error if content-encoding is 'deflate', but we don't want it OR
    # something else, so we don't understand it
    return $self->response(
        HTTP::Response->new(415) )        # UNSUPPORTED MEDIA TYPE
      if $compressed && !$self->options->{is_compress}
          || !$compressed
          && ( $self->request->content_encoding || '' ) =~ /\S/;

    my $content_type = $self->request->content_type || '';

# in some environments (PerlEx?) content_type could be empty, so allow it also
# anyway it'll blow up inside ::Server::handle if something wrong with message
# TBD: but what to do with MIME encoded messages in THOSE environments?
    return $self->make_fault( $SOAP::Constants::FAULT_CLIENT,
            "Content-Type must be 'text/xml,' 'multipart/*,' "
          . "'application/soap+xml,' 'or 'application/dime' instead of '$content_type'"
      )
      if !$SOAP::Constants::DO_NOT_CHECK_CONTENT_TYPE
          && $content_type
          && $content_type ne 'application/soap+xml'
          && $content_type ne 'text/xml'
          && $content_type ne 'application/dime'
          && $content_type !~ m!^multipart/!;

    # TODO - Handle the Expect: 100-Continue HTTP/1.1 Header
    if ( defined( $self->request->header("Expect") )
        && ( $self->request->header("Expect") eq "100-Continue" ) ) {

    }

    # TODO - this should query SOAP::Packager to see what types it supports,
    #      I don't like how this is hardcoded here.
    my $content =
      $compressed
      ? Compress::Zlib::uncompress( $self->request->content )
      : $self->request->content;

    my $response = $self->SUPER::handle(
        $self->request->content_type =~ m!^multipart/!
        ? join( "\n", $self->request->headers_as_string, $content )
        : $content
    ) or return;

    SOAP::Trace::debug($response);

    $self->make_response( $SOAP::Constants::HTTP_ON_SUCCESS_CODE, $response );
}

sub make_fault {
    my $self = shift;
    $self->make_response(
        $SOAP::Constants::HTTP_ON_FAULT_CODE => $self->SUPER::make_fault(@_)
    );
    return;
}

sub make_response {
    my ( $self, $code, $response ) = @_;

    my $encoding = $1
      if $response =~ /^<\?xml(?: version="1.0"| encoding="([^\"]+)")+\?>/;

    $response =~ s!(\?>)!$1<?xml-stylesheet type="text/css"?>!
      if $self->request->content_type eq 'multipart/form-data';

    $self->options->{is_compress} ||=
      exists $self->options->{compress_threshold}
      && eval { require Compress::Zlib };

    my $compressed = $self->options->{is_compress}
      && grep( /\b($COMPRESS|\*)\b/,
        $self->request->header('Accept-Encoding') )
      && ( $self->options->{compress_threshold} || 0 ) <
      SOAP::Utils::bytelength $response;

    $response = Compress::Zlib::compress($response) if $compressed;

# this next line does not look like a good test to see if something is multipart
# perhaps a /content-type:.*multipart\//gi is a better regex?
    my ($is_multipart) =
      ( $response =~ /content-type:.* boundary="([^\"]*)"/im );

    $self->response(
        HTTP::Response->new(
            $code => undef,
            HTTP::Headers->new(
                'SOAPServer' => $self->product_tokens,
                $compressed ? ( 'Content-Encoding' => $COMPRESS ) : (),
                'Content-Type' => join( '; ',
                    'text/xml',
                    !$SOAP::Constants::DO_NOT_USE_CHARSET
                      && $encoding ? 'charset=' . lc($encoding) : () ),
                'Content-Length' => SOAP::Utils::bytelength $response
            ),
            ( $] > 5.007 )
            ? do { require Encode; Encode::encode( $encoding, $response ) }
            : $response,
        ) );

    $self->response->headers->header( 'Content-Type' =>
'Multipart/Related; type="text/xml"; start="<main_envelope>"; boundary="'
          . $is_multipart
          . '"' )
      if $is_multipart;
}

# ->VERSION leaks a scalar every call - no idea why.
sub product_tokens {
    join '/', 'SOAP::Lite', 'Perl', $SOAP::Transport::HTTP::VERSION;
}

# ======================================================================

package SOAP::Transport::HTTP::CGI;

use vars qw(@ISA);
@ISA = qw(SOAP::Transport::HTTP::Server);

sub DESTROY { SOAP::Trace::objects('()') }

sub new {
    my $self = shift;
    return $self if ref $self;

    my $class = ref($self) || $self;
    $self = $class->SUPER::new(@_);
    SOAP::Trace::objects('()');

    return $self;
}

sub make_response {
    my $self = shift;
    $self->SUPER::make_response(@_);
}

sub handle {
    my $self = shift->new;

    my $length = $ENV{'CONTENT_LENGTH'} || 0;

    # if the HTTP_TRANSFER_ENCODING env is defined, set $chunked if it's chunked*
    # else to false
    my $chunked = (defined $ENV{'HTTP_TRANSFER_ENCODING'}
        && $ENV{'HTTP_TRANSFER_ENCODING'} =~ /^chunked.*$/) || 0;


    my $content = q{};

    if ($chunked) {
        my $buffer;
        binmode(STDIN);
        while ( read( STDIN, my $buffer, 1024 ) ) {
            $content .= $buffer;
        }
        $length = length($content);
    }

    if ( !$length ) {
        $self->response( HTTP::Response->new(411) )    # LENGTH REQUIRED
    }
    elsif ( defined $SOAP::Constants::MAX_CONTENT_SIZE
        && $length > $SOAP::Constants::MAX_CONTENT_SIZE ) {
        $self->response( HTTP::Response->new(413) ) # REQUEST ENTITY TOO LARGE
    }
    else {
        if ( exists $ENV{EXPECT} && $ENV{EXPECT} =~ /\b100-Continue\b/i ) {
            print "HTTP/1.1 100 Continue\r\n\r\n";
        }

        #my $content = q{};
        if ( !$chunked ) {
            my $buffer;
            binmode(STDIN);
            while ( sysread( STDIN, $buffer, $length ) ) {
                $content .= $buffer;
                last if ( length($content) >= $length );
            }
        }

        $self->request(
            HTTP::Request->new(
                $ENV{'REQUEST_METHOD'} || '' => $ENV{'SCRIPT_NAME'},
                HTTP::Headers->new(
                    map { (
                              /^HTTP_(.+)/i
                            ? ( $1 =~ m/SOAPACTION/ )
                                  ? ('SOAPAction')
                                  : ($1)
                            : $_
                          ) => $ENV{$_}
                      } keys %ENV
                ),
                $content,
            ) );
        $self->SUPER::handle;
    }

    # imitate nph- cgi for IIS (pointed by Murray Nesbitt)
    my $status =
      defined( $ENV{'SERVER_SOFTWARE'} )
      && $ENV{'SERVER_SOFTWARE'} =~ /IIS/
      ? $ENV{SERVER_PROTOCOL} || 'HTTP/1.0'
      : 'Status:';
    my $code = $self->response->code;

    binmode(STDOUT);

    print STDOUT "$status $code ", HTTP::Status::status_message($code),
      "\015\012", $self->response->headers_as_string("\015\012"), "\015\012",
      $self->response->content;
}

# ======================================================================

package SOAP::Transport::HTTP::Daemon;

use Carp ();
use vars qw($AUTOLOAD @ISA);
@ISA = qw(SOAP::Transport::HTTP::Server);

sub DESTROY { SOAP::Trace::objects('()') }

#sub new { require HTTP::Daemon;
sub new {
    my $self = shift;
    return $self if ( ref $self );

    my $class = $self;

    my ( @params, @methods );
    while (@_) {
        $class->can( $_[0] )
          ? push( @methods, shift() => shift )
          : push( @params,  shift );
    }
    $self = $class->SUPER::new;

    # Added in 0.65 - Thanks to Nils Sowen
    # use SSL if there is any parameter with SSL_* in the name
    $self->SSL(1) if !$self->SSL && grep /^SSL_/, @params;
    my $http_daemon = $self->http_daemon_class;
    eval "require $http_daemon"
      or Carp::croak $@
      unless $http_daemon->can('new');

    $self->{_daemon} = $http_daemon->new(@params)
      or Carp::croak "Can't create daemon: $!";

    # End SSL patch

    $self->myuri( URI->new( $self->url )->canonical->as_string );

    while (@methods) {
        my ( $method, $params ) = splice( @methods, 0, 2 );
        $self->$method(
            ref $params eq 'ARRAY'
            ? @$params
            : $params
        );
    }
    SOAP::Trace::objects('()');

    return $self;
}

sub SSL {
    my $self = shift->new;
    if (@_) {
        $self->{_SSL} = shift;
        return $self;
    }
    return $self->{_SSL};
}

sub http_daemon_class { shift->SSL ? 'HTTP::Daemon::SSL' : 'HTTP::Daemon' }

sub AUTOLOAD {
    my $method = substr( $AUTOLOAD, rindex( $AUTOLOAD, '::' ) + 2 );
    return if $method eq 'DESTROY';

    no strict 'refs';
    *$AUTOLOAD = sub { shift->{_daemon}->$method(@_) };
    goto &$AUTOLOAD;
}

sub handle {
    my $self = shift->new;
    while ( my $c = $self->accept ) {
        while ( my $r = $c->get_request ) {
            $self->request($r);
            $self->SUPER::handle;
            $c->send_response( $self->response );
        }

# replaced ->close, thanks to Sean Meisner <Sean.Meisner@VerizonWireless.com>
# shutdown() doesn't work on AIX. close() is used in this case. Thanks to Jos Clijmans <jos.clijmans@recyfin.be>
        $c->can('shutdown')
          ? $c->shutdown(2)
          : $c->close();
        $c->close;
    }
}

# ======================================================================

package SOAP::Transport::HTTP::Apache;

use vars qw(@ISA);
@ISA = qw(SOAP::Transport::HTTP::Server);

sub DESTROY { SOAP::Trace::objects('()') }

sub new {
    my $self = shift;
    unless ( ref $self ) {
        my $class = ref($self) || $self;
        $self = $class->SUPER::new(@_);
        SOAP::Trace::objects('()');
    }

    # Added this code thanks to JT Justman
    # This code improves and provides more robust support for
    # multiple versions of Apache and mod_perl

    # mod_perl 2.0
    if ( defined $ENV{MOD_PERL_API_VERSION}
        && $ENV{MOD_PERL_API_VERSION} >= 2 ) {
        require Apache2::RequestRec;
        require Apache2::RequestIO;
        require Apache2::Const;
        require Apache2::RequestUtil;
        require APR::Table;
        Apache2::Const->import( -compile => 'OK' );
        Apache2::Const->import( -compile => 'HTTP_BAD_REQUEST' );
        $self->{'MOD_PERL_VERSION'} = 2;
        $self->{OK} = &Apache2::Const::OK;
    }
    else {    # mod_perl 1.xx
        die "Could not find or load mod_perl"
          unless ( eval "require mod_perl" );
        die "Could not detect your version of mod_perl"
          if ( !defined($mod_perl::VERSION) );
        if ( $mod_perl::VERSION < 1.99 ) {
            require Apache;
            require Apache::Constants;
            Apache::Constants->import('OK');
            Apache::Constants->import('HTTP_BAD_REQUEST');
            $self->{'MOD_PERL_VERSION'} = 1;
            $self->{OK} = &Apache::Constants::OK;
        }
        else {
            require Apache::RequestRec;
            require Apache::RequestIO;
            require Apache::Const;
            Apache::Const->import( -compile => 'OK' );
            Apache::Const->import( -compile => 'HTTP_BAD_REQUEST' );
            $self->{'MOD_PERL_VERSION'} = 1.99;
            $self->{OK} = &Apache::OK;
        }
    }

    return $self;
}

sub handler {
    my $self = shift->new;
    my $r    = shift;

    # Begin patch from JT Justman
    if ( !$r ) {
        if ( $self->{'MOD_PERL_VERSION'} < 2 ) {
            $r = Apache->request();
        }
        else {
            $r = Apache2::RequestUtil->request();
        }
    }

    my $cont_len;
    if ( $self->{'MOD_PERL_VERSION'} < 2 ) {
        $cont_len = $r->header_in('Content-length');
    }
    else {
        $cont_len = $r->headers_in->get('Content-length');
    }

    # End patch from JT Justman

    my $content = "";
    if ( $cont_len > 0 ) {
        my $buf;

        # attempt to slurp in the content at once...
        $content .= $buf while ( $r->read( $buf, $cont_len ) > 0 );
    }
    else {

        # throw appropriate error for mod_perl 2
        return Apache2::Const::HTTP_BAD_REQUEST()
          if ( $self->{'MOD_PERL_VERSION'} >= 2 );
        return Apache::Constants::BAD_REQUEST();
    }

    $self->request(
        HTTP::Request->new(
            $r->method() => $r->uri,
            HTTP::Headers->new( $r->headers_in ),
            $content
        ) );
    $self->SUPER::handle;

    # we will specify status manually for Apache, because
    # if we do it as it has to be done, returning SERVER_ERROR,
    # Apache will modify our content_type to 'text/html; ....'
    # which is not what we want.
    # will emulate normal response, but with custom status code
    # which could also be 500.
    if ($self->{'MOD_PERL_VERSION'} < 2 ) {
        $r->status( $self->response->code );
    }
    else {
        $r->status_line($self->response->code);
    }

    # Begin JT Justman patch
    if ( $self->{'MOD_PERL_VERSION'} > 1 ) {
        $self->response->headers->scan(sub { $r->headers_out->add(@_) });
        $r->content_type( join '; ', $self->response->content_type );
    }
    else {
        $self->response->headers->scan( sub { $r->header_out(@_) } );
        $r->send_http_header( join '; ', $self->response->content_type );
    }

    $r->print( $self->response->content );
    return $self->{OK};

    # End JT Justman patch
}

sub configure {
    my $self   = shift->new;
    my $config = shift->dir_config;
    for (%$config) {
        $config->{$_} =~ /=>/
          ? $self->$_( {split /\s*(?:=>|,)\s*/, $config->{$_}} )
          : ref $self->$_() ? ()    # hm, nothing can be done here
          : $self->$_( split /\s+|\s*,\s*/, $config->{$_} )
          if $self->can($_);
    }
    return $self;
}

{

    # just create alias
    sub handle;
    *handle = \&handler
}

# ======================================================================
#
# Copyright (C) 2001 Single Source oy (marko.asplund@kronodoc.fi)
# a FastCGI transport class for SOAP::Lite.
# Updated formatting and removed dead code in new() in 2008
# by Martin Kutter
#
# ======================================================================

package SOAP::Transport::HTTP::FCGI;

use vars qw(@ISA);
@ISA = qw(SOAP::Transport::HTTP::CGI);

sub DESTROY { SOAP::Trace::objects('()') }

sub new {

    require FCGI;
    Exporter::require_version( 'FCGI' => 0.47 )
      ;    # requires thread-safe interface

    my $class = shift;
    return $class if ref $class;

    my $self = $class->SUPER::new(@_);
    $self->{_fcgirq} = FCGI::Request( \*STDIN, \*STDOUT, \*STDERR );
    SOAP::Trace::objects('()');

    return $self;
}

sub handle {
    my $self = shift->new;

    my ( $r1, $r2 );
    my $fcgirq = $self->{_fcgirq};

    while ( ( $r1 = $fcgirq->Accept() ) >= 0 ) {
        $r2 = $self->SUPER::handle;
    }

    return undef;
}

# ======================================================================

1;
