package pf::WebAPI::JSONRPC;
=head1 NAME

pf::WebAPI::JSONRPC - jsonrpc apache handler

=cut

=head1 DESCRIPTION

pf::WebAPI::JSONRPC

=cut

use strict;
use warnings;
use JSON::XS;
use pf::log;
use Apache2::RequestIO();
use Apache2::RequestRec();
use Apache2::Response ();
use Apache2::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED HTTP_NOT_IMPLEMENTED HTTP_UNSUPPORTED_MEDIA_TYPE HTTP_PRECONDITION_FAILED HTTP_NO_CONTENT HTTP_NOT_FOUND SERVER_ERROR HTTP_OK HTTP_INTERNAL_SERVER_ERROR);
use List::MoreUtils qw(any);
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(dispatch_to));

our $JSONRPC_ERROR_CODE_NOT_FOUND     = -32601;
our $JSONRPC_ERROR_CODE_GENERIC_ERROR = -32000;

our %ALLOW_CONTENT_TYPE = (
    'application/json-rpc' => undef,
    'application/json' => undef,
    'application/jsonrequest' => undef,
);

sub allowed { return exists $ALLOW_CONTENT_TYPE{$_[0]} }

sub handler {
    my $logger = get_logger;
    use bytes;
    my ($self,$r) = @_;
    my $content_type = $r->headers_in->{'Content-Type'};
    return Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE unless allowed($content_type);
    my $content = '';
    my $offset = 0;
    my $cnt = 0;
    do {
        $cnt = $r->read($content,8192,$offset);
        $offset += $cnt;
    } while($cnt == 8192);
    my $data = decode_json $content;
    my $ref_type = ref($data);
    return Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE unless $ref_type;
    #for now not supporting batch
    return Apache2::Const::HTTP_NOT_IMPLEMENTED if $ref_type eq 'ARRAY';
    my ($method,$id,$jsonrpc) = @{$data}{qw(method id jsonrpc)};
    return Apache2::Const::HTTP_NOT_IMPLEMENTED  unless defined $method;
    my ($response, $status_code, $method_sub, @args);
    my $dispatch_to = $self->dispatch_to;
    if(exists $data->{'params'} ) {
        my $params = $data->{'params'};
        if (ref ($params) eq 'ARRAY' ) {
            @args = @$params;
        } else {
            @args = ($params);
        }
    }
    unless ($method_sub = $dispatch_to->isPublic($method)) {
        $r->print(
            encode_json({
                (defined $jsonrpc ? (jsonrpc => $jsonrpc) : ()),
                (defined $id      ? (id      => $id)      : ()),
                error => {code => $JSONRPC_ERROR_CODE_NOT_FOUND, message => "Method not found"},
            })
        );
        $status_code = Apache2::Const::HTTP_NOT_FOUND;
    } elsif (defined $id) {
        my $response_content = '';
        eval {
            $response_content = encode_json ({
                ( defined $jsonrpc ?  (jsonrpc => $jsonrpc) : () ),
                result => [$dispatch_to->$method_sub(@args)],
                id => $id,
            });
        };
        if($@) {
            $response_content = encode_json({
                (defined $jsonrpc ? (jsonrpc => $jsonrpc) : ()),
                id => $id,
                error => {code => $JSONRPC_ERROR_CODE_GENERIC_ERROR, message => "$@"},
            });
            $logger->error($@);
            $status_code = Apache2::Const::HTTP_INTERNAL_SERVER_ERROR;
            $r->print($response_content);
        } else {
            $status_code = Apache2::Const::HTTP_OK;
        }
        $r->print($response_content);
    } else {
        $r->push_handlers(PerlCleanupHandler => sub {
            eval {
                $dispatch_to->$method(@args);
            };
            $logger->error($@) if $@;
        });
        $status_code = Apache2::Const::HTTP_NO_CONTENT;
    }
    $r->content_type($content_type);
    $r->status($status_code);
    return Apache2::Const::OK;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

