package pfappserver::Model::Config::Fingerbank::Device;

=head1 NAME

pfappserver::Model::Config::Fingerbank::Device

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Fingerbank::Device

=cut

use fingerbank::Model::Device();
use Moose;
use namespace::autoclean;
use HTTP::Status qw(:constants :is);

extends 'pfappserver::Base::Model::Fingerbank';

has '+fingerbankModel' => ( default => 'fingerbank::Model::Device');

has '+search_fields' => ( default => sub { [qw(name)] } );

=head2 getSubDevices

Returns the sub device for a parent id

=cut

sub getSubDevices {
    my ($self, $parent_id) = @_;
    my ($status, $resultSets) = $self->fingerbankModel->search([{parent_id => $parent_id}], $self->scope);
    my @items;
    return ($status, $resultSets) if is_error($status);
    foreach my $resultSet (@$resultSets) {
        while (my $item = $resultSet->next) {
            push @items,$item;
        }
    }
    return ($status,\@items);
}


__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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
