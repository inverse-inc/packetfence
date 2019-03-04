package pf::Authentication::Source::TwitterSource;

=head1 NAME

pf::Authentication::Source::TwitterSource

=head1 DESCRIPTION

This module implements methods for the Twitter source and the methods necessary
to perform the OAuth flow since Net::OAuth2 lacks support for Twitter OAuth.

=cut

use Moose;
use LWP;
use pf::log;
use Digest::HMAC_SHA1;
use MIME::Base64;
use CGI;

extends 'pf::Authentication::Source::OAuthSource';

has '+type' => (default => 'Twitter');
has '+class' => (default => 'external');
has 'client_id' => (isa => 'Str', is => 'rw', required => 1, default => '<CONSUMER KEY>');
has 'client_secret' => (isa => 'Str', is => 'rw', required => 1), default => '<CONSUMER SECRET>';
has 'site' => (isa => 'Str', is => 'rw', default => 'https://api.twitter.com');
has 'authorize_path' => (isa => 'Str', is => 'rw', default => '/oauth/authenticate');
has 'access_token_path' => (isa => 'Str', is => 'rw', default => '/oauth/request_token');
has 'redirect_url' => (isa => 'Str', is => 'rw', required => 1, default => 'https://<hostname>/oauth2/callback');
has 'protected_resource_url' => (isa => 'Str', is => 'rw', default => 'https://api.twitter.com/oauth/access_token');
has 'domains' => (isa => 'Str', is => 'rw', required => 1, default => '*.twitter.com,twitter.com,*.twimg.com,twimg.com');

=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::OAuth::Twitter' }


=head2 authorize

Get the URL for authorization with Twitter

=cut

sub authorize {
    my ($self) = @_;
    my $oauth_token = $self->generate_oauth_request_token();
    return $self->{site}.$self->{authorize_path}."?oauth_token=$oauth_token";
}

=head2 generate_oauth_request_token

Generates the OAuth request token for use in future 
requests through a call to the Twitter API

=cut

sub generate_oauth_request_token {
    my ($self) = @_;
    my $request_token_url = $self->{site}.$self->{access_token_path};

    my $params = {
        oauth_consumer_key => $self->{client_id},
        oauth_nonce => time,
        oauth_signature_method => "HMAC-SHA1",
        oauth_timestamp => time,
        oauth_version => "1.0"
    };

    my $qs = $self->simple_sign($request_token_url, $params);

    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new(POST => $request_token_url);
    $req->content_type('application/x-www-form-urlencoded');
    $req->content($qs);
    my $response = $ua->request($req);

    unless ($response->is_success) {
      get_logger->error("Couldn't execute request properly. Response is : ".$response->content);
      return undef;
    }

    my $dummy_url = "http://localhost?".$response->content;

    use URI;
    my $url_object = new URI($dummy_url);

    my %params = $url_object->query_form();

    my $oauth_token = $params{'oauth_token'};
    my $oauth_token_secret = $params{'oauth_token_secret'};

    return $oauth_token;
}

=head2 get_access_token

Get the access token through the Twitter API using the
oauth_token + oauth_verifier

This will also return the username of the user.

=cut

sub get_access_token {
    my ($self, $oauth_token, $oauth_verifier) = @_;
    my $access_token_url = $self->{protected_resource_url};

    my $params = {
      oauth_consumer_key => $self->{client_id},
      oauth_nonce => time,
      oauth_signature_method => "HMAC-SHA1",
      oauth_timestamp => time,
      oauth_version => "1.0",
      oauth_token => $oauth_token,
      oauth_verifier => $oauth_verifier,
    };

    my $qs = $self->simple_sign($access_token_url, $params);

    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new(POST => $access_token_url);
    $req->content_type('application/x-www-form-urlencoded');
    $req->content($qs);
    my $response = $ua->request($req);

    unless ($response->is_success) {
      die "Couldn't execute request properly. Response is : ".$response->content;
    }

    my $dummy_url = "http://localhost?".$response->content;
    my $url_object = new URI($dummy_url);
    my %params = $url_object->query_form();

    return {access_token => $params{'access_token'}, username => $params{'screen_name'}};
}

=head2 build_sorted_query

Will sort the parameters in a hash and put them in a
string reprensenting the parameters (param1=value1&param2=value2&)

=cut

sub build_sorted_query {
  my ($self, $input) = @_;
  my $qs;
  foreach (sort keys %$input) {
      $qs .= $_."=".$input->{$_}."&";
  }
  return substr ($qs, 0, -1);
}

=head2 simple_sign

Will sign a query so it can be sent to the Twitter API
See : L<https://dev.twitter.com/oauth/overview/creating-signatures>

=cut

sub simple_sign {
  my ($self, $url, $params) = @_;
  my $IN = new CGI;

  my $qs = $self->build_sorted_query($params);
  my $signing_key = $IN->escape($self->{client_secret})."&";
  my $signature_base = "POST&".$IN->escape($url)."&".$IN->escape($qs);

  my $hmac = Digest::HMAC_SHA1->new($signing_key);
  $hmac->add($signature_base);

  $params->{oauth_signature} = $IN->escape(encode_base64($hmac->digest));

  $qs = $self->build_sorted_query($params);

  return $qs

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
