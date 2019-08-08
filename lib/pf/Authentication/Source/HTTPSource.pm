package pf::Authentication::Source::HTTPSource;

=head1 NAME

pf::Authentication::Source::HTTPSource

=head1 DESCRIPTION

=cut

use JSON::MaybeXS;
use pf::constants qw($TRUE $FALSE);
use pf::Authentication::constants;
use pf::Authentication::Action;
use pf::Authentication::Source;
use URI::Escape::XS qw(uri_escape uri_unescape);
use WWW::Curl::Easy;
use pf::log;
use Readonly;
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

=head1 METHODS

=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::Login' }

=head2 has_authentication_rules

Whether or not the source should have authentication rules

=cut

sub has_authentication_rules { $FALSE }

=head2 _post_curl

Method used to build a basic curl object

=cut

sub _post_curl {
    my ($self, $uri, $post_fields) = @_;
    my $logger = get_logger();

    $uri = $self->protocol."://".$self->host.":".$self->port."/".$uri;

    my $curl = WWW::Curl::Easy->new;
    my $request = $post_fields;

    if($self->username && $self->password){
        $curl->setopt(CURLOPT_USERNAME, $self->username);
        $curl->setopt(CURLOPT_PASSWORD, $self->password);
    }

    my $response_body = '';
    $curl->setopt(CURLOPT_POSTFIELDSIZE,length($request));
    $curl->setopt(CURLOPT_POSTFIELDS, $request);
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_DNS_USE_GLOBAL_CACHE, 0);
    $curl->setopt(CURLOPT_NOSIGNAL, 1);
    $curl->setopt(CURLOPT_URL, $uri);
    $curl->setopt(CURLOPT_SSL_VERIFYHOST, 0);
    $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0);

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

=head2 encode_params

Encodes a hash into URL/BODY parameters

=cut

sub encode_params {
    my %hash = @_;
    my @pairs;
    for my $key (keys %hash) {
        push @pairs, join "=", map { uri_escape($_) } $key, $hash{$key};
    }
    return join "&", @pairs;
}

=head2 authenticate

Whether or not the username/password combination is valid

The server should reply with two attributes in a JSON response

result should be 1 for success, 0 for failure
message should be the reason it succeeded or failed

Example JSON response :
{"result":1,"message":"Valid username and password"}

=cut

sub authenticate {
    my ( $self, $username, $password ) = @_;

    my $uri = $self->authentication_url;

    my $post_fields = encode_params(username => $username, password => $password);

    my ($curl_return_code, $response_code, $response_body, $curl) = $self->_post_curl($uri, $post_fields);
    if ($curl_return_code == 0 && $response_code == 200) {
        my $result = decode_json($response_body);
        if($result->{result}){
            get_logger->info("Authentication valid with $username in custom source");
        }
        else {
            get_logger->info("Authentication invalid with $username in custom source. Error is : ".$result->{message});
        }
        return ($result->{result}, $result->{message});
    }
    else {
        my $curl_error = $curl->errbuf;
        get_logger->error("Could get proper reply for authentication request to ".$self->host.". Server replied with $response_body. Curl error : $curl_error");
        return ($FALSE, 'Unable to contact authentication server.');
    }


}

=head2 match

The HTTPSource class overrides the match method of the Source parent class.

The actions are defined by the API through it's JSON response.

Sample JSON response, note that not all attributes are necessary, only send back what you need.
{"access_duration":"1D","access_level":"ALL","sponsor":1,"unregdate":"2030-01-01","category":"default"}

=cut

sub match {
    my ($self, $params) = @_;
    my $common_attributes = $self->common_attributes();

    my $uri = $self->authorization_url;

    my $result;
    my $post_fields = encode_params(%{$params});

    my ($curl_return_code, $response_code, $response_body, $curl) = $self->_post_curl($uri, $post_fields);
    if ($curl_return_code == 0 && $response_code == 200) {
        $result = decode_json($response_body);
    }
    else {
        my $curl_error = $curl->errbuf;
        get_logger->error("Could get proper reply for authorization request to ".$self->host.". Server replied with $response_body. Curl error : $curl_error");
        return undef;
    }

    if (!defined $result) {
        return undef;
    }

    my @actions = ();

    my $access_duration = $result->{'access_duration'};
    if (defined $access_duration) {
        push @actions, pf::Authentication::Action->new({type => $Actions::SET_ACCESS_DURATION, value => $access_duration});
    }

    my $access_level = $result->{'access_level'};
    if (defined $access_level ) {
        push @actions, pf::Authentication::Action->new({type => $Actions::SET_ACCESS_LEVEL, value => $access_level});
    }

    my $sponsor = $result->{'sponsor'};
    if (defined($sponsor) && $sponsor == 1) {
        push @actions, pf::Authentication::Action->new({type => $Actions::MARK_AS_SPONSOR, value => 1});
    }

    my $unregdate = $result->{'unregdate'};
    if (defined $unregdate) {
        push @actions, pf::Authentication::Action->new({type => $Actions::SET_UNREG_DATE, value => $unregdate});
    }

    my $category = $result->{'category'};
    if (defined $category) {
        push @actions, pf::Authentication::Action->new({type => $Actions::SET_ROLE, value => $category});
    }

    my $time_balance = $result->{'time_balance'};
    if (defined $time_balance) {
        push @actions, pf::Authentication::Action->new({type => $Actions::SET_TIME_BALANCE, value => $time_balance});
    }

    my $bandwidth_balance = $result->{'bandwidth_balance'};
    if (defined $bandwidth_balance) {
        push @actions, pf::Authentication::Action->new({type => $Actions::SET_BANDWIDTH_BALANCE, value => $bandwidth_balance});
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
