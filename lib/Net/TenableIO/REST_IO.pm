package Net::TenableIO::REST_IO;

use warnings;
use strict;

use Carp;
use LWP::UserAgent;
use HTTP::Cookies;
use JSON;
use Data::Dumper qw(Dumper);

our $VERSION = '0.100';

sub new {

    my ($class, $host, $options) = @_;

    my $agent      = LWP::UserAgent->new();
    my $cookie_jar = HTTP::Cookies->new();

    croak('Specify cloud.tenable.com as a valid host')
        unless ($host);

    $agent->agent(_agent());
    $agent->ssl_opts(verify_hostname => 0);

    my $timeout  = delete($options->{timeout});
    my $ssl_opts = delete($options->{ssl_options}) || {};

    $agent->timeout($timeout);
    $agent->ssl_opts($ssl_opts);
    $agent->cookie_jar($cookie_jar);

    my $self = {
        host       => $host,
        options    => $options,
        url        => "https://$host",
        accesskey  => undef,
        secretkey  => undef,
        agent      => $agent,
    };

    bless $self, $class;

    #$self->_init();

    return $self;

}

sub _agent {

    my $class = __PACKAGE__;
    (my $agent = $class) =~ s{::}{-}g;

    return $agent . "/" . $class->VERSION;

}

sub _trim {

  my $string = shift;
  return $string unless($string);

  $string =~ s/^\s+|\s+$//g;
  return $string;

}

sub _init {

    my ($self) = @_;

    my $response = eval { $self->request('GET', '/system') };

    croak('Failed to connect to Tenable IO via ', $self->{url})
        if ($@);

    if ($response) {

        $self->{version}  = $response->{'version'};
        $self->{build_id} = $response->{'buildID'};
        $self->{license}  = $response->{'licenseStatus'};
        $self->{uuid}     = $response->{'uuid'};

    }

}

sub post {

    my ($self, $path, $params) = @_;

    (@_ == 2 || (@_ == 3 && ref $params eq 'HASH') || (@_ == 3 && ref $params eq 'ARRAY'))
        or croak(q/Usage: $io->post(PATH, {[HASHREF] o [ARRAYREF]})/);

    return $self->request('POST', $path, $params);

}

sub get {

    my ($self, $path, $params) = @_;

    (@_ == 2 || (@_ == 3 && ref $params eq 'HASH') || (@_ == 3 && ref $params eq 'ARRAY'))
        or croak(q/Usage: $io->get(PATH, {[HASHREF] o [ARRAYREF]})/);

    return $self->request('GET', $path, $params);

}

sub put {

    my ($self, $path, $params) = @_;

    (@_ == 2 || (@_ == 3 && ref $params eq 'HASH'))
        or croak(q/Usage: $io->put(PATH, [HASHREF])/);

    return $self->request('PUT', $path, $params);

}

sub delete {

    my ($self, $path, $params) = @_;

    (@_ == 2 || (@_ == 3 && ref $params eq 'HASH'))
        or croak(q/Usage: $sc->delete(PATH, [HASHREF])/);

    return $self->request('DELETE', $path, $params);

}

sub patch {

    my ($self, $path, $params) = @_;

    (@_ == 2 || (@_ == 3 && ref $params eq 'HASH'))
        or croak(q/Usage: $sc->patch(PATH, [HASHREF])/);

    return $self->request('PATCH', $path, $params);

}

sub request {

    my ($self, $method, $path, $params) = @_;

    croak('Unsupported request method')
        if ($method !~ /(get|post|put|delete|patch)/i);

    $path =~ s/^\///;

    my $url = $self->{url} . "/$path";
       $url = $url . $params->[0] if (ref $params eq 'ARRAY');

    my $request = HTTP::Request->new( uc($method) => $url );

    my $content = undef;
       $content = encode_json($params) if (ref $params eq 'HASH');

    if ($content) {
        $request->content($content);
    }

    $request->header('Content-Type', 'application/json');

    my $response = $self->{agent}->request($request);

    my $result  = {};
    my $is_json = undef;
       $is_json = ($response->{'_headers'}->{'content-type'} =~ /application\/json/) if ($method ne 'PUT');

    if ($is_json) {
        $result = eval { decode_json($response->{'_content'}) };
    }

    if ($response->{'_msg'} eq 'OK') {

        if ($is_json) {
            return $result;
        } else {
            return $response->{'_content'};
        }

    } else {

        if ($response->{'_rc'} == 403) {
            $result  = eval { decode_json($response->{'_content'}) };
            $is_json = 1;
        }

        if ($is_json && exists($response->{'_msg'})) {
            croak _trim($response->{'_msg'});
        } else {
            croak $response->{'_content'};
        }

    }

}

sub auth {

    my ($self, $accesskey, $secretkey) = @_;

    (@_ == 3) or croak(q/Usage: $io->auth(ACCESSKEY, SECRETKEY)/);

    $self->{accesskey} = $accesskey;
    $self->{secretkey} = $secretkey;
    my $apikeys = "accessKey=".$accesskey.";"."secretKey=".$secretkey;
    $self->{agent}->default_header('X-APIKeys' => $apikeys);

    return 1;

}

sub logout {

    my ($self) = @_;
    $self->request('DELETE', '/token');

    return 1;

}

sub DESTROY {
    my ($self) = @_;
    $self->logout() if $self->{token};
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Net::TenableIO::REST - Perl interface to Tenable IO REST API

=head1 SYNOPSIS

    use Net::TenableIO::REST;
    my $io = Net::TenableIO::REST('io.example.org');

    $io->login('secman', 'password');

    my $running_scans = $io->get('/scans', { filter => 'running' });

=head1 DESCRIPTION

This module provides Perl scripts easy way to interface the REST API of Tenable IO.

For more information about the TenableIO REST API follow the online documentation:

L<https://developer.tenable.com/docs>

=head1 CONSTRUCTOR

=head2 Net::TenableIO::REST->new ( host [, { timeout => $timeout , ssl_options => $ssl_options } ] )

Create a new instance of B<Net::TenableIO::REST>.

=over 4

=item * C<timeout> : Request timeout in seconds (default is 180) If a socket open,
read or write takes longer than the timeout, an exception is thrown.

=item * C<ssl_options> : A hashref of C<SSL_*> options to pass through to L<IO::Socket::SSL>.

=back

=head1 METHODS

=head2 $io->post|get|put|delete|patch ( path [, { param => value, ... } ] )

Execute a request to Tenable IO REST API. These methods are shorthand for
calling C<request()> for the given method.

    my $io_scan = $io->post('/scans/{scan_id}/export');

=head2 $io->request (method, path [, { param => value, ... } ] )

Execute a HTTP request of the given method type ('GET', 'POST', 'PUT', 'DELETE',
''PATCH') to Tenable IO REST API.

=head2 $io->login ( username, password )

Login into Tenable IO.

=head2 $io->logout

Logout from Tenable IO.

=back

=head1 AUTHOR

=over 4

Aligo S.A.S. <mercadeo@aligo.com.co>
Carrera 43B # 16 - 95 Oficina 1601
Edificio Camara Colombiana de la Infraestructura
Medellín, Colombia

=cut
