package pf::Authentication::Source::HTTPSource;

=head1 NAME

pf::Authentication::Source::HTTPSource - Authentication source backed by an external HTTP API

=head1 DESCRIPTION

Delegates authentication and authorization to an external HTTP API.

Both calls are HTTP POST requests, sent to
C<protocol://host:port/authentication_url> and
C<protocol://host:port/authorization_url>. The body is URL-encoded
(C<application/x-www-form-urlencoded>, the default) or JSON
(C<application/json>), depending on C<content_type>. HTTP basic authentication is used
when both C<username> and C<password> are set. The certificate and the
hostname of the server are verified when C<verify_tls> is enabled.

The API must reply with HTTP status 200 and a JSON body; anything else is
treated as a failure. See L</authenticate> and L</match> for the expected
responses.

=cut

use JSON::MaybeXS;
use Encode qw(decode FB_CROAK);
use pf::constants qw($TRUE $FALSE);
use pf::config qw(%ConfigMfa);
use pf::Authentication::constants;
use pf::Authentication::Action;
use pf::Authentication::Rule;
use pf::Authentication::Source;
use URI::Escape::XS qw(uri_escape uri_unescape);
use WWW::Curl::Easy;
use pf::Curl;
use pf::log;
use Readonly;
use Scalar::Util qw(looks_like_number);
use pf::util;

use Moose;
extends 'pf::Authentication::Source';
with qw(pf::Authentication::InternalRole);

has '+type' => ( default => 'HTTP' );
has 'protocol' => ( isa => 'Str', is => 'rw', default => 'http' );
has 'host' => ( isa => 'Str', is => 'rw', default => '127.0.0.1' );
has 'port' => ( isa => 'Int', is => 'rw', default => '10000' );
has 'username' => ( isa => 'Maybe[Str]', is => 'rw', default => undef );
has 'password' => ( isa => 'Maybe[Str]', is => 'rw', default => undef );
has 'authentication_url' => ( isa => 'Str', is => 'rw', default => '' );
has 'authorization_url' => ( isa => 'Str', is => 'rw', default => '' );
# Sources created before this option existed did not verify TLS: keep that
# behavior when the option is not set. On upgrade, add-default-params-to-auth.pl
# writes this default (disabled) in the existing sources. New sources created in
# the admin UI default to enabled (see useItemDefaults of the sources views).
has 'verify_tls' => ( isa => 'Str', is => 'rw', default => 'disabled' );

Readonly our $CONTENT_TYPE_FORM => 'application/x-www-form-urlencoded';
Readonly our $CONTENT_TYPE_JSON => 'application/json';
has 'content_type' => ( isa => 'Str', is => 'rw', default => $CONTENT_TYPE_FORM );

=head1 METHODS

=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::Login' }

=head2 has_authentication_rules

Whether or not the source should have authentication rules

=cut

sub has_authentication_rules { $FALSE }

=head2 base_url

The URL of a path on the HTTP server

=cut

sub base_url {
    my ($self, $path) = @_;
    my $host = $self->host;
    # An IPv6 address must be enclosed in brackets in a URL
    $host = "[$host]" if $host =~ /:/ && $host !~ /^\[/;
    return $self->protocol."://".$host.":".$self->port."/".$path;
}

=head2 _post_curl

Method used to build a basic curl object

=cut

sub _post_curl {
    my ($self, $uri, $post_fields) = @_;
    my $logger = get_logger();

    $uri = $self->base_url($uri);

    my $curl = pf::Curl::easy();
    my $request = $post_fields;

    if($self->username && $self->password){
        $curl->setopt(CURLOPT_USERNAME, $self->username);
        $curl->setopt(CURLOPT_PASSWORD, $self->password);
    }

    if ($self->is_json) {
        $curl->setopt(CURLOPT_HTTPHEADER, ["Content-Type: $CONTENT_TYPE_JSON"]);
    }

    my $response_body = '';
    $curl->setopt(CURLOPT_POSTFIELDSIZE,length($request));
    $curl->setopt(CURLOPT_POSTFIELDS, $request);
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_DNS_USE_GLOBAL_CACHE, 0);
    $curl->setopt(CURLOPT_NOSIGNAL, 1);
    $curl->setopt(CURLOPT_URL, $uri);
    if (isenabled($self->verify_tls)) {
        $curl->setopt(CURLOPT_SSL_VERIFYHOST, 2);
        $curl->setopt(CURLOPT_SSL_VERIFYPEER, 1);
    } else {
        $curl->setopt(CURLOPT_SSL_VERIFYHOST, 0);
        $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0);
    }

    $logger->debug("Calling Authentication API service using URI : $uri");

    # Starts the actual request
    my $curl_return_code = $curl->perform;

    my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
    return ($curl_return_code, $response_code, $response_body, $curl);


}

=head2 available_attributes

Attributes available to this module

=cut

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes;
  my $own_attributes = [
                        { value => "username", type => $Conditions::SUBSTRING },
                       ];

  return [@$super_attributes, @$own_attributes];
}

=head2 is_json

Whether the requests are sent as JSON

=cut

sub is_json {
    my ($self) = @_;
    return ($self->content_type // '') eq $CONTENT_TYPE_JSON ? $TRUE : $FALSE;
}

=head2 encode_request

Encodes the params of a request according to C<content_type>: see
L</encode_params> (URL-encoded) and L</encode_json_params> (JSON)

=cut

sub encode_request {
    my ($self, %params) = @_;
    return $self->is_json ? encode_json_params(%params) : encode_params(%params);
}

=head2 is_nested_param

Whether the values of a hash param are sent. Only the RADIUS request is: other
hashes of the match params hold local data that must not be sent to the API,
like the owner (person) record with its PSK and OTP secret.

=cut

sub is_nested_param {
    my ($key) = @_;
    return $key eq 'radius_request' ? $TRUE : $FALSE;
}

=head2 encode_json_params

Encodes a hash into a JSON object

Plain values are sent as is, undefined values as null, a multi-valued
attribute as an array. The radius_request hash is sent as an object (see
L</is_nested_param>). Other hashes, objects and deeper structures are not
sent, like in L</encode_params>.
Byte strings holding UTF-8 (like the RADIUS attributes) are decoded first, so
the body is valid UTF-8 without double encoding.

=cut

sub encode_json_params {
    my %hash = @_;
    my %json;
    for my $key (keys %hash) {
        my $value = $hash{$key};
        if (ref($value) eq 'HASH') {
            next if !is_nested_param($key);
            my %sub_json;
            for my $sub_key (keys %$value) {
                my @sub_value = _json_values($value->{$sub_key});
                $sub_json{$sub_key} = $sub_value[0] if @sub_value;
            }
            $json{$key} = \%sub_json;
        } else {
            my @json_value = _json_values($value);
            $json{$key} = $json_value[0] if @json_value;
        }
    }
    return JSON::MaybeXS->new(utf8 => 1, canonical => 1)->encode(\%json);
}

=head2 _json_values

The JSON value of a param, as a list: empty when the value cannot be sent,
the value itself, or an array of the plain values of an array

=cut

sub _json_values {
    my ($value) = @_;
    return (undef) if !defined $value;
    return (_json_string($value)) if !ref $value;
    return ([map { _json_string($_) } grep { !ref $_ } @$value]) if ref($value) eq 'ARRAY';
    return ();
}

=head2 _json_string

A plain value as a character string: a byte string holding valid UTF-8 is
decoded, anything else is kept as is

=cut

sub _json_string {
    my ($value) = @_;
    return $value if !defined $value || looks_like_number($value) || utf8::is_utf8($value) || $value !~ /[\x80-\xff]/;
    my $decoded = eval { decode('UTF-8', $value, FB_CROAK) };
    return defined $decoded ? $decoded : $value;
}

=head2 encode_params

Encodes a hash into URL/BODY parameters

Plain values are sent as is, undefined values as empty strings. The values of
the radius_request hash (see L</is_nested_param>) are sent as
C<radius_request.attribute>, once per value for multi-valued attributes. Other
hashes, objects and deeper structures are not sent.

=cut

sub encode_params {
    my %hash = @_;
    my @pairs;
    for my $key (sort keys %hash) {
        my $value = $hash{$key};
        if (ref($value) eq 'HASH') {
            next if !is_nested_param($key);
            for my $sub_key (sort keys %$value) {
                push @pairs, map { [ "$key.$sub_key", $_ ] } _scalar_values($value->{$sub_key});
            }
        } else {
            push @pairs, map { [ $key, $_ ] } _scalar_values($value);
        }
    }
    return join "&", map { join "=", map { uri_escape($_) } @$_ } @pairs;
}

=head2 _scalar_values

The values of a param that can be sent: the value itself, or the elements of an
array of plain values. Undefined values become empty strings.

=cut

sub _scalar_values {
    my ($value) = @_;
    return ('') if !defined $value;
    return ($value) if !ref $value;
    return map { $_ // '' } grep { !ref $_ } @$value if ref($value) eq 'ARRAY';
    return ();
}

=head2 is_sensitive_attribute

Whether a RADIUS attribute holds a secret (password, OTP, challenge or EAP
exchange) that must not be sent to the authorization API

This includes the pre-shared keys and the WPA handshake material sent by the
controllers for DPSK/PPSK (ex: Ruckus-DPSK-Anonce, Ruckus-DPSK-EAPOL-Key-Frame,
Eleven-EAPOL-Anonce, FreeRADIUS-802.1X-EAPoL-Key-Msg): with the SSID and the
MAC addresses, it allows an offline brute force of the PSK.

=cut

sub is_sensitive_attribute {
    my ($name) = @_;
    return $name =~ /password|^(?:MS-)?CHAP|^EAP-Message$|^State$|^Message-Authenticator$|PSK|PMK|EAPOL|Anonce/i ? $TRUE : $FALSE;
}

=head2 authorization_params

The match parameters sent to the authorization API: the secrets of the RADIUS
request (see L</is_sensitive_attribute>) and any password are removed.

=cut

sub authorization_params {
    my ($params) = @_;
    my %params = map { $_ => $params->{$_} } grep { !is_sensitive_attribute($_) } keys %$params;
    my $radius_request = $params{radius_request};
    if (ref($radius_request) eq 'HASH') {
        $params{radius_request} = {
            map { $_ => $radius_request->{$_} } grep { !is_sensitive_attribute($_) } keys %$radius_request
        };
    }
    return \%params;
}

=head2 mfa_exists

Whether an MFA with this ID is configured

=cut

sub mfa_exists {
    my ($self, $mfa_id) = @_;
    return exists $ConfigMfa{$mfa_id} ? $TRUE : $FALSE;
}

=head2 authenticate

Whether or not the username/password combination is valid

The server should reply with two attributes in a JSON response

The username and password are sent as the C<username> and C<password>
fields of the request body (see L</encode_request>).

result should be 1 for success, 0 for failure
message should be the reason it succeeded or failed

Example JSON response :
{"result":1,"message":"Valid username and password"}

=cut

sub authenticate {
    my ( $self, $username, $password ) = @_;

    my $uri = $self->authentication_url;

    my $post_fields = $self->encode_request(username => $username, password => $password);

    my ($curl_return_code, $response_code, $response_body, $curl) = $self->_post_curl($uri, $post_fields);
    if ($curl_return_code == 0 && $response_code == 200) {
        return $self->handleResults($response_body, $username);
    } else {
        my $curl_error = $curl->errbuf;
        get_logger->error("Could get proper reply for authentication request to ".$self->host.". Server replied with $response_body. Curl error : $curl_error");
        return ($FALSE, 'Unable to contact authentication server.');
    }
}

=head2 handleResults

Decodes the JSON body of an authentication reply and returns
C<($result, $message)>. An invalid or non-object body is a failure.

=cut

sub handleResults {
    my ($self, $response_body, $username) = @_;
    my $result = eval {decode_json($response_body) };
    if ($@ || ref($result) ne 'HASH') {
        get_logger->error("$@");
        return ($FALSE, "Invalid response");
    }
    if ($result->{result}) {
        get_logger->info( "Authentication valid with $username in custom source");
    } else {
        $result->{message} //= "Authentication failed";
        get_logger->info( "Authentication invalid with $username in custom source. Error is : " . $result->{message} );
    }

    return ( $result->{result} // $FALSE, $result->{message} ); 
}

=head2 match

The HTTPSource class overrides the match method of the Source parent class.

The actions are defined by the API through its JSON response. All the
match parameters (username, mac, SSID, rule_class, ...) are sent in the
request body, see L</encode_request>. The attributes of the RADIUS request are
sent as C<radius_request.Attribute-Name> (ex: radius_request.TLS-Client-Cert-Common-Name)
in a URL-encoded body, or in the C<radius_request> object of a JSON body,
except the passwords, CHAP/MS-CHAP values, EAP-Message, State,
Message-Authenticator and the PSK/DPSK and WPA handshake (EAPOL) attributes.

Supported attributes: access_duration, access_level, sponsor (1 or true marks
the user as a sponsor), unregdate (ignored when access_duration is set),
category, time_balance, bandwidth_balance, trigger_radius_mfa and
trigger_portal_mfa (the ID of the MFA to trigger, ignored when no such MFA
is configured). Attributes whose value is not a string or a number are ignored.
An invalid JSON reply, or one that is not an object, is a failure.

Sample JSON response, note that not all attributes are necessary, only send back what you need.
{"access_duration":"1D","access_level":"ALL","sponsor":1,"unregdate":"2030-01-01","category":"default"}

=cut

sub match {
    my ($self, $params) = @_;
    my $common_attributes = $self->common_attributes();

    my $uri = $self->authorization_url;

    my $post_fields = $self->encode_request(%{authorization_params($params)});

    my ($curl_return_code, $response_code, $response_body, $curl) = $self->_post_curl($uri, $post_fields);
    if ($curl_return_code != 0 || $response_code != 200) {
        my $curl_error = $curl->errbuf;
        get_logger->error("Could get proper reply for authorization request to ".$self->host.". Server replied with $response_body. Curl error : $curl_error");
        return undef;
    }

    my $result = eval { decode_json($response_body) };
    if ($@ || ref($result) ne 'HASH') {
        get_logger->error("Invalid reply for authorization request to ".$self->host.": the body is not a JSON object. $@");
        return undef;
    }

    # Keep only the attributes with a plain value (string or number)
    my %values;
    for my $name (keys %$result) {
        my $value = $result->{$name};
        next if !defined $value;
        # sponsor also accepts a JSON boolean (true marks the user as a sponsor)
        $value = $value ? 1 : 0 if $name eq 'sponsor' && JSON::MaybeXS::is_bool($value);
        if (ref $value) {
            get_logger->warn("Ignoring the attribute $name of the authorization reply from ".$self->host.": not a string or a number");
            next;
        }
        $values{$name} = $value;
    }

    my @actions = ();

    my $access_duration = $values{'access_duration'};
    if (defined $access_duration) {
        push @actions, pf::Authentication::Action->new({type => $Actions::SET_ACCESS_DURATION, value => $access_duration});
    }

    my $access_level = $values{'access_level'};
    if (defined $access_level ) {
        push @actions, pf::Authentication::Action->new({type => $Actions::SET_ACCESS_LEVEL, value => $access_level});
    }

    my $sponsor = $values{'sponsor'};
    if (defined($sponsor) && looks_like_number($sponsor) && $sponsor == 1) {
        push @actions, pf::Authentication::Action->new({type => $Actions::MARK_AS_SPONSOR, value => 1});
    }

    my $unregdate = $values{'unregdate'};
    if (!defined $access_duration && defined $unregdate) {
        push @actions, pf::Authentication::Action->new({type => $Actions::SET_UNREG_DATE, value => $unregdate});
    }

    my $category = $values{'category'};
    if (defined $category) {
        push @actions, pf::Authentication::Action->new({type => $Actions::SET_ROLE, value => $category});
    }

    my $time_balance = $values{'time_balance'};
    if (defined $time_balance) {
        push @actions, pf::Authentication::Action->new({type => $Actions::SET_TIME_BALANCE, value => $time_balance});
    }

    my $bandwidth_balance = $values{'bandwidth_balance'};
    if (defined $bandwidth_balance) {
        push @actions, pf::Authentication::Action->new({type => $Actions::SET_BANDWIDTH_BALANCE, value => $bandwidth_balance});
    }

    for my $mfa_action ([trigger_radius_mfa => $Actions::TRIGGER_RADIUS_MFA], [trigger_portal_mfa => $Actions::TRIGGER_PORTAL_MFA]) {
        my ($name, $type) = @$mfa_action;
        my $mfa_id = $values{$name};
        next if !defined $mfa_id;
        if (!$self->mfa_exists($mfa_id)) {
            get_logger->warn("Ignoring $name=$mfa_id from the authorization reply of ".$self->host.": no such MFA is configured");
            next;
        }
        push @actions, pf::Authentication::Action->new({type => $type, value => $mfa_id});
    }

    return pf::Authentication::Rule->new(
        id => "default",
        class => $params->{rule_class},
        actions => \@actions,
    );
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
