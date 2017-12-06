package pf::UnifiedApi::Controller::TenantsOnboarding;

=head1 NAME

pf::UnifiedApi::Controller::TenantsOnboarding -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::TenantsOnboarding

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller';

use pf::tenant_code;

sub onboard {
    my ($self) = @_;
    my $data = $self->req->json;
    my $ssids = delete $data->{ssids};
    my $token = delete $data->{token};

    if (!$token) {
        return $self->render_error(422, "Missing token.");
    }

    if (!$data->{name}) {
        return $self->render_error(422, "Missing tenant name.");
    }

    my $result = pf::tenant_code->onboard($token, $data, $ssids);

    if ($result) {
        my $tenant = pf::dal::tenant->search(-where => { name => $data->{name}})->next;
        $self->res->headers->add(Location => "/api/v1/tenants/".$tenant->id);
        $self->render(json => {message => "Onboarded tenant successfully"}, status => 201);
    }
    else {
        return $self->render_error(422, "Couldn't perform onboarding of tenant. Check server-side logs for details.");
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;
