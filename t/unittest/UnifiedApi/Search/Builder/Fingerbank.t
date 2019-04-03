#!/usr/bin/perl

=head1 NAME

Nodes

=cut

=head1 DESCRIPTION

unit test for pf::UnifiedApi::Search::Builder::Fingerbank

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 11;

#This test will running last
use Test::NoWarnings;
use fingerbank::Model::MAC_Vendor;
use pf::UnifiedApi::Search::Builder::Fingerbank;
use pf::error qw(is_error);
use pf::constants qw($ZERO_DATE);
my $model = "fingerbank::Model::MAC_Vendor";
my $db =  fingerbank::DB_Factory->instantiate(schema => 'Local');
my $schema = $db->handle;
my $source = $schema->source($model->_parseClassName);

my $sb = pf::UnifiedApi::Search::Builder::Fingerbank->new();

{
    my ($status, $col) = $sb->make_columns({ source => $source , model => $model,  fields => [qw(mac $garbage ip4log.ip)], scope => 'Local'});
    ok(is_error($status), "Do no accept invalid columns");
}

{
    my ($status, $col) = $sb->make_columns({ model => $model, source => $source,  fields => [qw(mac id)], scope => 'Local'});
    ok(!is_error($status), "Accept valid columns");
    is_deeply([qw(mac id)], $col, "Columns the same");
}

{
    my ($status, $col) = $sb->make_columns({ model => $model, source => $source,  fields => [], scope => 'Local'});
    ok(!is_error($status), "Accept valid columns");
    is_deeply([qw(id name mac created_at updated_at)], $col, "All columns ");
}


{
    my @f = qw(mac id);

    my %search_info = (
        model => $model,
        source => $source,
        fields => \@f,
        query => {
            op => 'equals',
            field => 'mac',
            value => "00:11:22:33:44:55",
        },
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [
            200,
            [
                qw(mac id),
            ],
        ],
        'Return the columns'
    );

    is_deeply(
        [
            $sb->make_where(\%search_info)
        ],
        [
            200,
            {
                'mac' => { "=" => "00:11:22:33:44:55" },
            },
        ],
        'Where',
    );

}

{
    my @f = qw(mac id);

    my %search_info = (
        model => $model,
        source => $source,
        fields => \@f,
        query => {
            op => 'equals',
            field => 'mac_garbge',
            value => "00:11:22:33:44:55",
        },
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [
            200,
            [
                qw(mac id),
            ],
        ],
        'Return the columns'
    );

    is_deeply(
        [
            $sb->make_where(\%search_info)
        ],
        [
            422,
            {
                message => 'mac_garbge is an invalid field',
            },
        ],
        'Where',
    );

}

{
    my @f = qw(mac id);

    my %search_info = (
        model => $model,
        source => $source,
        fields => \@f,
        query => {
            op => 'equals',
            field => 'mac',
            value => "00:11:22:33:44:55",
        },
        sort => ['mac'],
    );
    is_deeply(
        [
            $sb->make_order_by(\%search_info)
        ],
        [
            200,
            [
                {
                    -asc => 'mac'
                }
            ],
        ],
        'Order by',
    );
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
