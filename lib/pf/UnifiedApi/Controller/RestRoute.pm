package pf::UnifiedApi::Controller::RestRoute;

=head1 NAME

pf::UnifiedApi::Controller::RestRoute -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::RestRoute

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller';
use Mojo::Util qw(url_unescape);

sub list {
    my ($self) = @_;
    return $self->render_error(404, "Unimplemented");
}

sub resource {
    my ($self) = @_;
    return $self->render_error(404, "Unimplemented");
}

sub get {
    my ($self) = @_;
    return $self->render_error(404, "Unimplemented");
}

sub create {
    my ($self) = @_;
    return $self->render_error(404, "Unimplemented");
}

sub remove {
    my ($self) = @_;
    return $self->render_error(404, "Unimplemented");
}

sub update {
    my ($self) = @_;
    return $self->render_error(404, "Unimplemented");
}

sub replace {
    my ($self) = @_;
    return $self->render_error(404, "Unimplemented");
}

sub search {
    my ($self) = @_;
    return $self->render_error(404, "Unimplemented");
}

sub escape_url_param {
    my ($self, $param) = @_;
    $param = url_unescape($param);
    $param =~ s/~/\//g;
    return $param;
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

