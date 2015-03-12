package pfappserver::Model::Config::Authentication;

=head1 NAME

pfappserver::Model::Config::Authentication

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Authentication

=cut

use Moose;
use namespace::autoclean;
use pf::authentication;
use HTTP::Status qw(:constants is_error is_success);
use pf::ConfigStore::Authentication;

extends 'pfappserver::Base::Model::Config';

has '+itemKey' => (default => 'source');
has '+itemsKey' => (default => 'sources');

=head1 METHODS

=head2 _buildCachedConfig

=cut

sub _buildConfigStore { pf::ConfigStore::Authentication->new ;}

=head2 readAll

Return all authentication sources except the SQL sources.

We especially don't want to allow the modification of the local SQL database.

=cut

sub readAll {
    my ($self) = @_;
    my $sql_type = pf::Authentication::Source::SQLSource->meta->get_attribute('type')->default;
    my @sources = grep { $_->{type} ne $sql_type } @pf::ConfigStore::Authentication::auth_sources;

    return ($STATUS::OK, \@sources);
}

=head2 update

=cut

sub update {
    my ($self, $id, $source_obj) = @_;
    my %not_params = (
        rules => undef,
        unique => undef,
        class => undef
    );

    # Update attributes
    my %assignments;
    foreach my $attr (grep { !exists $not_params{$_}  } map { $_->name } $source_obj->meta->get_all_attributes()) {
        $assignments{$attr} = $source_obj->$attr;
    }

    $self->SUPER::update($id, \%assignments);
}

__PACKAGE__->meta->make_immutable;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

