package pfappserver::Model::Config::Switch;

=head1 NAME

pfappserver::Model::Config::Switch add documentation

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Switch;

=cut

use Moose;
use namespace::autoclean;
use pf::util qw(calc_page_count);
use pf::config qw(
    $ALWAYS
    $PORT
    $SSID
    $PORT
    $MAC
);
use pf::ConfigStore::Switch;
use HTTP::Status qw(:constants is_error is_success);

extends 'pfappserver::Base::Model::Config';

sub _buildConfigStore {return pf::ConfigStore::Switch->new;}

=head1 METHODS

=head2 remove

Delete an existing item

=cut

sub remove {
    my ($self,$id) = @_;
    if($id eq 'all') {
        return ($STATUS::INTERNAL_SERVER_ERROR, "Cannot delete this item");
    }
    return $self->SUPER::remove($id);
}

our %QUERY_METHOD_LOOKUP = (
    equal => \&equal_query,
    not_equal => \&not_equal_query,
    starts_with => \&starts_with_query,
    ends_with => \&ends_with_query,
    like => \&like_query,
);

sub equal_query {
    my ($self,$searchQuery,$entry) = @_;
    my $name = $searchQuery->{name};
    return $entry->{$name} eq $searchQuery->{value};
}

sub not_equal_query {
    my ($self,$searchQuery,$entry) = @_;
    my $name = $searchQuery->{name};
    return $entry->{$name} ne $searchQuery->{value};
}

sub starts_with_query {
    my ($self,$searchQuery,$entry) = @_;
    my $name = $searchQuery->{name};
    my $value = $searchQuery->{value};
    return $entry->{$name} =~ /^\Q$value\E/;
}

sub ends_with_query {
    my ($self,$searchQuery,$entry) = @_;
    my $name = $searchQuery->{name};
    my $value = $searchQuery->{value};
    return $entry->{$name} =~ /\Q$value\E$/;
}

sub like_query {
    my ($self,$searchQuery,$entry) = @_;
    my $name = $searchQuery->{name};
    my $value = $searchQuery->{value};
    return $entry->{$name} =~ /\Q$value\E/;
}

sub true_query { 1 }

=head2 search

Search the config from query

=cut

sub search {
    my ($self, $query) = @_;
    my ($status, $ids) = $self->readAllIds;
    my ($pageNum, $perPage) = @{$query}{qw(page_num per_page)};
    $pageNum //= 1;
    $perPage //= 25;
    my $start        = ($pageNum - 1) * 25;
    my $end          = $start + $perPage - 1;
    my $searchEntry  = $query->{searches}->[0];
    my $searchMethod = \&true_query;
    if (defined $searchEntry->{value}) {
        $searchMethod = $QUERY_METHOD_LOOKUP{$searchEntry->{op}};
    }
    my (@items, $item);
    my $found_count = 0;
    my $idKey = $self->idKey;
    my $itemsKey = $self->itemsKey;
    foreach my $id (@$ids) {
        next unless defined ($item = $self->configStore->read($id, $idKey));
        if ( $self->$searchMethod( $searchEntry, $item ) ) {
            if ($start <= $found_count && $found_count <= $end) {
                push @items, $item;
            }
            $found_count++;
        }
    }
    my $pageCount = calc_page_count($found_count, $perPage);
    return (
        HTTP_OK,
        {
            $itemsKey  => \@items,
            page_num   => $pageNum,
            per_page   => $perPage,
            page_count => $pageCount,
            itemsKey   => $self->itemsKey
        }
    );
}




__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};


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
