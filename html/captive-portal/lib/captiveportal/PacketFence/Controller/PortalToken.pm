package captiveportal::PacketFence::Controller::PortalToken;

use Moose;
use pf::CHI;

BEGIN { extends 'captiveportal::Base::Controller'; }


=head1 NAME

captiveportal::PacketFence::Controller::PortalToken - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub cache { return pf::CHI->new(namespace => 'portaladmin'); }

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $actions;
    if (my $uuid = $c->request->param('token')) {
        $actions = cache->get($uuid);
        if (!defined($actions)) {
            $c->response->status(404);
            $c->response->body('{ "access_level" => "none" }');
            $c->response->content_type("application/json");
        }
    } else {
        $c->response->status(404);
        $c->response->content_type("application/json");
        $c->response->body('{ "access_level" => "none" }');
    }
    $c->stash(
        current_view     => 'JSON',
        json_content     => $actions,
    );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
