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
use pf::node qw(node_custom_search);

extends 'pfappserver::Base::Model::Search';

sub initialBuilder {
    new pf::SearchBuilder;
    my $builder = new pf::SearchBuilder;
    return $builder
    ->select(qw(
            pid firstname lastname email telephone company address notes sponsor),
            (map { { table=>'temporary_password', name => $_  } } qw(valid_from expiration access_duration category)),
            L_("count(node.mac) as nodes"),
            L_("concat(firstname,' ', lastname) as person_name"),
    )->from('person',
            {
                'table'  => 'node',
                'join' => 'LEFT',
                'using' => 'pid',
            },
            {
                'table'  => 'temporary_password',
                'join' => 'LEFT',
                'using' => 'pid',
            },
    )
    ->group_by('pid');
}

sub search {
    my ($self,$params) = @_;
    my %results;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my $builder = $self->initialBuilder();
    my @searches = map {$self->process_query($_)} @{$params->{searches}};
    my ($start,$end,$all_or_any,$page_num,$per_page) = @{$params}{qw(start end all_or_any)};
    $self->add_joins($builder,$params);
    if($start && $end) {
    }
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
    $self->add_limit($builder,$params);
    my $sql = $builder->sql;
    $logger->info($sql);
    $results{items} = [node_custom_search($sql)];
    return %results;

}

my %COLUMN_MAP = (
    username => 'pid',
    mac => {
        table => 'node',
        name  => 'mac',
    },
    name  => \"concat(firstname,' ', lastname)",
    ip_address   => {
       table => 'iplog',
       name  => 'ip',
    },
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

__PACKAGE__->meta->make_immutable;

=back

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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

