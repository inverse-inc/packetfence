package pf::WebAPI::Sereal;
=head1 NAME

pf::WebAPI::Sereal add documentation

=cut

=head1 DESCRIPTION

pf::WebAPI::Sereal

=cut

use strict;
use warnings;
use Sereal::Encoder;
use Sereal::Decoder;
use Log::Log4perl;
use List::MoreUtils qw(any);
use Apache2::RequestIO();
use Apache2::RequestRec();
use Apache2::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED HTTP_NOT_IMPLEMENTED HTTP_UNSUPPORTED_MEDIA_TYPE HTTP_NO_CONTENT HTTP_NOT_FOUND);
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(dispatch_to));

our $encoder =  Sereal::Encoder->new( { snappy => 1 } );
our $decoder =  Sereal::Decoder->new();

sub allowed {
    my ($self,$content_type) = @_;
    return any { $content_type eq $_ } $self->allowed_content_types;
}

sub default_content_type { "application/x-sereal"  }

sub allowed_content_types { ($_[0]->default_content_type ) }

sub handler {
    my $logger = Log::Log4perl->get_logger('pf::WebAPI');
    use bytes;
    my ($self,$r) = @_;
    my $content_type = $r->headers_in->{'Content-Type'};
    return Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE unless $self->allowed($content_type);
    my $default_content_type = $self->default_content_type;
    my $content = '';
    my $offset = 0;
    my $cnt = 0;
    do {
        $cnt = $r->read($content,8192,$offset);
        $offset += $cnt;
    } while($cnt == 8192);
    my $data = $self->decode(\$content);
    return Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE unless ref($data) eq 'ARRAY';
    my $argCount = @$data;
    my $type = $data->[0];
    if ($type == 0) {
        my ($type, $msgid, $method, $params) = @$data;
        my $dispatch_to = $self->dispatch_to;
        return Apache2::Const::HTTP_NOT_FOUND unless $dispatch_to->can($method);
        my $response = [];
        eval {
            my @results = $dispatch_to->$method(@$params);
            $response = [1,$msgid,undef,\@results];
        };
        if($@) {
            $response = [1,$msgid,["$@"],undef];
        }
        $r->content_type($self->default_content_type);
        $content = $self->encode($response);
        $r->print($content);
        return Apache2::Const::OK;
    } elsif ($type == 2) {
        my ($type, $method, $params) = @$data;
        my $dispatch_to = $self->dispatch_to;
        return Apache2::Const::HTTP_NOT_FOUND unless $dispatch_to->can($method);
        $r->push_handlers(PerlCleanupHandler => sub {
            eval {
                $dispatch_to->$method(@$params);
            };
        });
        return Apache2::Const::HTTP_NO_CONTENT;
    }
    return Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE;
}

sub encode {
    my ($self,$data) = @_;
    return $encoder->encode($data);
}

sub decode {
    my ($self,$data) = @_;
    my $out;
    $decoder->decode($$data,$out);
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

