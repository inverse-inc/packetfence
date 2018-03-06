package pf::UnifiedApi::Controller::Locationlogs;

=head1 NAME

pf::UnifiedApi::Controller::Locationlogs -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Locationlogs

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::Crud';
use pf::dal::locationlog;
use pf::SQL::Abstract;
use pf::error qw(is_error);

has dal => 'pf::dal::locationlog';
has url_param_name => 'locationlog_id';
has primary_key => 'id';

sub search {
    my ($self) = @_;
    my ($status, $query_info) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $query_info, status => $status);
    }

    my $where = $self->make_where($query_info);

    if (!defined $where) {
        return;
    }

    ($status, my $iter) = $self->dal->search(
        -with_class => undef,
        -where => $where,
    );

    return $self->render(json => {items => $iter->all()}, status => $status);
}

sub make_where {
    my ($self, $query_info) = @_;
    my $query = $query_info->{query};
    if (!defined $query) {
        return {};
    }

    my $where = searchQueryToSqlAbstract($query);
    return $where;
}

our %OP_TO_SQL_OP = (
    equals              => '=',
    not_equals          => '!=',
    greater_than        => '>',
    less_than           => '<',
    greater_than_equals => '>=',
    less_than_equals    => '<=',
    between             => '-between',
    contains            => '-like',
    ends_with           => '-like',
    starts_with         => '-like',
);

our %OP_TO_HANDLER = (
    (
        map { $_ => \&standard_query_to_sql} qw(equals not_equals greater_than less_than greater_than_equals less_than_equals)
    ),
    between => sub {
        my ($q) = @_;
        return { $q->{field} => { "-between" => $q->{values} } };
    },
    contains => sub {
        my ($q) = @_;
        return { $q->{field} => { "-like" => '%' . $q->{value} . '%' } };
    },
    ends_with => sub {
        my ($q) = @_;
        return { $q->{field} => { "-like" => '%' . $q->{value} } };
    },
    starts_with => sub {
        my ($q) = @_;
        return { $q->{field} => { "-like" => $q->{value} . '%' } };
    },
    and => sub {
        my ($q) = @_;
        local $_;
        my @sub_queries =
          map { searchQueryToSqlAbstract($_) } @{ $q->{values} };
        if ( @sub_queries == 1 ) {
            return $sub_queries[0];
        }
        return { '-and' => \@sub_queries };
    },
    or => sub {
        my ($q) = @_;
        local $_;
        my @sub_queries =
          map { searchQueryToSqlAbstract($_) } @{ $q->{values} };
        if ( @sub_queries == 1 ) {
            return $sub_queries[0];
        }
        return { '-or' => \@sub_queries };
    }
);

sub standard_query_to_sql {
    my ($q) = @_;
    return { $q->{field} => { $OP_TO_SQL_OP{ $q->{op} } => $q->{value} } };
}

sub searchQueryToSqlAbstract {
    my ($query) = @_;
    my $op = $query->{op};
    if (exists $OP_TO_HANDLER{$op} ) {
        return $OP_TO_HANDLER{$op}->($query);
    }

    return "die unsupported op $op"
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

