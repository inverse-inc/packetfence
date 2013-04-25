package pfappserver::Model::Config::Rules;
=head1 NAME

pfappserver::Model::Config::Rules add documentation

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Rules

=cut

use Moose;
use namespace::autoclean;
use pf::authentication;
use HTTP::Status qw(:constants is_error is_success);

extends 'pfappserver::Base::Model::Config::Group';

has '+idKey' => (default => 'rule_id');

has '+itemsKey' => (default => 'rules');

=head2 Methods

=over

=item _buildCachedConfig

=cut

sub _buildCachedConfig { $pf::authentication::cached_authentication_config }

__PACKAGE__->meta->make_immutable;


=back

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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

