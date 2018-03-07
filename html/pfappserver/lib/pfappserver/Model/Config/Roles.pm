package pfappserver::Model::Config::Roles;

=head1 NAME

pfappserver::Model::Config::Roles

=cut

=head1 DESCRIPTION

Model for the roles from roles.conf

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use pf::config;
use pf::ConfigStore::Roles;
use pf::nodecategory;
use pf::log;
use pf::generate_filter qw(generate_filter);

extends 'pfappserver::Base::Model::Config';


sub _buildConfigStore { pf::ConfigStore::Roles->new }

=head2 Methods

=over

=item search

=cut

sub search {
    my ($self, $query) = @_;
    my ($status, $ids) = $self->readAllIds;
    my ($pageNum, $perPage, $searches) = @{$query}{qw(page_num per_page searches)};
    $pageNum //= 1;
    $perPage //= 25;
    $searches //= [];
    my $has_next_page;
    my $filter = $self->makeFilter($searches);
    my $offset = ($pageNum - 1) * 25;
    my $idKey = $self->idKey;
    my $items = $self->configStore->filter_offset_limit($filter, $offset, $perPage + 1, $idKey);
    if (@$items > $perPage) {
        pop @$items;
        $has_next_page = 1;
    }
    if (@$items == 0) {
        return ($STATUS::NOT_FOUND, "No matching roles found");
    }
    my $itemsKey = $self->itemsKey;

    return (
        $STATUS::OK,
        {
            $itemsKey  => $items,
            page_num   => $pageNum,
            per_page   => $perPage,
            itemsKey   => $itemsKey,
            has_next_page => $has_next_page,
        }
    );
}

sub true_filter { 1 }

sub makeFilter {
    my ($self, $searches) = @_;
    my $filter;
    if (@$searches) {
        $filter = generate_filter(@{$searches->[0]}{qw(op name value)}) // \&true_filter;
    }
    else {
        $filter = \&true_filter;
    }
    return $filter;
}

=head2 listFromDB

List the roles from the database

=cut

sub listFromDB {
    my ( $self ) = @_;

    my $logger = get_logger();
    my ($status, $status_msg);

    my @categories;
    eval {
        @categories = nodecategory_view_all();
    };
    if ($@) {
        $status_msg = "Can't fetch node categories from database.";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    return ($STATUS::OK, \@categories);
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

=back

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
