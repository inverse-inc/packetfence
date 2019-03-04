package pf::WebAPI::MsgPack;
=head1 NAME

pf::WebAPI::MsgPack - msgpack rpc apache handler

=cut

=head1 DESCRIPTION

pf::WebAPI::MsgPack

=cut

use strict;
use warnings;
use Data::MessagePack;
use Data::MessagePack::Stream;
use pf::log;
use pf::util::webapi;
use Apache2::RequestIO();
use Apache2::RequestRec();
use Apache2::Response ();
use Apache2::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED HTTP_NOT_IMPLEMENTED HTTP_UNSUPPORTED_MEDIA_TYPE SERVER_ERROR HTTP_NOT_FOUND HTTP_NO_CONTENT);
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(dispatch_to));

our $MSGPACKRPC_REQUEST = 0;
our $MSGPACKRPC_RESPONSE = 1;
our $MSGPACKRPC_NOTIFICATION = 2;

sub handler {
    my $logger = get_logger();
    use bytes;
    my ($self,$r) = @_;
    my $content_type = $r->headers_in->{'Content-Type'};
    unless ($content_type eq 'application/x-msgpack') {
        $self->_set_error($r,undef,Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE,"invalid content type");
        return Apache2::Const::OK;
    }
    my $offset = 0;
    my $cnt = 0;
    my $unpacker = Data::MessagePack::Stream->new;
    while ($r->read(my $buf,8192) ) {
        $unpacker->feed($buf);
    }
    my $data = $unpacker->data if $unpacker->next;
    unless ( ref($data) eq 'ARRAY' ) {
        $self->_set_error($r,undef,Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE,"invalid content type");
        return Apache2::Const::OK;
    }
    my $argCount = @$data;
    if ($data->[0] == $MSGPACKRPC_REQUEST ) {
        my $status_code = Apache2::Const::OK;
        my ($type, $msgid, $method, $params) = @$data;
        pf::util::webapi::add_mac_to_log_context($params);
        my $dispatch_to = $self->dispatch_to;
        unless ($dispatch_to->isPublic($method)) {
            $self->_set_error($r,$msgid,Apache2::Const::HTTP_NOT_FOUND,"$method not found");
            return Apache2::Const::OK;
        }
        my $response = [];
        eval {
            my @results = $dispatch_to->$method(@$params);
            #The response message is a four elements array shown below, packed by MessagePack format
            #[type, msgid, error, result]
            $response = [$MSGPACKRPC_RESPONSE,$msgid,undef,\@results];
        };
        if($@) {
            my $error = $@;
            $logger->error($error);
            $self->_set_error($r,$msgid,Apache2::Const::SERVER_ERROR,$error);
            return Apache2::Const::OK;
        }
        my $content = Data::MessagePack->pack($response);
        $r->print($content);
        $r->content_type('application/x-msgpack');
    } elsif ($data->[0] == $MSGPACKRPC_NOTIFICATION ) {
        my ($type, $method, $params) = @$data;
        pf::util::webapi::add_mac_to_log_context($params);
        #Do not return errors on notification messages
        $r->status(Apache2::Const::HTTP_NO_CONTENT);
        my $dispatch_to = $self->dispatch_to;
        if ($dispatch_to->isPublic($method)) {
            $r->push_handlers(PerlCleanupHandler => sub {
                eval {
                    $dispatch_to->$method(@$params);
                };
            });
        } else {
            $logger->error("$method not found");
        }
    } else {
        $self->_set_error($r,undef,Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE,"invalid message type");
    }
    return Apache2::Const::OK;
}

sub _set_error {
    my ($self,$r,$msgid,$status,$msg) = @_;
    get_logger->error($msg);
    #The response message is a four elements array shown below, packed by MessagePack format
    #[type, msgid, error, result]
    my $response = [$MSGPACKRPC_RESPONSE,$msgid,[$msg],undef];
    my $content = Data::MessagePack->pack($response);
    $r->content_type('application/x-msgpack');
    $r->status($status);
    $r->print($content);
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

