package pfappserver::Model::Config::Domain;

=head1 NAME

pfappserver::Model::Config::Domain add documentation

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Domain

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use pf::config;
use pf::ConfigStore::Domain;
use pf::util;
use pf::domain;

extends 'pfappserver::Base::Model::Config';


sub _buildConfigStore { pf::ConfigStore::Domain->new }

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

sub status {
    my ($self, $domain) = @_;

    my $info = $self->configStore->read($domain);

    my $chroot_path = pf::domain::chroot_path($domain);
    my ($join_status, $join_output) = pf::domain::test_join($domain);

    return ($join_status, $join_output);

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
