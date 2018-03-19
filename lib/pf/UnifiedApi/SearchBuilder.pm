package pf::UnifiedApi::SearchBuilder;

=head1 NAME

pf::UnifiedApi::SearchBuilder -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::SearchBuilder

=cut

use strict;
use warnings;
use Moo;
use pf::SQL::Abstract;
use pf::UnifiedApi::Search;
use pf::error qw(is_error);

our %OP_HAS_SUBQUERIES = (
    'and' => 1,
    'or' => 1,
);

sub search {
    my ( $self, $search_info ) = @_;
    my ($status, $search_args) = $self->make_search_args($search_info);
    if ( is_error($status) ) {
        return $status, $search_args;
    }

    ( $status, my $iter ) = $search_info->{dal}->search( %$search_args );
    if ( is_error($status) ) {
        return $status, {msg =>  "Error fulfilling search"}
    }

    my $limit = $search_args->{'-limit'};
    my $offset = $search_args->{'-offset'};
    my $items      = $iter->all();
    my $nextCursor = undef;
    if ( @$items == $limit ) {
        pop @$items;
        $nextCursor = $offset + $limit - 1;
    }

    return $status,
      {
        prevCursor => $offset,
        items      => $items,
        ( defined $nextCursor ? ( nextCursor => $nextCursor ) : () )
      }
      ;
}

sub make_search_args {
    my ($self, $search_info) = @_;
    $search_info->{found_fields} = [];
    my ($status, $columns) = $self->make_columns($search_info);
    if (is_error($status)) {
        return $status, $columns;
    }

    ($status, my $where) = $self->make_where($search_info);
    if (is_error($status, $where)) {
        return $status, $where;
    }

    ($status, my $from) = $self->make_from($search_info);
    if (is_error($status, $from)) {
        return $status, $from;
    }

    my $offset   = $self->make_offset($search_info);
    my $limit    = $self->make_limit($search_info);
    my $order_by = $self->make_order_by($search_info);
    my %search_args = (
        -with_class => undef,
        -where      => $where,
        -limit      => $limit,
        -offset     => $offset,
        -order_by   => $order_by,
        -from       => $from,
    );
    if (@$columns) {
        $search_args{'-columns'} = $columns;
    }

    return 200, \%search_args;
}

sub make_offset {
    my ($self, $s) = @_;
    return int($s->{'cursor'} || '0');
}

sub make_limit {
    my ($self, $s) = @_;
    my $limit = int($s->{limit} // 0) || 25;
    $limit++;
    return $limit;
}

sub make_from {
    my ($self, $s) = @_;
    my @from = ($s->{dal}->table);
    my @join_specs = $self->make_join_specs($s);
    if (@join_specs) {
        unshift @from, '-join';
        push @from, @join_specs;
    }

    return 200, \@from;
}

sub make_join_specs {
    my ($self, $s) = @_;
    my %found;
    my @join_specs;
    my $allow_joins = $self->allowed_join_fields;
    foreach my $f (@{$s->{found_fields} // []}) {
        if (exists $allow_joins->{$f}) {
            my $jf = $allow_joins->{$f};
            my ($namespace, undef) = split(/\./, $f, 2);
            next if exists $found{$namespace};
            $found{$namespace} = 1;
            push @join_specs, @{$jf->{join_spec} // []};
        }
    }
    return @join_specs;
}

sub make_columns {
    my ( $self, $s ) = @_;
    my $cols = $s->{fields} // [];
    my @errors = map { {msg => "$_ is an invalid field" } } grep { !$self->valid_column($s, $_) } @$cols;
    if (@errors) {
        return 422,
          {
            msg => "Invalid column(s) defined",
            errors => \@errors
          };
    }
    
    push @{$s->{found_fields}}, @$cols;
    my $t = $s->{dal}->table;
    @$cols = map { $self->is_table_field($s, $_) ? "${t}.$_" : $_ } @$cols;
    return 200, $cols;
}

=head2 allowed_join_fields

Returns a hash of the allowed joined fields for the search builder

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

sub valid_column {
    my ($self, $s, $col) = @_;
    return $self->is_table_field($s, $col) || $self->is_join_field($s, $col);
}

sub is_join_field {
    my ($self, $s, $col) = @_;
    return exists $self->allowed_join_fields->{$col};
}

sub is_table_field {
    my ($self, $s, $col) = @_;
    return exists $s->{dal}->get_meta->{$col};
}

sub verify_query {
    my ($self, $s, $query) = @_;
    my $op = $query->{op} // '(null)';
    if (!$self->is_valid_op($query)) {
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
    }

    return (200, $query);
}

sub is_valid_query {
    my ($self, $s, $q) = @_;
    return $self->valid_column($s, $q->{field});
}

sub is_valid_op {
    my ($self, $q) = @_;
    return pf::UnifiedApi::Search::valid_op($q->{op});
}

sub make_where {
    my ($self, $s) = @_;
    my $query = $s->{query};
    if (!defined $query) {
        return 200, {};
    }

    (my $status, $query) = $self->verify_query($s, $query);
    if (is_error($status)) {
        return $status, $query;
    }

    my $where = pf::UnifiedApi::Search::searchQueryToSqlAbstract($query);
    return 200, $where;
}

sub make_order_by {
    my ($self, $q) = @_;
    my $sort = $q->{sort} // [];
    local $_;
    return [map { normalize_sort($_)  } @$sort ];
}

sub normalize_sort {
    my ($order_by) = @_;
    my $direction = '-asc';
    if ($order_by =~ /^([^ ]+) (DESC|ASC)$/i ) {
       $order_by = $1;
       $direction = "-" . lc($2);
    }
    return { $direction => $order_by }
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
