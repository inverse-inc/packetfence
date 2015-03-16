package pfappserver::Model::Search::User;
=head1 NAME

pfappserver::Model::Search::User add documentation

=cut

=head1 DESCRIPTION

User

=cut

use strict;
use warnings;
use Moose;
use pfappserver::Base::Model::Search;
use pf::SearchBuilder;
use pf::person qw(person_custom_search);
use HTTP::Status qw(is_success :constants);
use POSIX qw(ceil);

extends 'pfappserver::Base::Model::Search';

sub make_builder {
    new pf::SearchBuilder;
    my $builder = new pf::SearchBuilder;
    return $builder
    ->select(@pf::person::FIELDS,
            (map { { table => 'password', name => $_  } } qw(valid_from expiration access_duration category password)),
            L_("count(node.mac)", "nodes"),
            L_("concat(firstname,' ', lastname)", "person_name"),
    )->from('person',
            {
                'table'  => 'node',
                'join' => 'LEFT',
                'using' => 'pid',
            },
            {
                'table'  => 'password',
                'join' => 'LEFT',
                'using' => 'pid',
            },
    )
    ->group_by('pid');
}

sub search {
    my ($self,$params) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my $builder = $self->make_builder;
    $self->setup_query($builder,$params);
    my $results = $self->do_query($builder,$params);
    return(HTTP_OK,$results);
}

my %COLUMN_MAP = (
    username => 'pid',
    mac => {
        table => 'node',
        name  => 'mac',
    },
    name => \"concat(firstname,' ', lastname)",
    ip_address => {
       table => 'iplog',
       name  => 'ip',
    },
    nodes => \"count(node.mac)",
);

my %JOIN_MAP = (
    ip_address => [
        {
            'table'  => 'iplog',
            'join' => 'LEFT',
            'on' =>
            [
                [
                    {
                        'table' => 'iplog',
                        'name'  => 'mac',
                    },
                    '=',
                    {
                        'table' => 'node',
                        'name'  => 'mac',
                    }
                ]
            ],
        },
    ]
);

sub map_column {
    my ($self,$column) = @_;
    exists $COLUMN_MAP{$column} ? $COLUMN_MAP{$column}  : $column;
}

sub process_query {
    my ($self,$query) = @_;
    my $new_query = $self->SUPER::process_query($query);
    $new_query->[0] = $self->map_column($new_query->[0]);
    return $new_query;
}

sub add_joins {
    my ($self,$builder,$params) = @_;
    foreach my $name (map { $_->{name} } @{$params->{searches}}) {
        $builder->from(@{$JOIN_MAP{$name}})
            if( exists $JOIN_MAP{$name});
    }
}


sub setup_query {
    my ($self,$builder,$params) = @_;
    $self->add_joins($builder,$params);
    $self->add_searches($builder,$params);
    $self->add_limit($builder,$params);
    $self->add_order_by($builder,$params);
}

sub do_query {
    my ($self,$builder,$params) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my %results = %$params;
    my $sql = $builder->sql;
    my ($per_page, $page_num) = @{$params}{qw(per_page page_num)};
    $per_page ||= 25;
    $page_num ||= 1;
    my $itemsKey = $self->itemsKey;
    $results{$itemsKey} = [person_custom_search($sql)];
    my $sql_count = $builder->sql_count;
    my ($count) = person_custom_search($sql_count);
    $count = $count->{count};
    $results{count} = $count;
    $results{pages_count} = ceil( $count / $per_page );
    $results{per_page} = $per_page;
    $results{page_num} = $page_num;
    return \%results;
}

sub add_searches {
    my ($self,$builder,$params) = @_;
    my @searches = map {$self->process_query($_)} @{$params->{searches}};
    my $all_or_any = $params->{all_or_any};
    if ($all_or_any eq 'any' ) {
        $all_or_any = 'or';
    } else {
        $all_or_any = 'and';
    }
    if(@searches) {
        $builder->where('(');
        $builder->where($all_or_any)->where(@$_) for @searches;
        $builder->where(')');
    }

}

sub add_order_by {
    my ($self, $builder, $params) = @_;
    my ($by, $direction) = @$params{qw(by direction)};
    if ($by && $direction) {
        $by = $COLUMN_MAP{$by} if (exists $COLUMN_MAP{$by});
        $builder->order_by($by, $direction);
    }
}

__PACKAGE__->meta->make_immutable;


=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

