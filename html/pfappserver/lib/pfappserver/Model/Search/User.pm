package pfappserver::Model::Search::User;

=head1 NAME

pfappserver::Model::Search::User The model that handles searching nodes

=cut

=head1 DESCRIPTION

User

=cut

use strict;
use warnings;
use Moose;
use pf::log;
use HTTP::Status qw(is_success :constants is_error);
use pf::util qw(calc_page_count);
use pf::dal::person;
use SQL::Abstract::More;
use pf::admin_roles;
use POSIX qw(ceil);

my %COLUMN_MAP = (
    username => 'person.pid',
    mac => 'node.mac',
    name => \"concat(firstname,' ', lastname)",
    ip_address => 'iplog.ip',
    nodes => \"count(node.mac)",
    sponsor => "person.sponsor",
);

our @DEFAULT_COLUMNS = (
    ( map {"person.$_|$_"} @pf::person::FIELDS ),
    ( map { "password.$_|$_" } qw(valid_from expiration access_duration category password) ),
    'count(node.mac)|nodes',
);

our %JOIN_MAP = (
    ip_address => [ qw[=>{mac=mac} iplog] ]
);

our %OP_MAP = (
    equal       => '=',
    not_equal   => '<>',
    not_like    => 'NOT LIKE',
    like        => 'LIKE',
    ends_with   => 'LIKE',
    starts_with => 'LIKE',
    in          => 'IN',
    not_in      => 'NOT IN',
);

=head2 default_search

Return the default search

=cut

sub default_search {
    return {
    -columns => [@DEFAULT_COLUMNS],
    -from => [-join => qw[person =>{password.pid=person.pid} password =>{node.pid=person.pid} node]],
    -group_by => 'person.pid',
    };
}

=head2 search

search

=cut

sub search {
    my ($self, $c, $params) = @_;
    $params->{page_num} ||= 1;
    $params->{per_page} ||= 25;
    $params->{by} //= 'person.pid';
    $params->{direction} //= 'asc';
    my $search_info = $self->default_search;
    my $sqla = SQL::Abstract::More->new;
    $self->_update_from($c, $params, $search_info);
    $self->_build_where($c, $params, $search_info);
    $self->_build_limit($c, $params, $search_info);
    $self->_build_order_by($c, $params, $search_info);
    my ($status, $iter) = pf::dal::person->search(%$search_info);
    if (is_error($status)) {
        return ($status, undef);
    }
    my $items = $iter->all(undef);
    ($status, my $count) = pf::dal::person->count(
        -where => $search_info->{-where},
    );
    if (is_error($status)) {
        return ($status, undef);
    }
    my $per_page = $params->{per_page};
    my %results = (
        items => $items,
        count => $count,
        page_count => ceil($count / $per_page),
        per_page => $per_page,
        page_num => $params->{page_num},
        by => $params->{by},
        direction => $params->{direction},
    );
    return (HTTP_OK, \%results);
}

=head2 _update_from

Update the from in the search info

=cut

sub _update_from {
    my ($self, $c, $params, $search_info) = @_;
    my $searches = $params->{searches} || [];
    my $from = $search_info->{-from};
    for my $search (@$searches) {
        my $name = $search->{name};
        if (exists $JOIN_MAP{$name}) {
            push @$from, @{$JOIN_MAP{$name}};
        }
    }
}

=head2 _build_where

build the where clause of the query

=cut

sub _build_where {
    my ($self, $c, $params, $search_info) = @_;
    my %where;
    my $filter = $params->{filter};
    if (defined $filter) {
        push @{$where{'-or'}}, map { {"person.$_" => {'LIKE' => "\%$filter\%"}}} qw(pid firstname lastname email) ;
    }
    my $searches = $params->{searches} || [];
    my $all_or_any = $params->{all_or_any} // "any";
    my @clauses = map { $self->_build_clause($_) } @$searches;
    if( @clauses) {
        my $relational_op = $all_or_any eq "any" ? "-or" : "-and";
        push @{$where{$relational_op}}, @clauses;
    }
    my $user = $c->user;
    my $roles = [$user->roles];
    if (!pf::admin_roles::admin_can($roles, 'USERS_READ') && pf::admin_roles::admin_can($roles, 'USERS_READ_SPONSORED')) {
        $where{'person.sponsor'} = $user->id;
    }
    $search_info->{-where} = \%where;
}

=head2 _build_limit

Build limit and offset of the query

=cut

sub _build_limit {
    my ($self, $c, $params, $search_info) = @_;
    my $page_num = $params->{page_num} || 1;
    my $limit  = $params->{per_page} || 25;
    my $offset = (( $page_num - 1 ) * $limit);
    $search_info->{-limit} = $limit;
    $search_info->{-offset} = $offset;
}

=head2 _build_order_by

Build the order by clause of the query

=cut

sub _build_order_by {
    my ($self, $c, $params, $search_info) = @_;
    my ($by, $direction) = @$params{qw(by direction)};
    $by //= 'person.pid';
    $direction //= 'asc';
    $direction = lc($direction);
    if ($direction ne 'desc') {
        $direction = 'asc';
    }
    $search_info->{-order_by} = { "-$direction" => $by };
}

=head2 _build_clause

Build clause from the query

=cut

sub _build_clause {
    my ($self, $query) = @_;
    my $op = $query->{op};
    my $value = $query->{value};
    my $name = $query->{name};
    return unless defined $op && defined $name;
    return unless defined $value;
    $name = $self->fixup_name($name);
    $value //= '';
    die "$op is not a supported search operation"
        unless exists $OP_MAP{$op};
    my $sql_op = $OP_MAP{$op};
    if($sql_op eq 'LIKE' || $sql_op eq 'NOT LIKE') {
        #escaping the % and _ \ charcaters
        my $escaped = $value =~ s/([%_\\])/\\$1/g;
        if($op eq 'like' || $op eq 'not_like') {
            $value = "\%$value\%";
        } elsif ($op eq 'starts_with') {
            $value = "$value\%";
        } elsif ($op eq 'ends_with') {
            $value = "\%$value";
        }
        if ($escaped) {
            return { $name => { like => \[q{? ESCAPE '\\\\'}, $value] } };
        }
    }
    return {$name => {$sql_op => $value}};
}

=head2 fixup_name

Fixup the name of column

=cut

sub fixup_name {
    my ($self, $name) = @_;
    if (exists $COLUMN_MAP{$name}) {
        return $COLUMN_MAP{$name};
    }
    return $name;
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
