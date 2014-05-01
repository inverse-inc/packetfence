package pf::WebAPI::RPC::MsgPack;
=head1 NAME

pf::WebAPI::RPC::MsgPack add documentation

=cut

=head1 DESCRIPTION

pf::WebAPI::RPC::MsgPack

=cut

use strict;
use warnings;
use Data::MessagePack;
use Log::Log4perl;
use Apache2::RequestIO();
use Apache2::RequestRec();
use Apache2::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED HTTP_NOT_IMPLEMENTED HTTP_UNSUPPORTED_MEDIA_TYPE HTTP_NO_CONTENT HTTP_NOT_FOUND);
use base qw(pf::WebAPI::RPC);
__PACKAGE__->mk_accessors(qw(dispatch_to));
use constant REQUEST => 0;
use constant NOTIFICATION => 2;
use constant BULK => 3;

our $ENCODER = Data::MessagePack->new;
our $DECODER = $ENCODER;

sub default_content_type { "application/x-msgpack"  }

sub handleRequest {
    my ($self,$r,$methodSub,$args,$id) = @_;
    my $dispatch_to = $self->dispatch_to;
    my $response = [];
    eval {
        my @results = $dispatch_to->$methodSub(@$args);
        $response = [1,$id,undef,\@results];
    };
    if($@) {
        $response = [1,$id,["$@"],undef];
    }
    $r->content_type($self->default_content_type);
    my $content = $self->encode($response);
    $r->print($content);
    return Apache2::Const::OK;
}

sub handleNotification {
    my ($self,$r,$methodSub,$args,$id) = @_;
    my $dispatch_to = $self->dispatch_to;
    $r->push_handlers(PerlCleanupHandler => sub {
        eval {
            $dispatch_to->$methodSub(@$args);
        };
    });
    return Apache2::Const::HTTP_NO_CONTENT;
}

sub handleParseError {
    return Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE;
}

sub parseRequest {
    my ($self,$r) = @_;
    my $content = '';
    my $offset = 0;
    my $cnt = 0;
    do {
        $cnt = $r->read($content,8192,$offset);
        $offset += $cnt;
    } while($cnt == 8192);
    my $logger = Log::Log4perl->get_logger('pf::WebAPI');
    my $data = $self->decode(\$content);
    return unless ref ($data) eq 'ARRAY';
    my $type = shift @$data;
    my ($method,$args,$id);
    return if $type != NOTIFICATION && $type != REQUEST;
    $id = shift @$data if $type == REQUEST;
    ($method,$args) = @$data;
    return ($type,$method,$args,$id);
}

sub encode {
    my ($self,$data) = @_;
    return $ENCODER->encode($data);
}

sub decode {
    my ($self,$data) = @_;
    return $DECODER->decode($$data);
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

