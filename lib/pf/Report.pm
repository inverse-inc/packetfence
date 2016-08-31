package pf::Report;

use Moose;
use SQL::Abstract::More;

has 'joins', (is => 'rw', isa => 'ArrayRef[Str]', );

has 'searches', (is => 'rw', isa => 'ArrayRef[HashRef]');

has 'base_table', (is => 'rw', isa => 'Str');

has 'columns', (is => 'rw', isa => 'ArrayRef[Str]');

has 'date_field', (is => 'rw', isa => 'Str');

sub query {
    my ($self, %infos) = @_;
    use Data::Dumper;
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
            push @$and, [ -and => \@conditions ];
        }
        else {
            push @$and, \@conditions;
        }
    }

    my ($sql, @params) = $sqla->select(
        -columns => $self->columns, 
        -from => [
            -join => ($self->base_table, split(" ", join(" ", @{$self->joins}))),
        ],
        -where => [ 
            -and => [
                @$and,
            ]
        ],
    );
    print $sql;
}

1;

