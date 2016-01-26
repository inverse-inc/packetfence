package captiveportal::PacketFence::Controller::MDM;
use Moose;
use namespace::autoclean;
use File::Slurp qw(read_file);
use JSON::MaybeXS;

BEGIN { extends 'captiveportal::Base::Controller'; }
use pf::config;
use pf::api;

__PACKAGE__->config( namespace => 'mdm', );

=head1 NAME

captiveportal::PacketFence::Controller::WirelessProfile - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub opswat_registration :Path("/central-management/endpoint/register") : Args(0) {
    my ( $self, $c ) = @_;
    my $args = decode_json(read_file($c->req->body()));
    use Data::Dumper;
    $c->log->info(Dumper($args));
    my $return = eval { pf::api->mdm_opswat_register($args) };
    if($@){
        $c->response->status(500);
        $c->response->body(encode_json({ error => $@ }));
    }
    $c->response->status(200);
    $c->response->body(encode_json($return));
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

__PACKAGE__->meta->make_immutable;

1;

