package pf::UnifiedApi::Search::Builder::Fingerbank;

=head1 NAME

pf::UnifiedApi::Search::Builder -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Search::Builder

=cut

use strict;
use warnings;
use Moo;
use SQL::Abstract;
use pf::UnifiedApi::Search;
use fingerbank::DB_Factory;
use pf::error qw(is_error);

our %OP_HAS_SUBQUERIES = (
    'and' => 1,
    'or' => 1,
);


=head2 $self->search($search_info)

Search using search_info

    my ($http_status, $search_result_or_error) = $self->search({
        'model' => 'fingerbanl::Model',
        'scope'  => 'Scope',
        'schema' => $schema,
        'cursor' => '1',
        'limit' => 25,
        'query' => {},
        'fields' => [...],
        'sort' => [...]
    });

model    The Model of the fingerbank

schema   The schema of the fingerbank

scope     Scope of the query (All/Upstream/Local)

cursor The cursor of the where start search. (Optional)

limit  The maximum items to return

query  The query object to use for searching

fields An array of fields to return

sort   An array of the sort order for the search

=cut


sub search {
    my ($self, $search_info) = @_;
    my ($status, $search_args) = $self->make_search_args($search_info);
    if ( is_error($status) ) {
        return $status, $search_args;
    }

    my $model = $search_info->{model};
    my $limit = $search_args->{'-limit'};
    my $offset = $search_args->{'-offset'};
    #use Data::Dumper;print Dumper($search_args);
    ($status, my $resultsets) = $model->search(
        [
            $search_args->{'-where'} // {},
            {
                rows => $limit,
                order_by => $search_args->{'-order_by'},
                offset => $offset,
                columns => $search_args->{'-columns'},
            }
        ],
        $search_info->{scope}
    );
    my @items;
    if (is_error($status)) {
        if ($status != 404) {
            return $status, { msg => $resultsets };
        }

        $status = 200;
    } else {
        for my $resultset (@$resultsets) {
             while (my $row = $resultset->next) {
                 my %array_row = %{$row->{'_column_data'}};
                 push ( @items, \%array_row );
             }
        }
    }
    my $nextCursor = undef;
    if ( @items == $limit ) {
        pop @items;
        $nextCursor = $offset + $limit - 1;
    }

    return 200, {
        prevCursor => $offset,
        ( defined $nextCursor ? ( nextCursor => $nextCursor ) : () ),
        items => \@items,
        scope => $search_info->{scope},
    };
}

=head2 $self->make_search_args($search_info)

Make the search args from the search_info

    my ($http_status, $search_args_or_error) = $self->make_search_args($search_info);

=cut

sub make_search_args {
    my ($self, $search_info) = @_;

    $search_info->{found_fields} = [];
    my ($status, $columns) = $self->make_columns($search_info);
    if (is_error($status)) {
        return $status, $columns;
    }

    ($status, my $where) = $self->make_where($search_info);
    if (is_error($status)) {
        return $status, $where;
    }

    ($status, my $order_by) = $self->make_order_by($search_info);
    if (is_error($status)) {
        return $status, $order_by;
    }

    my $offset   = $self->make_offset($search_info);
    my $limit    = $self->make_limit($search_info);
    my %search_args = (
        -with_class => undef,
        -where      => $where,
        -limit      => $limit,
        -offset     => $offset,
        -order_by   => $order_by,
        -columns    => $columns,
    );

    return 200, \%search_args;
}

=head2 $self->make_offset($search_info)

Make the offset based off the search_info

    my $offset = $self->make_offset($search_info)

=cut

sub make_offset {
    my ($self, $s) = @_;
    return int($s->{'cursor'} || '0');
}

=head2 $self->make_limit($search_info)

Make the limit based off the search_info

    my $limit = $self->make_limit($search_info)

=cut

sub make_limit {
    my ($self, $s) = @_;
    my $limit = int($s->{limit} // 0) || 25;
    $limit++;
    return $limit;
}

=head2 $self->make_columns($search_info)

Make the SQL::Abstract::More columns from the search_info

    my ($http_status, $columns_or_error) = $self->make_columns($search_info);

=cut

sub make_columns {
    my ( $self, $s ) = @_;
    my $cols = $s->{fields} // [];
    my @errors = map { {msg => "$_ is an invalid field" } } grep { !$self->is_valid_field($s, $_) } @$cols;
    if (@errors) {
        return 422,
          {
            msg    => "Invalid column(s) defined",
            errors => \@errors
          };
    }

    my ($status, $error) = $self->check_for_duplicated_fields($cols);
    if (is_error($status)) {
        return $status, $error;
    }

    if (@$cols) {
        push @{$s->{found_fields}}, @$cols;
        @$cols = map { $self->format_column($s, $_) } @$cols
    } else {
        $cols = [map { $self->format_column($s, $_)} $s->{source}->columns];
    }

    return 200, $cols;
}

=head2 check_for_duplicated_fields

check_for_duplicated_fields

=cut

sub check_for_duplicated_fields {
    my ($self, $cols) = @_;
    my %found;
    my @duplicated;
    for my $col (@$cols) {
        if (++$found{$col} > 1) {
            push @duplicated, $col;
        }
    }

    if (@duplicated) {
        return 422,
          {
            msg    => "Duplicated column(s) found",
            errors => [ map { { msg => "Column $_ duplicated" } } @duplicated ],
          };
    }

    return 200, undef;
}

=head2 format_column

format_column

=cut

sub format_column {
    my ($self, $s, $c) = @_;
    if ($self->is_table_field($s, $c)) {
        #my $t = $s->{source}->name;
        return "${c}";
    }
    my $allowed_join_fields = $self->allowed_join_fields;
    my $specs = $allowed_join_fields->{$c};
    return exists $specs->{column_spec} ? $specs->{column_spec} : $c;
}

=head2 $self->allowed_join_fields()

Returns a hash of the allowed joined fields for the search builder

    my $allowed_join_fields = $self->allowed_join_fields();

This is meant to be overridden in the sub classes

Should have the following format

    {
      'jointable.fieldname' => {
          join_spec => [
              #SQL::Abstract::More join spec
          ],
      },
    }

=cut

sub allowed_join_fields { {} }

=head2 $self->is_valid_field($search_info, $field_name)

Checks if a field is valid

    my $bool = $self->is_valid_field($search_info, $field_name)

=cut

sub is_valid_field {
    my ($self, $s, $col) = @_;
    return $self->is_table_field($s, $col) || $self->is_join_field($s, $col);
}

=head2 $self->is_join_field($search_info, $field_name)

Checks if a field is a join field

    my $bool = $self->is_join_field($search_info, $field_name)

=cut

sub is_join_field {
    my ($self, $s, $f) = @_;
    return exists $self->allowed_join_fields->{$f};
}

=head2 $self->is_table_field($search_info, $field_name)

Checks if a field is a table field

    my $bool = $self->is_table_field($search_info, $field_name)

=cut

sub is_table_field {
    my ($self, $s, $f) = @_;
    return $s->{source}->has_column($f);
}

=head2 $self->verify_query($search_info, $query)

    my ($http_status, $query_or_error) = $self->verify_query($search_info, $query);

=cut

sub verify_query {
    my ($self, $s, $query) = @_;
    my $op = $query->{op} // '(null)';
    if (!$self->is_valid_op($op)) {
        return 422, {msg => "$op is not valid"};
    }

    if (exists $OP_HAS_SUBQUERIES{$op}) {
        for my $q (@{$query->{values} // []}) {
            my ($status, $query) = $self->verify_query($s, $q);
            if (is_error($status)) {
                return $status, $query;
            }
        }
    } else {
        my $field = $query->{field};
        if ( !$self->is_valid_query($s, $query)) {
            return 422, {msg => "$field is an invalid field"};
        }

        push @{$s->{found_fields}}, $field;
        (my $status, $query) = $self->rewrite_query($s, $query);
        if (is_error($status)) {
            return $status, $query;
        }
    }

    return (200, $query);
}

=head2 rewrite_query

rewrite_query

=cut

sub rewrite_query {
    my ($self, $s, $query) = @_;
    my $f = $query->{field};
    my $status = 200;
    if ($self->is_table_field($s, $f)) {
        $query->{field} = $f;
    } elsif ($self->is_field_rewritable($s, $f)) {
        my $allowed = $self->allowed_join_fields;
        my $cb = $allowed->{$f}{rewrite_query};
        ($status, $query) = $self->$cb($s, $query);
    }

    return ($status, $query);
}


=head2 is_field_rewritable

is_field_rewritable

=cut

sub is_field_rewritable {
    my ($self, $s, $f) = @_;
    return exists $self->allowed_join_fields->{$f}{rewrite_query};
}


=head2 $self->is_valid_query($search_info, $query)

Checks if a query is a valid query

    my $bool = $self->is_valid_query($search_info, $query)

=cut

sub is_valid_query {
    my ($self, $s, $q) = @_;
    return $self->is_valid_field($s, $q->{field});
}

=head2 $self->is_valid_op($search_info, $op)

Checks if a query is a valid query

    my $bool = $self->is_valid_op($search_info, $op)

=cut

sub is_valid_op {
    my ($self, $op) = @_;
    return pf::UnifiedApi::Search::valid_op($op);
}

=head2 $self->make_where($search_info)

Makes the SQL::Abstract::More where clause from the search_info

    my ($http_status, $where_or_error) = $self->make_where($search_info)

=cut

sub make_where {
    my ($self, $s) = @_;
    my $query = $s->{query};
    my $where;
    if (defined $query) {
        (my $status, $query) = $self->verify_query($s, $query);
        if (is_error($status)) {
            return $status, $query;
        }
        $where = pf::UnifiedApi::Search::searchQueryToSqlAbstract($query);
    }

    return 200, $where;
}

=head2 $self->make_order_by($search_info)

Makes the SQL::Abstract::More order by clause from the search_info

    my ($status, $order_by_or_error) = $self->make_order_by($search_info)

=cut

sub make_order_by {
    my ($self, $s) = @_;
    my $sort = $s->{sort} // [];
    my @errors;
    my @order_by_specs;
    for my $sort_spec (@$sort) {
        my $order_by = $self->normalize_order_by($s, $sort_spec);
        if (defined $order_by) {
            push @order_by_specs, $order_by;
        } else {
            push @errors, {msg => "$sort_spec is invalid"};
        }
    }

    if (@errors) {
        return 422, { msg => 'Invalid field(s) in sort', errors => \@errors};
    }

    return 200, \@order_by_specs;
}

=head2 $self->normalize_order_by($order_by_field)

Normalize a sort field to the SQL::Abstract::More order by spec

    my $order_by_spec_or_undef = $self->normalize_order_by($order_by_field)

=cut

sub normalize_order_by {
    my ($self, $s, $order_by) = @_;
    my $direction = '-asc';
    if ($order_by =~ /^([^ ]+) (DESC|ASC)$/i ) {
       $order_by = $1;
       $direction = "-" . lc($2);
    }

    if (!$self->is_valid_field($s, $order_by)) {
        return undef;
    }

    if ($order_by =~ /\./) {
        $order_by = \"`$order_by`";
    }

    return { $direction => $order_by }
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
