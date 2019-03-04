package pf::WebAPI::JSONRPC;

=head1 NAME

pf::WebAPI::JSONRPC - jsonrpc apache handler

=cut

=head1 DESCRIPTION

pf::WebAPI::JSONRPC

=cut

use strict;
use warnings;
use JSON::MaybeXS;
use pf::log;
use pf::util::webapi;
use pf::dal;
use Apache2::RequestIO;
use Apache2::RequestRec;
use Apache2::Response;
use Apache2::Const -compile =>
  qw(DONE OK DECLINED HTTP_UNAUTHORIZED HTTP_NOT_IMPLEMENTED HTTP_UNSUPPORTED_MEDIA_TYPE HTTP_PRECONDITION_FAILED HTTP_NO_CONTENT HTTP_NOT_FOUND SERVER_ERROR HTTP_OK HTTP_INTERNAL_SERVER_ERROR);
use List::MoreUtils qw(any);
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(dispatch_to));

our $JSONRPC_ERROR_CODE_GENERIC_ERROR   = -32000;
our $JSONRPC_ERROR_CODE_INVALID_REQUEST = -32600;
our $JSONRPC_ERROR_CODE_NOT_FOUND       = -32601;
our $JSONRPC_ERROR_CODE_PARSE_ERROR     = -32700;

our %ALLOW_CONTENT_TYPE = (
    'application/json-rpc'    => undef,
    'application/jsonrequest' => undef,
);

our $CONTENT_TYPE = 'application/json-rpc';
our $RPC_VERSION  = "2.0";

sub allowed {return exists $ALLOW_CONTENT_TYPE{$_[0]}}

sub handler {
    my $logger = get_logger();
    use bytes;
    my ($self, $r) = @_;
    my $content = $self->get_all_content($r);
    my $content_type = $r->headers_in->{'Content-Type'} || $CONTENT_TYPE;
    my $data = eval {decode_json $content };
    if ($@) {
        my $error = $@;
        get_logger->error($error);
        return $self->send_response(
            $r,
            Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE,
            $self->make_error_object(undef, $JSONRPC_ERROR_CODE_PARSE_ERROR, "Cannot parse request\n", $error),
            $content_type,
        );
    }
    pf::dal->reset_tenant();
    my $ref_type = ref $data;
    unless ($ref_type && $ref_type eq 'HASH') {
        get_logger->error("Invalid request");
        return $self->send_response(
            $r,
            Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE,
            $self->make_error_object(undef, $JSONRPC_ERROR_CODE_INVALID_REQUEST, "Invalid request\n"),
            $content_type,
        );
    }

    my ($method, $id, $jsonrpc, $tenant_id) = @{$data}{qw(method id jsonrpc tenant_id)};
    unless (defined $method) {
        get_logger->error("Invalid request, no method defined");
        return $self->send_response(
            $r,
            Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE,
            $self->make_error_object(undef, $JSONRPC_ERROR_CODE_INVALID_REQUEST, "Invalid request, no method defined\n"),
            $content_type,
        );
    }
    if (defined $tenant_id) {
        pf::dal->set_tenant($tenant_id);
    }

    my $dispatch_to = $self->dispatch_to;
    my $response_content = '';
    my $method_sub;
    unless ( $method_sub = $dispatch_to->isPublic($method)) {
        get_logger->error("Invalid request no method defined");
        return $self->send_response(
            $r,
            Apache2::Const::HTTP_NOT_FOUND,
            $self->make_error_object(undef, $JSONRPC_ERROR_CODE_NOT_FOUND, "Method '$method' not found\n"),
            $content_type,
        );
    }
    my @args;
    if (exists $data->{'params'}) {
        my $params = $data->{'params'};
        if (ref($params) eq 'ARRAY') {
            @args = @$params;
        } else {
            @args = ($params);
        }
        pf::util::webapi::add_mac_to_log_context(\@args);
    }
    if (defined $id) {
        my $object;
        eval {
            $object = {
                (defined $jsonrpc ? (jsonrpc => $jsonrpc) : ()),
                result => [$dispatch_to->$method(@args)],
                id     => $id,
            }
        };
        if ($@) {
            my $error = $@;
            get_logger->error($error);
            return $self->send_response(
                $r,
                Apache2::Const::HTTP_INTERNAL_SERVER_ERROR,
                $self->make_error_object($id, $JSONRPC_ERROR_CODE_GENERIC_ERROR, $error),
                $content_type,
            );
        }
        return $self->send_response($r, Apache2::Const::HTTP_OK, $object, $content_type);
    }
    # Notify message defer until later
    $r->push_handlers(
        PerlCleanupHandler => sub {
            eval {$dispatch_to->$method(@args);};
            $logger->error($@) if $@;
        }
    );
    $r->content_type($content_type);
    return Apache2::Const::HTTP_NO_CONTENT;
}

sub send_response {
    my ($self, $r, $status, $object, $content_type) = @_;
    $r->custom_response($status, '');
    $r->content_type($content_type // $CONTENT_TYPE);
    $r->status($status);
    my $response_content = encode_json($object);
    $r->print($response_content);
    $r->rflush;
    return Apache2::Const::OK;
}

sub get_all_content {
    my ($self, $r) = @_;
    my $content = '';
    my $offset  = 0;
    my $cnt     = 0;
    do {
        $cnt = $r->read($content, 8192, $offset);
        $offset += $cnt;
    } while ($cnt == 8192);
    return $content;
}

sub make_error_object {
    my ($self, $id, $code, $message, $data) = @_;
    return {jsonrpc => "2.0", id => $id, error => {code => $code, message => $message}, data => $data};
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
