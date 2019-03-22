package pf::radius::rest;

=head1 NAME

pf::radius::rest

=cut

=head1 DESCRIPTION

Helper methods to use REST with FreeRADIUS

=cut

use strict;
use warnings;

use pf::log;
use Apache2::Const -compile =>
  qw(DONE OK DECLINED HTTP_UNAUTHORIZED HTTP_FORBIDDEN HTTP_NOT_IMPLEMENTED HTTP_UNSUPPORTED_MEDIA_TYPE HTTP_PRECONDITION_FAILED HTTP_NO_CONTENT HTTP_NOT_FOUND SERVER_ERROR HTTP_OK HTTP_INTERNAL_SERVER_ERROR);
use pf::api::error;
use pf::radius::constants;

=head2 format_response

Format a PacketFence RADIUS response to the format expected by the FreeRADIUS REST module

=cut

sub format_response {
    my ($response) = @_;

    my $radius_return = shift @$response;
    my %mapped_object = @$response;
    my $radius_audit = delete $mapped_object{"RADIUS_AUDIT"} // {};
    my %audit;
    while (my ($key, $value) = each %$radius_audit) {
        $audit{"control:$key"} = $value;
    }

    %mapped_object = ( %audit, %mapped_object);

    get_logger->trace(sub { use Data::Dumper ; "RADIUS REST object : ". Dumper(\%mapped_object) });
    $response = \%mapped_object;

    $response->{'control:PacketFence-Authorization-Status'} = 'allow';

    if($radius_return == $RADIUS::RLM_MODULE_USERLOCK) {
        $response->{'control:PacketFence-Authorization-Status'} = 'deny';
        $radius_return = $RADIUS::RLM_MODULE_OK
    }

    unless ($radius_return == $RADIUS::RLM_MODULE_OK) {
        die pf::api::error->new(status => Apache2::Const::HTTP_UNAUTHORIZED, response => $response);
    }

    return $response;
}

=head2 format_request

Format a FreeRADIUS REST RADIUS request to the format PacketFence expects it

=cut

sub format_request {
    my ($request) = @_;
    # transform the request according to what radius_authorize expects
    my %remapped_radius_request = map {
        (@{$request->{$_}->{value}} > 1) ? ($_ => $request->{$_}->{value}) : ($_ => $request->{$_}->{value}[0]);
    } keys %{$request};
    return \%remapped_radius_request;
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
