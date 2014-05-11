package pf::WebAPI::RPC::Sereal;
=head1 NAME

pf::WebAPI::RPC::Sereal add documentation

=cut

=head1 DESCRIPTION

pf::WebAPI::RPC::Sereal

=cut

use strict;
use warnings;
use Sereal::Encoder qw(sereal_encode_with_object);
use Sereal::Decoder qw(sereal_decode_with_object sereal_decode_with_header_with_object);
use base qw(pf::WebAPI::RPC::MsgPack);

our $ENCODER =  Sereal::Encoder->new();
our $DECODER =  Sereal::Decoder->new();

sub default_content_type { "application/x-sereal"  }


sub encode {
    my ($self,$data) = @_;
    return sereal_encode_with_object($ENCODER,$data);
}

sub decode {
    my ($self,$data) = @_;
    my $out;
    sereal_decode_with_object($DECODER,$$data,$out);
    return $out;
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

