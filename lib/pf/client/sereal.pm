package pf::client::sereal;

=head1 NAME

pf::client::sereal

=head1 SYNOPSIS

  use pf::client::sereal;
  my $client = pf::client::sereal->new;
  my @args = $client->call("echo","packet","fence");


=head1 DESCRIPTION

  pf::client::sereal is a msgpacket client over http

=cut

use strict;
use warnings;

use Log::Log4perl;
use WWW::Curl::Easy;
use Sereal::Encoder qw(sereal_encode_with_object);
use Sereal::Decoder qw(sereal_decode_with_object sereal_decode_with_header_with_object);
use Moo;
extends 'pf::client';
our $ENCODER =  Sereal::Encoder->new( {snappy => 1 });
our $DECODER =  Sereal::Decoder->new();


=head1 Attributes

=cut

has '+content_type' => (default => sub {"application/x-sereal"});

use constant REQUEST => 0;
use constant RESPONSE => 2;
use constant NOTIFICATION => 2;

=head1 METHODS

=head2 decode

TODO: documention

=cut

sub decode {
    my ($self,$data) = @_;
    my $response;
    sereal_decode_with_object($DECODER,$$data,$response);
    return $response;
}

sub extractValues {
    my ($self,$response) = @_;
    return @{$response->[3]};
}


=head2 build_request

  builds the sereal request

=cut

sub build_request {
    my ($self,$function,$args) = @_;
    my $id = $self->id;
    my $request = [REQUEST,$id,$function,$args];
    $id++;
    $self->id($id);
    return sereal_encode_with_object($ENCODER,$request);
}

=head2 build_notification

  builds the sereal notification request

=cut

sub build_notification {
    my ($self,$function,$args) = @_;
    my $request = [NOTIFICATION,$function,$args];
    return $ENCODER->encode($request);
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

