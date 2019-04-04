package pf::Report;

use Moose;
use SQL::Abstract::More;
use pf::dal;
use pf::error qw(is_error is_success);
use pf::log;
use Tie::IxHash;
use List::MoreUtils qw(any);

use constant REPORT => 'Report';

has 'id', (is => 'rw', isa => 'Str');

has 'description', (is => 'rw', isa => 'Str');

has 'long_description', (is => 'rw', isa => 'Str');

has 'group_field', (is => 'rw', isa => 'Str');

has 'order_fields', (is => 'rw', isa => 'ArrayRef[Str]');

has 'base_conditions', (is => 'rw', isa => 'ArrayRef[HashRef]');

has 'base_conditions_operator', (is => 'rw', isa => 'Str', default => 'all');

has 'joins', (is => 'rw', isa => 'ArrayRef[Str]', );

has 'searches', (is => 'rw', isa => 'ArrayRef[HashRef]');

has 'base_table', (is => 'rw', isa => 'Str');

has 'columns', (is => 'rw', isa => 'ArrayRef[Str]');

has 'date_field', (is => 'rw', isa => 'Str');

has 'person_fields', (is => 'rw', isa => 'ArrayRef[Str]');

has 'node_fields', (is => 'rw', isa => 'ArrayRef[Str]');

sub generate_sql_query {
    my ($self, %infos) = @_;
    my $logger = get_logger;

    my $sqla = SQL::Abstract::More->new();
    my $and = [];
    $infos{search}{type} //= $self->base_conditions_operator;

    # Date range handling
    push @$and, $self->date_field => { ">", $infos{start_date}} if($infos{start_date});
    push @$and, $self->date_field => { "<", $infos{end_date}} if($infos{end_date});

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
    if($infos{search}) {
        my $all = $infos{search}{type} eq "all" ? 1 : 0;
        my @conditions = map { $_->{field} => {$_->{operator} => $_->{value}} } @{$infos{search}{conditions}};
        if($all) {
            $logger->debug("Matching for all conditions for the provided search");
            push @$and, [ -and => \@conditions ];
        }
        else {
            $logger->debug("Matching for any conditions for the provided search");
            push @$and, \@conditions;
        }
    }

    if(my $search = $infos{sql_abstract_search}) {
        $logger->debug("Adding provided SQL abstract search");
        push @$and, $search;
    }

    if(@{$self->base_conditions} > 0) {
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

    my %limit_offset;
    unless($infos{count_only}) {
        %limit_offset = (
            -limit => $infos{per_page},
            -offset => ($infos{page}-1) * $infos{per_page},
        );
    }

    my %ordering;
    if($infos{order}) {
        %ordering = (
            -order_by => [$infos{order}, @{$self->order_fields}],
        );
    }
    elsif(@{$self->order_fields} > 0) {
        %ordering = (
            -order_by => $self->order_fields,
        );
    }
    elsif(defined($self->date_field)) {
        %ordering = (
            -order_by => ['-'.$self->date_field],
        );
    }


    # NOTE: when counting, we shouldn't group but instead count distinct so it is ignored in that case even when specified
    my %group_by;
    if($self->group_field && !$infos{count_only}) {
        %group_by = (
            -group_by => [$self->group_field],
        );
    }

    my $columns;
    if($infos{count_only}) {
        $columns = $self->group_field ? 'count(distinct('.$self->group_field.')) as count' : 'count(*) as count';
    }
    else {
        $columns = $self->columns;
    }

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

sub ensure_default_infos {
    my ($self, $infos) = @_;
    $infos->{page} //= 1;
    $infos->{per_page} //= 25;
    $infos->{count_only} //= 0;
}

sub query {
    my ($self, %infos) = @_;
    $self->ensure_default_infos(\%infos);
    my ($sql, $params) = $self->generate_sql_query(%infos);
    get_logger->debug(sub { "Executing query : $sql, with the following params : " . join(", ", map { "'$_'" } @$params) });
    return $self->_db_data($sql, @$params);
}

sub page_count {
    my ($self, %infos) = @_;
    $self->ensure_default_infos(\%infos);
    my ($sql, $params) = $self->generate_sql_query(%infos, count_only => 1);
    my ($status, $results) = $self->_db_data($sql, @$params);
    return undef if(is_error($status));

    my $pages = $results->[0]->{count} / $infos{per_page};
    return (($pages == int($pages)) ? $pages : int($pages + 1));
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

=head2 is_person_field

Check if a field is part of the person fields

=cut

sub is_person_field {
    my ($self, $field) = @_;
    return any { $_ eq $field } @{$self->person_fields};
}

=head2 is_node_field

Check if a field is part of the node fields

=cut

sub is_node_field {
    my ($self, $field) = @_;
    return any { $_ eq $field } @{$self->node_fields};
}

1;

