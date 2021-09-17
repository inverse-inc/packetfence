package pf::Report::abstract;

use Moose;
extends qw(pf::Report);
use pf::SQL::Abstract;
use pf::UnifiedApi::Search;
use pf::dal;
use pf::error qw(is_error is_success);
use pf::log;
use Tie::IxHash;
use List::MoreUtils qw(any);

has 'group_field' => (is => 'rw', isa => 'Str');

has 'date_field' => (is => 'rw', isa => 'Str');

has 'order_fields' => (is => 'rw', isa => 'ArrayRef[Str]');

has 'base_conditions' => (is => 'rw', isa => 'ArrayRef[HashRef]');

has 'base_conditions_operator' => (is => 'rw', isa => 'Str', default => 'all');

has 'joins' => (is => 'rw', isa => 'ArrayRef[Str]', );

has 'searches' => (is => 'rw', isa => 'ArrayRef[HashRef]');

has 'base_table' => (is => 'rw', isa => 'Str');

has 'columns' => (is => 'rw', isa => 'ArrayRef[Str]');

sub generate_sql_query {
    my ($self, %infos) = @_;
    my $logger = get_logger;

    my $sqla = SQL::Abstract::More->new();
    my $and = [];
    $infos{search}{type} //= $self->base_conditions_operator;

    # Date range handling
    push @$and, $self->date_field => { ">=", $infos{start_date}} if($infos{start_date});
    push @$and, $self->date_field => { "<=", $infos{end_date}} if($infos{end_date});

    # Search handling
    # conditions = [
    #   {
    #       field => "theField",
    #       # Following the SQL standard
    #       operator => "=",
    #       value => "thatsTheValue",
    #
    #   }
    # ]
    if ($infos{search}) {
        my $all = $infos{search}{type} eq "all" ? 1 : 0;
        my @conditions = map { $_->{field} => {$_->{operator} => $_->{value}} } @{$infos{search}{conditions}};
        if ($all) {
            $logger->debug("Matching for all conditions for the provided search");
            push @$and, [ -and => \@conditions ];
        } else {
            $logger->debug("Matching for any conditions for the provided search");
            push @$and, \@conditions;
        }
    }

    if (my $search = $infos{sql_abstract_search}) {
        $logger->debug("Adding provided SQL abstract search");
        push @$and, $search;
    }

    if (@{$self->base_conditions} > 0) {
        my $all = $self->base_conditions_operator eq "all" ? 1 : 0;
        my @conditions = map { $_->{field} => {$_->{operator} => $_->{value}} } @{$self->base_conditions};
        if($all) {
            $logger->debug("Matching for all base conditions");
            push @$and, [ -and => \@conditions ];
        }
        else {
            $logger->debug("Matching for any base conditions");
            push @$and, \@conditions;
        }
    }

    my %limit_offset = (
            -limit => $infos{sql_limit},
            -offset => $infos{offset},
    );
    my %ordering;
    if ($infos{order}) {
        %ordering = (
            -order_by => [$infos{order}, @{$self->order_fields}],
        );
    } elsif (@{$self->order_fields} > 0) {
        %ordering = (
            -order_by => $self->order_fields,
        );
    } elsif (defined($self->date_field)) {
        %ordering = (
            -order_by => ['-'.$self->date_field],
        );
    }


    # NOTE: when counting, we shouldn't group but instead count distinct so it is ignored in that case even when specified
    my %group_by;
    if ($self->group_field) {
        %group_by = (
            -group_by => [$self->group_field],
        );
    }

    my $columns = $self->columns;
    my ($sql, @params) = $sqla->select(
        -columns => $columns,
        -from => [
            -join => ($self->base_table, split(" ", join(" ", @{$self->joins}))),
        ],
        -where => [ 
            -and => [
                @$and,
            ]
        ],
        %limit_offset,
        %ordering,
        %group_by,
    );
    return ($sql, \@params);
}

sub build_query_options {
    my ($self, $infos) = @_;
    my %options;
    my $limit = ($infos->{limit} // 25) + 0;
    $options{limit} = $limit;
    $options{sql_limit} = $limit + 1;
    $options{offset} = $infos->{cursor} // 0;
    if (defined $self->date_field) {
        for my $f (qw(start_date end_date)) {
            $options{$f} = $infos->{$f};
        }
    }

    if (defined $infos->{sort}) {
        $options{order} = $infos->{sort};
    }

    if (defined $infos->{query}) {
        $options{where} = pf::UnifiedApi::Search::searchQueryToSqlAbstract($infos->{query});
    }


    return (200, \%options);
}

sub ensure_default_infos {
    my ($self, $infos) = @_;
    $infos->{page} //= 1;
    $infos->{per_page} //= 25;
    $infos->{count_only} //= 0;
}

sub nextCursor {
    my ($self, $result, %infos) = @_;
    my $limit = $infos{limit} + 1;
    my $last_item;
    if (@$result == $limit) {
        $last_item = pop @$result;
    }

    if ($last_item) {
        return ($infos{cursor} // 0) + $limit - 1;
    }

    return undef;
}

sub _db_data {
    my ($self, $sql, @params) = @_;

    my ( $ref, @array );
    my ($status, $sth) = pf::dal->db_execute($sql, @params);
    if (is_error($status)) {
        return ($status);
    }
    # Going through data as array ref and putting it in ordered hash to respect the order of the select in the final report
    my $fields = $sth->{NAME};
    while ( $ref = $sth->fetchrow_arrayref() ) {
        tie my %record, 'Tie::IxHash';
        @record{@$fields} = @$ref;
        push( @array, \%record );
    }
    $sth->finish();
    return (200, \@array);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2016-2021 Inverse inc.

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

