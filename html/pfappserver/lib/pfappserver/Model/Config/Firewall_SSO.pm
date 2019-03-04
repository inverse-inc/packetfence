package pfappserver::Model::Config::Firewall_SSO;

=head1 NAME

pfappserver::Model::Config::Firewall_SSO add documentation

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Firewall_SSO

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use pf::config;
use pf::ConfigStore::Firewall_SSO;

extends 'pfappserver::Base::Model::Config';


sub _buildConfigStore { pf::ConfigStore::Firewall_SSO->new }

=head2 Methods

=over

=item search

=cut

sub search {
    my ($self, $field, $value) = @_;
    my @results = $self->configStore->search($field, $value);
    if (@results) {
        return ($STATUS::OK, \@results);
    } else {
        return ($STATUS::NOT_FOUND,["[_1] matching [_2] not found"],$field,$value);
    }
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

=back

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

