#!/usr/bin/perl

=head1 NAME

search_node -

=cut

=head1 DESCRIPTION

search_node

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::SearchBuilder::Node;
use pfappserver::Base::Model::Search;
use pfappserver::Model::Search::Node;

=head2 input from catalyst

| searches.0.name                     | switch_ip                            |
| searches.0.op                       | equal                                |
| searches.0.value                    | 192.168.56.101                       |

=cut

my $query = {
    searches => [
        {name => 'mac', op => 'equal', value => '00:25:4b:8d:06:af'}
    ],
    online_date => {
        start => '2011-11-09',
        end => '2016-11-09',
    }
};

my $search = pfappserver::Model::Search::Node->new;

use Data::Dumper;
my $builder = $search->make_builder;
$search->setup_query($builder, $query);
print $builder->sql,";\n";
#my $results = $search->do_query($builder, $query);


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

