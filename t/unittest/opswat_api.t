#!/usr/bin/perl

=head1 NAME

CHI

=cut

=head1 DESCRIPTION

unit test for pf::CHI

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);

    #Module for overriding configuration paths
    use PfFilePaths;

}

use Test::More tests => 5;
use Test::Exception;

#This test will running last
use Test::NoWarnings;

use_ok("pf::api");

my $backend = pfconfig::config->new->get_backend();
my $test_mac = "00:11:22:33:44:55";
my $ping_key = $test_mac."-last-ping";

$backend->clear();

is(undef, $backend->get($ping_key),
    "No last ping when device was never seen");

my $before_ping = time;

my $result = pf::api->mdm_opswat_ping({device_id => $test_mac});

is_deeply($result, {rp_time => 60},
    "Result from OPSWAT ping is correct");

my $last_ping = $backend->get($ping_key);

ok(($last_ping <= time && $last_ping >= $before_ping ),
    "Last ping is before now and after ping call");

my $payload = {
    detected_products => [
        {
            categories => [6],
            method_outputs => [
                {
                    result => {
                        method => 1001,
                        is_recent => 1,
                    },
                },
                {
                    result => {
                        method => 1000,
                        enabled => 1,
                    },
                },
            ],
        },
        {
            categories => [5],
            method_outputs => [
                {
                    result => {
                        method => 1001,
                        is_recent => 1,
                    },
                },
                {
                    result => {
                        method => 1000,
                        enabled => 1,
                    },
                },
            ],
        },
    ],
};

$result = pf::api->mdm_opswat_report($payload);
is_deeply($result, {compliant => 1},
    "Compliant payload yields proper result");

$payload = {
    detected_products => []
};

$result = pf::api->mdm_opswat_report($payload);

is_deeply($result, {compliant => 0},
    "Payload with no products is not compliant (no antivirus)");

$payload = {
    detected_products => [
        {
            categories => [5],
            method_outputs => [
                {
                    result => {
                        method => 1001,
                        is_recent => 0,
                    },
                },
                {
                    result => {
                        method => 1000,
                        enabled => 0,
                    },
                },
            ],
        },
    ],
};

$result = pf::api->mdm_opswat_report($payload);

is_deeply($result, {compliant => 0},
    "Payload with not recent antivirus definitions is not compliant");

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

