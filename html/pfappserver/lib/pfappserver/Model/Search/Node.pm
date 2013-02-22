package pfappserver::Model::Search::Node;
=head1 NAME

pfappserver::Model::Search::Node add documentation

=cut

=head1 DESCRIPTION

Node

=cut

use strict;
use warnings;
use Moose;
use pfappserver::Base::Model::Search;
use pf::SearchBuilder;
use pf::node qw(node_custom_search);

extends 'pfappserver::Base::Model::Search';

sub search {
    my ($self,$params) = @_;
    my %results;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my $builder = new pf::SearchBuilder;
    $builder
        ->select(qw(
            mac pid voip bypass_vlan status category_id
            detect_date regdate unregdate lastskip
            user_agent computername dhcp_fingerprint
            last_arp last_dhcp notes),
            L_("IF(ISNULL(node_category.name), '', node_category.name)",'category')
        )->from('node',
                {
                    'table'  => 'node_category',
                    'join' => 'LEFT',
                    'on' =>
                    [
                        [
                            {
                                'table'  => 'node_category',
                                'name'   => 'category_id',
                            },
                            '=',
                            {
                                'table'  => 'node',
                                'name'   => 'category_id',
                            }
                        ]
                    ],
                }
        );
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
    $results{items} = [node_custom_search($sql)];
    return %results;
}

my %COLUMN_MAP = (
    node_category => {
        table => 'node_category',
        name  => 'name',
    },
    person_name => 'pid',
    switch_ip   => {
       table => 'locationlog',
       name  => 'switch',
    },
    violation   => {
        table => 'class',
        name  => 'description',
    },
);

sub process_query {
    my ($self,$query) = @_;
    my $new_query = $self->SUPER::process_query($query);
    my $old_column = $new_query->[0];
    $new_query->[0] = exists $COLUMN_MAP{$old_column} ? $COLUMN_MAP{$old_column}  : $old_column;
    return $new_query;
}

my %JOIN_MAP = (
    violation => [
        {
            'table'  => 'violation',
            'join' => 'LEFT',
            'on' =>
            [
                [
                    {
                        'table' => 'violation',
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
        {
            'table'  => 'class',
            'join' => 'LEFT',
            'on' =>
            [
                [
                    {
                        'table' => 'violation',
                        'name'  => 'vid',
                    },
                    '=',
                    {
                        'table' => 'class',
                        'name'  => 'vid',
                    }
                ]
            ],
        }
    ],
    switch_ip => [
        {
            'table'  => 'locationlog',
            'join' => 'LEFT',
            'on' =>
            [
                [
                    {
                        'table' => 'locationlog',
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

