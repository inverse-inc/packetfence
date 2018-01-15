package pfappserver::PacketFence::Controller::OAuth2;

=head1 NAME

pfappserver::PacketFence::Controller::OAuth2 - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use JSON::MaybeXS;
use Moose;
use pf::error;




BEGIN { extends 'pfappserver::Base::Controller'; }

__PACKAGE__->config();

=head1 SUBROUTINES

=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
}


=head2 callback

=cut

sub callback :Local :AdminRole('OAUTH2') {
    my ($self, $c) = @_;
    $c->response->header("Content-Type" => "application/json");
    $c->response->body(encode_json($c->request->query_params));
    $c->response->status($STATUS::OK);
    $c->detach();
}


=head2 passthru

=cut

sub passthru :Local :AdminRole('OAUTH2') {
    my ($self, $c) = @_;
    my $ua = LWP::UserAgent->new();
    $ua->timeout(3);
    $c->stash->{request_method} = $c->request->method;
    if ($c->request->method eq 'POST') {
        my $host = 'http://httpbin.org/post';
        if($c->request->headers->header('X-Oauth2-Uri')) {
            $host = $c->request->headers->header('X-Oauth2-Uri');
        }
        my $response = $ua->post($host, $c->request->body_parameters);
        if ( $response->is_success ) {
            $c->response->header('Content-Type' => $response->headers->header('Content-Type'));
            $c->response->body($response->content());
            $c->response->status($response->code());
            $c->detach();
        }        
    } 
    my ($status);
    $status = $STATUS::BAD_REQUEST;
    $c->response->body('false');
    $c->response->status($status);
}



=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
