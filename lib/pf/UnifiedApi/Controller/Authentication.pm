package pf::UnifiedApi::Controller::Authentication;

=head1 NAME

pf::UnifiedApi::Controller::Authentication -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Authentication

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller';
use pf::error qw(is_error);
use pf::authentication;
use pf::Authentication::constants qw($LOGIN_SUCCESS);

sub adminAuthentication {
    my ($self) = @_;
    
    my ($status, $json) = $self->parse_json;
    if (is_error($status)) {
        $self->render(status => $status, json => $json);
    }

    my ($result, $roles, $tenant_id) = pf::authentication::adminAuthentication($json->{username}, $json->{password});

    if($result == $LOGIN_SUCCESS) {
        $self->render(status => 200, json => { result => $result, roles => $roles, tenant_id => int($tenant_id) });
    }
    else {
        $self->render(status => 401, json => { result => $result, message => "Authentication failed." })
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

