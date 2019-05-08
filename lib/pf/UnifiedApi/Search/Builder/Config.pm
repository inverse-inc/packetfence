package pf::UnifiedApi::Search::Builder::Config;

=head1 NAME

pf::UnifiedApi::Search::Builder::Config -

=head1 DESCRIPTION

pf::UnifiedApi::Search::Builder::Config

=cut

use strict;
use warnings;
use Moo;
use pf::factory::condition;
use pf::util qw(mcmp make_string_rcmp make_string_cmp);
use pf::generate_filter qw(filter_with_offset_limit);
use pf::error qw(is_error);

our %OP_TO_CONDITION = (
    'equals'     => 'pf::condition::equals',
    'not_equals' => 'pf::condition::not_equals',
    'not'        => 'pf::condition::not',
    'and'        => 'pf::condition::all',
    'or'         => 'pf::condition::any',
    'contains'   => 'pf::condition::matches',
    'ends_with'   => 'pf::condition::ends_with',
    'starts_with'   => 'pf::condition::starts_with',
);

our %LOGICAL_OPS = (
    'and' => 1,
    'or'  => 1,
);

sub search {
    my ($self, $search_info) = @_;
    my ($status, $search_args) = $self->make_search_args($search_info);
    if (is_error($status)) {
        return $status, $search_args;
    }

    my $configStore = $search_info->{configStore};
    my $condition = $search_args->{condition};
    my @items = $configStore->filter(sub { $condition->match($_[0]) }, 'id');
    my $cmps = $search_args->{cmps};
    if ($cmps) {
        @items = sort { mcmp($a, $b, $cmps) } @items;
    }

    my $count = scalar @items;
    my $cursor = $search_info->{cursor} // 0;
    my $nextCursor;
    my $limit = $search_info->{limit} || 25;
    if ($cursor > 0) {
        splice(@items, 0, $cursor);
    }

    if (@items > $limit) {
        $nextCursor = $cursor + $limit;
        splice(@items, $limit);
    }

    return $status,
      {
        prevCursor  => $cursor,
        items       => \@items,
        total_count => $count,
        ( defined $nextCursor ? ( nextCursor => $nextCursor ) : () ),
      };
}

=head2 make_search_args

make_search_args

=cut

sub make_search_args {
    my ($self, $search_info) = @_;
    my %args = (
        condition => $self->make_condition($search_info),
        cmps      => $self->make_sort_cmps($search_info),
    );
    return 200, \%args;
}

=head2 make_sort_cmps

make_sort_cmps

=cut

sub make_sort_cmps {
    my ($self, $search_info) = @_;
    my $sort = $search_info->{sort} // [];
    if (@$sort == 0) {
        return undef;
    }

    return [
        map {
            $_->{dir} eq 'desc'
              ? make_string_rcmp($_->{field})
              : make_string_cmp($_->{field})
        } @$sort
    ];
}

=head2 make_condition

make_condition

=cut

sub make_condition {
    my ($self, $search) = @_;
    my $query = $search->{query};
    if (!defined $query) {
        return pf::condition::true->new;
    }

    return $self->query_to_condition($search, $query);
}

=head2 query_to_condition

query_to_condition

=cut

sub query_to_condition {
    my ($self, $search, $query) = @_;
    my $op = lc($query->{op});
    if (!exists $OP_TO_CONDITION{$op}) {
        die "$op is an invalid op";
    }

    my $condition = $OP_TO_CONDITION{$op};
    if ($LOGICAL_OPS{$op}) {
        my @conditions = map { $self->query_to_condition($search, $_) } @{$query->{values}};
        if (@conditions == 1) {
            return $conditions[0];
        }

        return $condition->new({ conditions => \@conditions });
    }

    if ($op eq 'not') {
        return $condition->new({
            condition => $self->query_to_condition( $search, $query->{value} )
        });
    }

    return pf::condition::key->new({
        key       => $query->{field},
        condition => $condition->new( { value => $query->{value} } )
    });
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
