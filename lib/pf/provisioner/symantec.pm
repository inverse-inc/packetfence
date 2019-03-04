package pf::provisioner::symantec;
=head1 NAME

pf::provisioner::symantec add documentation

=cut

=head1 DESCRIPTION

pf::provisioner::symantec

=cut

use strict;
use warnings;
use pf::log;
use LWP::UserAgent;
use HTTP::Request;
use Moo;
use List::MoreUtils qw(any);
use pf::util qw(clean_mac);
use XML::Simple;
    # SOAP global error handler (mostly transport or server errors)
    # here we only log, the or on soap method calls will take care of returning

=head1 Atrributes

has username => (is => 'rw');

=head2 password

Password for symantec server

=cut

has password => (is => 'rw');

=head2 host

host of the symantec

=cut

has host => (is => 'rw');

=head2 port

Username for symantec server

=cut

has port => (is => 'rw', default => sub { 443 });

=head2 username

Username for symantec server

=cut

has proxy => (is => 'rw', lazy =>1, builder=>1);

=head2 protocol

Username for symantec server

=cut

has protocol => (is => 'rw', default => sub { "https" } );

=head2 ua

The User Agent

=cut

has ua => (is => 'rw', lazy => 1, builder => 1);

=head2 xmlParser

The xml parser

=cut

has xmlParser => (is => 'rw', lazy => 1, builder => 1);

=head2 agent_download_uri 

The URI to download the agent

=cut

has agent_download_uri => (is => 'rw');


=head2 _build_xmlParser

_build_xmlParser

=cut

sub _build_xmlParser {
    XML::Simple->new(GroupTags => { deviceList => 'device'  },ForceArray => [qw(device)]);
}

=head2 _build_ua

_build_ua

=cut

sub _build_ua {
    LWP::UserAgent->new;
}

=head2 _build_proxy

_build_proxy

=cut

sub _build_proxy {
    my ($self) = @_;
    return $self->protocol . '://' . $self->host . ":" . $self->port;
}

=head2 authorize

authorize

=cut

sub authorize {
    my ($self, $mac) = @_;
    $mac = clean_mac($mac);
    my $request  = $self->makeRequest($mac);
    my $response = $self->ua->request($request);
    if($response->is_success) {
        return $self->is_valid($response,$mac);
    }
    return 0;
}

=head2 makeRequest

makeRequest

=cut

sub makeRequest {
    my ($self,$mac) = @_;
    my $path = "/appstore/ciscoise/devices/0/macaddress/$mac/all";
    my $url  = $self->proxy . $path;
    my $request = HTTP::Request->new(GET => $url);
    $request->authorization_basic($self->username,$self->password);
    return $request;
}

=head2 is_valid

is_valid

=cut

sub is_valid {
    my ($self,$response,$mac) = @_;
    my $ise_api = $self->xmlParser->XMLin($response->content);
    my $deviceList = $ise_api->{deviceList};
    return 0 if ref ($deviceList) eq 'HASH';
    return any {
        my $m = clean_mac($_->{macaddress});
        $m && $m eq $mac && $_->{attributes}{compliance}{status} eq 'true'
    } @$deviceList;
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

1;
