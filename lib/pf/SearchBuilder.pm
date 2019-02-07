#!/usr/bin/perl
package pf::SearchBuilder;

=head1 NAME

pf::SearchBuilder An SQL select query builder inspired by Fey

=cut

=head1 SYNOPSIS

use pf::SearchBuilder;

new $builder = new pf::SearchBuilder;

$builder
 ->select(qw(
    mac pid voip bypass_vlan status category_id
    detect_date regdate unregdate lastskip
    user_agent computername dhcp_fingerprint
    last_arp last_dhcp notes)
)->from(
    'node',
    {
        'join' => 'LEFT',
        table  => 'node_category',
        using  => 'category_id'
    },
)->where(
    'mac','=','00:00:00:00:00:00:'
)->and(
    'category','LIKE','gaming_%'
);

my $sql = $builder->sql();

=head1 DESCRIPTION

pf::SearchBuilder


=cut

use Moose;
use namespace::autoclean;
use pf::log;
use pf::db qw(get_db_handle);
use Scalar::Util qw(looks_like_number);
BEGIN {
    use Exporter;
    use base qw(Exporter);
    our @EXPORT = qw(L_);
};

=head1 METHODS


=cut

has _is_distinct => (
    is => 'rw',
    default => 0
);

has "_$_" => (
    is        => 'rw',
    predicate => "_has_$_",
) for (qw(offset limit distinct_on));

has "${_}_clause_elements" => (
    is     => 'bare',
    traits => ['Array'],
    default => sub {[]},
    handles => {
        "${_}_clause_elements" => 'elements',
        "add_to_${_}_clause_elements" => 'push',
        "has_${_}_clause_elements"    => 'count',
        "first_${_}_clause_element"   => ['get',0],
        "last_${_}_clause_element"    => ['get',-1]
    }
) for (qw(select from where group_by order_by join));

sub select {
    my ($self,@args) = @_;
    $self->add_to_select_clause_elements($self->_process_select(@args));
    return $self;
}

sub _process_select {
    my ($self,@args) = @_;
    my @columns;
    for my $column (@args) {
        my $type = ref($column);
        my $new_column;
        if($type eq 'SCALAR') {
            $column= L_($$column);
        } elsif ($type eq '') {
            $column = {name => $column};
        }
        push @columns,$column;
    }
    return @columns;
}

sub _process_from {
    my ($self,@args) = @_;
    return map { ref($_) ? $_ : {table => $_} } @args;
}

sub distinct {
    my ($self) = @_;
    $self->_is_distinct(1);
    return $self;
}

sub distinct_on {
    my ($self,$column) = @_;
    $self->_distinct_on($self->_process_select($column));
    return $self;
}

sub from {
    my ($self,@args) = @_;
    my @tables = $self->_process_from(@args);
    $self->add_to_from_clause_elements(@tables);
    return $self;
}


=head2 L_

A convenience function for creating literals
my $builder = new pf::SearchBuilder;
$builder
    ->select(L_("count(*)") => 'node_count')
    ->from('node');
my $sql = $builder->sql();

=cut

sub L_ {
    my ($lit, $as) = @_;
    my $column = {literal => $lit};
    if (defined $as) {
        $column->{as} = $as;
    }
    return $column;
}

sub where {
    my ($self, @args) = @_;
    my @clauses;
    if (@args == 1) {
        @clauses = $self->_single_where_clause(@args);
    } else {
        @clauses = $self->_where_clause(@args);
    }
    $self->add_to_where_clause_elements(@clauses);
    return $self;
}

our %WHERE_SINGLE_OPS = (
    'and' => undef,
    'or'  => undef,
    ')'  => undef,
    '('  => undef,
);

sub _single_where_clause {
    my ($self,$op) = @_;
    my @clauses;
    if( ref($op) eq 'SCALAR'  ) {
        @clauses = ($$op);
    }
    elsif (exists $WHERE_SINGLE_OPS{lc($op)}) {
        @clauses = ($op);
    }
    else {
        die "$op cannot be added to where clause";
    }
    return @clauses;
}

sub _unary_where_clause {
    die "not enough params";
}


our %OP_GROUP_MAP = (
    (map { $_ => '_binary'} ('=','<>','!=','>','<','>=','<=')) ,
    (map { $_ => '_is'} ('IS','IS NOT')) ,
    (map { $_ => '_like'} ('LIKE','NOT LIKE')),
    (map { $_ => '_in'} ('IN','NOT IN')),
    (map { $_ => '_between'} ('BETWEEN','NOT BETWEEN')),
    (map { $_ => '_unary_postfix'} ('IS NULL','IS NOT NULL'))
);

sub _where_clause {
    my ($self,$lhs,$op,@rhs) = @_;
    my @clauses;
    if (exists $OP_GROUP_MAP{$op}) {
        $self->_add_implict_and();
        my $method = $OP_GROUP_MAP{$op};
        push @clauses, $self->$method($lhs,$op,@rhs);
    } else {
        die "invalid operator '$op' provided";
    }
    return @clauses;
}

sub _add_implict_and {
    my ($self) = @_;
    my $logger = get_logger();
    if($self->has_where_clause_elements) {
        my $last_elem = $self->last_where_clause_element;
        if($last_elem eq ')' || ! exists $WHERE_SINGLE_OPS{lc($last_elem)} ) {
           $self->add_to_where_clause_elements('and');
        }
    }
}

our %EQUALITY_OPS = (
    '='  => '_',
    '!=' => undef,
    '<>' => undef,
);

sub _binary {
    my ($self,$lhs,$op,@rhs) = @_;
    my @clauses;
    if(@rhs == 1 ) {
        my $formatted_lhs = $self->format_column($lhs);
        #if rhs side value is undefined
        if ( !defined $rhs[0] && (exists $EQUALITY_OPS{$op} )) {
            @clauses = $self->_unary_postfix($lhs, ($op eq '=' ? 'IS NULL' : 'IS NOT NULL')  );
        } else {
            push @clauses,$formatted_lhs, $op,$self->_format_values(@rhs);
        }

    } else {
        die "invalid amount operands provided";
    }
    return @clauses;
}

sub _unary_postfix {
    my ($self,$lhs,$op,@rhs) = @_;
    return ($self->format_column($lhs),$op);
}

sub _like {
    my ($self, $lhs, $op, $rhs, @escape) = @_;
    my @clauses;
    if (defined $rhs && (@escape == 0 || (@escape == 1 && defined $escape[0]))) {

        #if rhs side value is undefined
        my $formatted_lhs = $self->format_column($lhs);
        push @clauses, $formatted_lhs, $op, $self->_format_values($rhs);

        push @clauses, 'ESCAPE', $self->_format_values(@escape)
            if @escape;

    }
    else {
        die "invalid amount operands provided";
    }
    return @clauses;
}

sub _between {
    my ($self,$lhs,$op,@rhs) = @_;
    my @clauses;
    if( @rhs == 2 ) {
        #if rhs side value is undefined
        my $formatted_lhs = $self->format_column($lhs);
        push @clauses,$formatted_lhs, $op,$self->_format_values($rhs[0]),'and',$rhs[1];

    } else {
        die "invalid amount operands provided";
    }
    return @clauses;
}

sub _in {
    my ($self,$lhs,$op,@rhs) = @_;
    my @clauses;
    if( @rhs ) {
        #if rhs side value is undefined
        my $formatted_lhs = $self->format_column($lhs);
        push @clauses,$formatted_lhs, $op,'(' . join(", ",$self->_format_values(@rhs)) . ')';

    } else {
        die "invalid amount operands provided";
    }
    return @clauses;
}

sub _format_identifier {
    my ($self,@values) = @_;
    my $dbh = get_db_handle();
    return map { $dbh->quote($_) } @values;

}
sub _format_values {
    my ($self,@values) = @_;
    my $dbh = get_db_handle();
    return map {
       ref $_ eq 'SCALAR' ? $$_ : $dbh->quote($_)
    } @values;

}

sub group_by {
    my ($self,@args) = @_;
    $self->add_to_group_by_clause_elements($self->_process_select(@args));
    return $self;
}

sub having {
    my ($self,@args) = @_;
    return $self;
}

sub order_by {
    my ($self,$column,$direction) = @_;
    $direction ||= 'ASC';
    $direction = uc($direction);
    if($direction ne 'ASC' && $direction ne 'DESC') {
        die "direction order ($direction) is invalid";
    }
    $self->add_to_order_by_clause_elements([$self->_process_select($column),$direction]);
    return $self;
}

sub limit {
    my ($self,$limit,$offset) = @_;
    if(looks_like_number($limit)) {
        $self->_limit($limit);
    }
    if(looks_like_number($offset)) {
        $self->_offset($offset);
    }
    return $self;
}

sub dbh {
    return get_db_handle();
}

sub sql {
    my $self = shift;
    return (
        join q{ },
        $self->select_clause(),
        $self->from_clause(),
        $self->where_clause(),
        $self->group_by_clause(),
        $self->having_clause(),
        $self->order_by_clause(),
        $self->limit_clause(),
    );
}

sub sql_count {
    my $self = shift;
    return (
        join q{ },
        $self->select_count_clause(),
        "from (",
            $self->select_clause(),
            $self->from_clause(),
            $self->where_clause(),
            $self->group_by_clause(),
            $self->having_clause(),
        ") AS x"
    ) if($self->has_group_by_clause_elements);

    return (
        join q{ },
        $self->select_count_clause(),
        $self->from_clause(),
        $self->where_clause(),
    );
}

sub bind_params {
    my ($self,@args) = @_;
    return $self;
}

sub select_clause {
    my ($self,$dbh) = @_;

    my $sql = 'SELECT ';

    if ( $self->_is_distinct() ) {
        $sql .= 'DISTINCT ';
    } elsif (  $self->_has_distinct_on ) {
        $sql .= 'DISTINCT ON ('
            . $self->format_column($self->_distinct_on(),$dbh) . ') ';
    }

    $sql .= (
        join ', ',
        map { $self->format_column($_,$dbh) } $self->select_clause_elements()
    );

    return $sql;
}

sub select_count_clause {
    my ($self,$dbh) = @_;

    my $sql = 'SELECT COUNT(*) AS count ';

    return $sql;
}

sub format_column {
    my ($self,$column) = @_;
    my $dbh = $self->dbh();
    my $type = ref $column;
    if ($type eq 'SCALAR') {
        $column = L_($$column);
    } elsif ($type eq '') {
        $column = {name => $column};
    }
    my $column_text;
    my $as =  $column->{as} if exists $column->{as};
    if(exists $column->{literal} && defined $column->{literal}) {
        $column_text = $column->{literal};
    } else {
        my $name = $column->{name};
        my $table_name = (exists $column->{table} && $column->{table} ) || $self->first_from_clause_element->{table};
        $column_text = join('.', map {$dbh->quote_identifier($_) } ($table_name,$column->{name}));
    }
    $column_text .= " AS $as" if defined $as;
    return $column_text;
}


sub from_clause {
    my ($self,@args) = @_;
    my $sql = '';
    if($self->has_from_clause_elements){
        $sql = join(' ','FROM', map {  $self->format_from($_) } $self->from_clause_elements);
    }
    return $sql;
}

my %VALID_JOIN_TYPES = (
    LEFT    => undef,
    RIGHT   => undef,
    CROSS   => undef,
    INNER   => undef,
    OUTER   => undef,
    NATURAL => undef,
    'FULL OUTER'  => undef,
    'LEFT OUTER'  => undef,
    'RIGHT OUTER' => undef,
    'FULL INNER' => undef,
);

sub format_from {
    my ($self,$from_clause) = @_;
    my $type = ref($from_clause);
    my $clause = '';
    my @clause_parts;
    my $dbh = $self->dbh;
    if($type eq 'HASH') {
        my ($table, $as, $join_type, $using, $on) = @{$from_clause}{qw(table as join using on)};
        if(defined $table) {
            if(ref($table) ) {
                $table = $$table;
            } else {
                $table = $dbh->quote_identifier($table);
            }
            if($join_type) {
                $join_type = uc($join_type);
                if(exists $VALID_JOIN_TYPES{$join_type}) {
                    push @clause_parts, $join_type;
                }
                push @clause_parts, "JOIN", $table;
                push @clause_parts, 'AS', $as if defined $as && length($as) > 0;
                if ($using) {
                    push @clause_parts, 'USING(', $dbh->quote_identifier($using), ')';
                } elsif ($on) {
                    push @clause_parts, 'ON', $self->format_from_on(@$on);
                }
            } else {
                @clause_parts = ($table);
            }
            $clause = join(' ', @clause_parts);
        } else {
            die "table not defined";
        }
    } elsif ($from_clause->isa('pf::SearchBuilder::Clause')) {
        $clause = $from_clause->clause;
    }
    return $clause;
}

sub format_from_on {
    my ($self, @args) = @_;
    return
        map { $self->_format_from_on($_) }
        map { @$_} @args;
}

sub _format_from_on {
    my ($self, $arg) = @_;
    my $clause = '';
    my $logger = get_logger();
    my $type = ref($arg);
    if ($type eq 'HASH') {
        $clause = $self->format_column($arg);
    } elsif ($type eq 'SCALAR') {
        $clause = $$arg;
    } elsif (exists $OP_GROUP_MAP{$arg}) {
        $clause = $arg;
    } elsif (exists $WHERE_SINGLE_OPS{lc($arg)}) {
        $clause = $arg;
    } elsif (length $type == 0) {
        $clause = $self->dbh->quote($arg);
    } elsif ($arg->isa('pf::SearchBuilder::Clause')) {
        $clause = $arg->clause;
    }
    return $clause;
}

sub where_clause {
    my ($self,@args) = @_;
    my $sql = '';
    if($self->has_where_clause_elements) {
        $sql = join(' ', 'WHERE', $self->where_clause_elements());
    }
    return $sql;
}

sub order_by_clause {
    my ($self,@args) = @_;
    my $sql = '';
    if($self->has_order_by_clause_elements) {
        $sql = join(' ',
            'ORDER BY',
            (
            join(",", map { $self->format_column($_->[0]) . " " . $_->[1] } $self->order_by_clause_elements())
            )
        );
    }
    return $sql;
}

sub group_by_clause {
    my ($self,$dbh) = @_;
    my $sql = '';
    if($self->has_group_by_clause_elements) {
        $sql = join(' ',
            'GROUP BY',
            (
            map { $self->format_column($_,$dbh) }
            $self->group_by_clause_elements()
            )
        );
    }
    return $sql;
}

sub having_clause {
    my ($self,@args) = @_;
    my $sql = '';
    return $sql;
}

sub limit_clause {
    my ($self) = @_;
    my $sql = '';
    if($self->_has_limit()) {
        $sql = join(
            q{ },
            'LIMIT',
            ($self->_has_offset() ? ($self->_offset(),',') : ( )),
            $self->_limit()
        );
    }
    return $sql;
}

sub sql_or_alias {
    my ($self,@args) = @_;
    return $self;
}

sub sql_with_alias {
    my ($self,@args) = @_;
    return $self;
}

=head2 and

Some syntax sugar for where('and')

=cut

sub and {
    my ($self, @args) = @_;
    return $self->where(@args);
}

=head2 or

Some syntax sugar for where('or)

=cut


sub or {
    my ($self) = @_;
    return $self->where('or');
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

