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

sub authenticate {
    my ($self) = @_;
    
    my ($status, $json) = $self->parse_json;
    if (is_error($status)) {
        $self->render(status => $status, json => $json);
    }

    my $internal_sources = pf::authentication::getInternalAuthenticationSources();
    my ($result, $message) = pf::authentication::authenticate( { 'username' => $json->{username}, 'password' => $json->{password}, 'rule_class' => $Rules::ADMIN }, @$internal_sources );

    $status = $result ? 200 : 401;

    $self->render(status => $status, json => { result => $result, message => $message });
}

sub match {
    my ($self) = @_;

    my ($status, $json) = $self->parse_json;
    if (is_error($status)) {
        $self->render(status => $status, json => $json);
    }

    my $internal_sources = pf::authentication::getInternalAuthenticationSources();
    my $result = pf::authentication::match($source_id, { username => $user, 'rule_class' => $Rules::ADMIN }, $Actions::SET_ACCESS_LEVEL, undef, $extra);

    $status = $result ? 200 : 401;

    $self->render(status => $status, json => { result => $value, message => $message });
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

