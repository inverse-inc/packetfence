#!/usr/bin/perl

=head1 NAME

RADIUS

=head1 DESCRIPTION

unit test for RADIUS

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);

    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 12;
use Test::Mojo;
use Utils;

#This test will running last
use Test::NoWarnings;
use pf::ConfigStore::Source;

my ( $fh, $filename ) = Utils::tempfileForConfigStore("pf::ConfigStore::Source");

my $t = Test::Mojo->new('pf::UnifiedApi');

my $collection_base_url = '/api/v1/config/sources';

my %options = (
    type        => 'RADIUS',
    port        => 1812,
    host        => '1.2.3.4',
    timeout     => 1000,
    description => 'Blag balh',
    secret      => 'bob',
);

$t->post_ok(
    $collection_base_url => json => {
        id               => 'RADIUS_CONNECT_THROUGH_TEST2',
        pfconnector_port => 30000,
        %options,
    }
)->status_is(422)->json_is(
    {
        status => 422,
        errors => [
            {
                field   => 'pfconnector_port',
                message => 'Port should be unique',
            }
        ],
        message => 'Unable to validate',
    }
);
$t->post_ok(
    $collection_base_url => json => {
        id               => 'RADIUS_CONNECT_THROUGH_TEST2',
        pfconnector_port => 30001,
        %options,
    }
)->status_is(422)->json_is(
    {
        status => 422,
        errors => [
            {
                field   => 'pfconnector_port',
                message => 'Port should be unique',
            }
        ],
        message => 'Unable to validate',
    }
);

$t->post_ok(
    $collection_base_url => json => {
        id               => 'RADIUS_CONNECT_THROUGH_TEST2',
        pfconnector_port => 30002,
        %options,
    }
)->status_is(201);

$t->post_ok(
    $collection_base_url => json => {
        id               => 'RADIUS_CONNECT_THROUGH_TEST3',
        pfconnector_port => 29999,
        %options,
    }
)->status_is(422)->json_is(
    {
        status => 422,
        errors => [
            {
                field   => 'pfconnector_port',
                message => 'Value must be between 30000 and 30999',
            }
        ],
        message => 'Unable to validate',
    }
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2025 Inverse inc.

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

