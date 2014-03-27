package pf::WebAPI::MsgPack;
=head1 NAME

pf::WebAPI::MsgPack add documentation

=cut

=head1 DESCRIPTION

pf::WebAPI::MsgPack

=cut

use strict;
use warnings;
use Data::MessagePack;
use Log::Log4perl;
use base qw(Class::Accessor);
use Apache2::RequestIO ();
use Apache2::RequestRec;
use Apache2::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED HTTP_NOT_IMPLEMENTED HTTP_UNSUPPORTED_MEDIA_TYPE);
__PACKAGE__->mk_accessors(qw(dispatch_to));

sub handler {
    my $logger = Log::Log4perl->get_logger('pf::WebAPI');
    use bytes;
    my ($self,$r) = @_;
    my $content_type = $r->headers_in->{'Content-Type'};
    return Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE unless ($content_type eq 'application/x-msgpack');
    my $content = '';
    my $offset = 0;
    my $cnt = 0;
    do {
        $cnt = $r->read($content,8192,$offset);
        $offset += $cnt;
    } while($cnt == 8192);
    my $data = Data::MessagePack->unpack($content);
    return Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE unless ref($data) eq 'ARRAY' && @$data == 4;
    my ($type, $msgid, $method, $params) = @$data;
    return Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE unless $type == 0;
    my $dispatch_to = $self->dispatch_to;
    return Apache2::Const::HTTP_NOT_IMPLEMENTED unless $dispatch_to->can($method);
    my $response = [];
    eval {
        my @results = $dispatch_to->$method(@$params);
        $response = [1,$msgid,undef,\@results];
    };
    if($@) {
        $response = [1,$msgid,["$@"],undef];
    }
    $r->content_type('application/x-msgpack');
    $content = Data::MessagePack->pack($response);
    $r->print($content);
    return Apache2::Const::OK;
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

