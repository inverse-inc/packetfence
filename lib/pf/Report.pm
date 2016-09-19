package pf::Report;

use Moose;
use SQL::Abstract::More;
use pf::db;
use pf::log;
use Tie::IxHash;

use constant REPORT => 'Report';

has 'id', (is => 'rw', isa => 'Str');

has 'description', (is => 'rw', isa => 'Str');

has 'group_field', (is => 'rw', isa => 'Str');

has 'order_fields', (is => 'rw', isa => 'ArrayRef[Str]');

has 'base_conditions', (is => 'rw', isa => 'ArrayRef[HashRef]');

has 'base_conditions_operator', (is => 'rw', isa => 'Str', default => 'all');

has 'joins', (is => 'rw', isa => 'ArrayRef[Str]', );

has 'searches', (is => 'rw', isa => 'ArrayRef[HashRef]');

has 'base_table', (is => 'rw', isa => 'Str');

has 'columns', (is => 'rw', isa => 'ArrayRef[Str]');

has 'date_field', (is => 'rw', isa => 'Str');

# empty since no queries are prepared upfront
sub Report_db_prepare {}

sub generate_sql_query {
    my ($self, %infos) = @_;
    my $logger = get_logger;

    my $sqla = SQL::Abstract::More->new();
    my $and = [];

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

    my %group_by;
    if($self->group_field) {
        %group_by = (
            -group_by => [$self->group_field],
        );
    }

    my ($sql, @params) = $sqla->select(
        -columns => $infos{count_only} ? 'count(*) as count' : $self->columns, 
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
    my $print_params = join(", ", map { "'$_'" } @$params);
    get_logger->debug("Executing query : $sql, with the following params : $print_params");
    return $self->_db_data(REPORT, {'report_sql' => $sql}, 'report_sql', @$params);
}

sub page_count {
    my ($self, %infos) = @_;
    $self->ensure_default_infos(\%infos);
    my ($sql, $params) = $self->generate_sql_query(%infos, count_only => 1);
    my @results = $self->_db_data(REPORT, {'report_sql' => $sql}, 'report_sql', @$params);
    my $pages = $results[0]->{count} / $infos{per_page};
    return (($pages == int($pages)) ? $pages : int($pages + 1));
}

sub _db_data {
    my ($self, $from_module, $module_statements_ref, $query, @params) = @_;

    my $sth = db_query_execute($from_module, $module_statements_ref, $query, @params) || return (0);

    my ( $ref, @array );
    # Going through data as array ref and putting it in ordered hash to respect the order of the select in the final report
    my $fields = $sth->{NAME};
    my $fieldsLength = @$fields;
    while ( $ref = $sth->fetchrow_arrayref() ) {
        tie my %record, 'Tie::IxHash';
        foreach my $i (0..($fieldsLength-1)) {
            $record{$fields->[$i]} = $ref->[$i];
        }
        push( @array, \%record );
    }
    $sth->finish();
    return (@array);
}

1;

