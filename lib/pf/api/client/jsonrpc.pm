package pf::api::client::jsonrpc;

=head1 NAME

pf::api::client::jsonrpc

=head1 SYNOPSIS

  use pf::api::client::jsonrpc;
  my $client = pf::api::client::jsonrpc->new;
  my @args = $client->call("echo","packet","fence");


=head1 DESCRIPTION

  pf::api::client::jsonrpc is a msgpacket client over http

=cut

use strict;
use warnings;

use Log::Log4perl;
use Moo;
use JSON::XS;
extends 'pf::api::client';

=head1 Attributes

=cut

has '+content_type' => (default => sub {"application/json-rpc"});

=head1 METHODS

=head2 decode

TODO: documention

=cut

sub decode {
    my ($self,$data) = @_;
    return decode_json($$data);
}

sub extractValues {
    my ($self,$response) = @_;
    return @{$response->{result}};
}


=head2 build_request

  builds the jsonrpc request

=cut

sub build_request {
    my ($self,$function,$args) = @_;
    my $id = $self->id;
    my $request = {method => $function, jsonrpc => '2.0', id => $id , params => $args };
    $id++;
    $self->id($id);
    return encode_json $request;
}

=head2 build_notification

  builds the jsonrpc notification request

=cut

sub build_notification {
    my ($self,$function,$args) = @_;
    my $request = {method => $function, jsonrpc => '2.0', params => $args };
    return encode_json $request;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

