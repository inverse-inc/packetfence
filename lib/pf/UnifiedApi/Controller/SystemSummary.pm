package pf::UnifiedApi::Controller::SystemSummary;

=head1 NAME

pf::UnifiedApi::Controller::SystemSummary -

=head1 DESCRIPTION

pf::UnifiedApi::Controller::SystemSummary

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pf::db;
use pf::config::util qw(is_inline_configured);
use pf::version;

sub get {
    my ($self) = @_;
    return $self->render(
        json => {
           readonly_mode => db_check_readonly() ? $self->json_true : $self->json_false,
           is_inline_configured => is_inline_configured() ? $self->json_true : $self->json_false,
           version => pf::version::version_get_current(),
        }
    );

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
