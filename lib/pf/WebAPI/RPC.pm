package pf::WebAPI::RPC;
=head1 NAME

pf::WebAPI::RPC add documentation

=cut

=head1 DESCRIPTION

pf::WebAPI::RPC

=cut

use strict;
use warnings;
use Log::Log4perl;
use List::MoreUtils qw(any);
use Apache2::RequestIO();
use Apache2::RequestRec();
use Apache2::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED HTTP_NOT_IMPLEMENTED HTTP_UNSUPPORTED_MEDIA_TYPE HTTP_NO_CONTENT HTTP_NOT_FOUND);
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(dispatch_to));
use constant REQUEST => 0;
use constant NOTIFICATION => 2;
use constant BULK => 3;

sub allowed {
    my ($self,$content_type) = @_;
    return any { $content_type eq $_ } $self->allowed_content_types;
}

sub default_content_type { }

sub allowed_content_types { ($_[0]->default_content_type ) }

sub handler {
    my $logger = Log::Log4perl->get_logger('pf::WebAPI');
    use bytes;
    my ($self,$r) = @_;
    my $content_type = $r->headers_in->{'Content-Type'};
    return Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE unless $self->allowed($content_type);
    my ($requestType,$method,$args,$id) = $self->parseRequest($r);
    return $self->handleBulkRequest($r,$args) if $requestType == BULK;
    my $methodSub = $self->lookupMethod($r,$method);
    return $self->handleMethodNotFound($r) unless $methodSub;
    return $self->handleRequest($r,$methodSub,$args,$id) if $requestType == REQUEST;
    return $self->handleNotification($r,$methodSub,$args,$id) if $requestType == NOTIFICATION;
    return $self->handleUnknownRequestType($r,$methodSub,$args,$id);
}

sub handleBulkRequest {
    return Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE;
}

sub handleUnknownRequestType {
    return Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE;
}

sub lookupMethod {
    my ($self,$r,$method) = @_;
    return $self->dispatch_to->can($method);
}

sub encode {
    my ($self,$data) = @_;
    return $self->encoder->encode($data);
}

sub decode {
    my ($self,$data) = @_;
    return $self->decoder->decode($$data);
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
