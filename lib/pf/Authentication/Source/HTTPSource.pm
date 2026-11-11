package pf::Authentication::Source::HTTPSource;

=head1 NAME

pf::Authentication::Source::HTTPSource - Authentication source backed by an external HTTP API

=head1 DESCRIPTION

Delegates authentication and authorization to an external HTTP API.

Both calls are HTTP POST requests, sent to
C<protocol://host:port/authentication_url> and
C<protocol://host:port/authorization_url>. The body is JSON
(C<application/json>, the default) or URL-encoded
(C<application/x-www-form-urlencoded>), depending on C<content_type>. HTTP basic authentication is used
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
use Hash::Flatten qw(flatten);
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
# Disabled by default: the sources created before this option existed did not verify TLS
has 'verify_tls' => ( isa => 'Str', is => 'rw', default => 'disabled' );

Readonly our $CONTENT_TYPE_FORM => 'application/x-www-form-urlencoded';
Readonly our $CONTENT_TYPE_JSON => 'application/json';
# URL-encoded by default: the only format the sources sent before this option existed
has 'content_type' => ( isa => 'Str', is => 'rw', default => $CONTENT_TYPE_FORM );

# One encoder for all the requests
my $JSON_ENCODER = JSON::MaybeXS->new(utf8 => 1, canonical => 1);

=head1 RADIUS ATTRIBUTES

Only these attributes of the RADIUS request are sent to the authorization API
(see L</is_allowed_radius_attribute>): any other one, like a vendor attribute,
may hold a secret (password, PSK, digest, WPA handshake) that would allow an
offline brute force.

=cut

Readonly our @RADIUS_ATTRIBUTES => qw(
    User-Name Stripped-User-Name Realm
    Calling-Station-Id Called-Station-Id Called-Station-SSID
    NAS-IP-Address NAS-IPv6-Address NAS-Identifier NAS-Port NAS-Port-Id NAS-Port-Type
    Service-Type Framed-Protocol Framed-IP-Address Framed-IPv6-Address Framed-MTU
    Connect-Info Acct-Session-Id Acct-Multi-Session-Id Event-Timestamp
    EAP-Type FreeRADIUS-Client-IP-Address FreeRADIUS-Client-Shortname
    Cisco-AVPair Airespace-Wlan-Id Aruba-Essid-Name Aruba-AP-Group Aruba-Location-Id Ruckus-SSID
    PacketFence-Authorization-Status PacketFence-AutoReg PacketFence-Computer-Name
    PacketFence-Connection-Type PacketFence-Domain PacketFence-Eap-Type PacketFence-IfIndex
    PacketFence-IsPhone PacketFence-Mac PacketFence-NasName PacketFence-Outer-User
    PacketFence-Profile PacketFence-Proxied-From PacketFence-Proxied-To PacketFence-Radius-Ip
    PacketFence-Request-Time PacketFence-Role PacketFence-ShortName PacketFence-Source
    PacketFence-SSID PacketFence-Status PacketFence-Switch-Id PacketFence-Switch-Ip-Address
    PacketFence-Switch-Mac PacketFence-UserDN PacketFence-UserName
);

# The certificate of an EAP-TLS client and of its issuer
Readonly our $RADIUS_ATTRIBUTE_PREFIXES => qr/^TLS-(?:Client-)?Cert-/;

my %RADIUS_ATTRIBUTES = map { $_ => 1 } @RADIUS_ATTRIBUTES;

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

Whether the requests are sent as JSON: the media type (without its parameters,
ex: C<; charset=utf-8>) is C<application/json>, or C<json>. Any other value is
URL-encoded, with a warning when it is not C<application/x-www-form-urlencoded>.

=cut

sub is_json {
    my ($self) = @_;
    my ($media_type) = split /;/, $self->content_type // '', 2;
    $media_type = lc($media_type // '');
    $media_type =~ s/^\s+|\s+$//g;
    return $TRUE if $media_type eq $CONTENT_TYPE_JSON || $media_type eq 'json';
    if ($media_type ne '' && $media_type ne $CONTENT_TYPE_FORM) {
        get_logger->warn("Unknown content_type '" . $self->content_type . "' for the HTTP source " . $self->id . ", the requests are URL-encoded");
    }
    return $FALSE;
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
    return $JSON_ENCODER->encode(\%json);
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

The fields are named with L<Hash::Flatten>, like the rule conditions of
L<pf::Authentication::Source/match>: the values of the radius_request hash (see
L</is_nested_param>) are sent as C<radius_request.attribute>, and the values of
a multi-valued attribute as C<radius_request.attribute:0>,
C<radius_request.attribute:1>, ... Undefined values are sent as empty strings.
Other hashes, objects and deeper structures are not sent.

=cut

sub encode_params {
    my %hash = @_;
    my %plain;
    for my $key (keys %hash) {
        my $value = $hash{$key};
        if (ref($value) eq 'HASH') {
            next if !is_nested_param($key);
            my %sub_plain;
            for my $sub_key (keys %$value) {
                my @sub_value = _plain_value($value->{$sub_key});
                $sub_plain{$sub_key} = $sub_value[0] if @sub_value;
            }
            $plain{$key} = \%sub_plain;
        } else {
            my @plain_value = _plain_value($value);
            $plain{$key} = $plain_value[0] if @plain_value;
        }
    }
    my $flat = flatten(\%plain);
    return join "&", map { uri_escape($_) . "=" . uri_escape($flat->{$_} // '') } sort keys %$flat;
}

=head2 _plain_value

The value of a param that can be sent, as a list: empty when the value cannot
be sent, the value itself (undefined or plain), or a copy of an array without
its elements that are not plain values

=cut

sub _plain_value {
    my ($value) = @_;
    return ($value) if !ref $value;
    return ([grep { !ref $_ } @$value]) if ref($value) eq 'ARRAY';
    return ();
}

=head2 is_sensitive_attribute

Whether a match param holds a secret (ex: the password) that must not be sent
to the authorization API

=cut

sub is_sensitive_attribute {
    my ($name) = @_;
    return $name =~ /password|secret|passphrase|psk|otp/i ? $TRUE : $FALSE;
}

=head2 is_allowed_radius_attribute

Whether an attribute of the RADIUS request is sent to the authorization API,
see L</RADIUS ATTRIBUTES>

=cut

sub is_allowed_radius_attribute {
    my ($name) = @_;
    return ($RADIUS_ATTRIBUTES{$name} || $name =~ $RADIUS_ATTRIBUTE_PREFIXES) ? $TRUE : $FALSE;
}

=head2 authorization_params

The match parameters sent to the authorization API: the params holding a secret
(see L</is_sensitive_attribute>) are removed, and only the allowed attributes
of the RADIUS request are kept (see L</is_allowed_radius_attribute>).

=cut

sub authorization_params {
    my ($params) = @_;
    my %params = map { $_ => $params->{$_} } grep { !is_sensitive_attribute($_) } keys %$params;
    my $radius_request = $params{radius_request};
    if (ref($radius_request) eq 'HASH') {
        $params{radius_request} = {
            map { $_ => $radius_request->{$_} } grep { is_allowed_radius_attribute($_) } keys %$radius_request
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

result should be 1 (or true) for success, 0 (or false) for failure. Any
other value, like "false", "0.0", an array or an object, is a failure.
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

=head2 is_success_result

Whether the result of an authentication reply is a success: a JSON true, the
number 1, or the string "1" or "true". Anything else is a failure.

=cut

sub is_success_result {
    my ($result) = @_;
    return $FALSE if !defined $result;
    return $result ? $TRUE : $FALSE if JSON::MaybeXS::is_bool($result);
    return $FALSE if ref $result;
    return ($result eq '1' || $result eq 'true') ? $TRUE : $FALSE;
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
    if (is_success_result($result->{result})) {
        get_logger->info( "Authentication valid with $username in custom source");
        return ( $TRUE, $result->{message} );
    }
    $result->{message} //= "Authentication failed";
    get_logger->info( "Authentication invalid with $username in custom source. Error is : " . $result->{message} );
    return ( $FALSE, $result->{message} );
}

=head2 match

The HTTPSource class overrides the match method of the Source parent class.

The actions are defined by the API through its JSON response. All the
match parameters (username, mac, SSID, rule_class, ...) are sent in the
request body, see L</encode_request>. The attributes of the RADIUS request are
sent as C<radius_request.Attribute-Name> (ex: radius_request.TLS-Client-Cert-Common-Name)
in a URL-encoded body, or in the C<radius_request> object of a JSON body. Only
the attributes listed in L</RADIUS ATTRIBUTES> are sent.

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
