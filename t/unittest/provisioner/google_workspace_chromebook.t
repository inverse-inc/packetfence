#!/usr/bin/perl

=head1 NAME

google_workspace_chromebook

=head1 DESCRIPTION

unit test for google_workspace_chromebook

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

use Test::More tests => 3;

#This test will running last
use Test::NoWarnings;
use pf::provisioner::google_workspace_chromebook;
my $provision = pf::provisioner::google_workspace_chromebook->new;

my $response = {
    chromeosdevices => [
        {
            activeTimeRanges     => [ { activeTime => 10, date => "" } ],
            annotatedAssetId     => "",
            annotatedLocation    => "",
            annotatedUser        => "",
            autoUpdateExpiration => "",
            bootMode             => "",
            cpuStatusReports     => [
                {
                    cpuTemperatureInfo =>
                      [ { label => "", temperature => 10 } ],
                    cpuUtilizationPercentageInfo => [10],
                    reportTime                   => "",
                },
            ],
            deviceFiles => [
                { createTime => "", downloadUrl => "", name => "", type => "" },
            ],
            deviceId          => "",
            diskVolumeReports => [
                {
                    volumeInfo => [
                        {
                            storageFree  => "",
                            storageTotal => "",
                            volumeId     => ""
                        }
                    ],
                },
            ],
            dockMacAddress      => "",
            etag                => "",
            ethernetMacAddress  => "",
            ethernetMacAddress0 => "",
            firmwareVersion     => "",
            kind                => "",
            lastEnrollmentTime  => "",
            lastKnownNetwork    => [ { ipAddress => "", wanIpAddress => "" } ],
            lastSync            => "",
            macAddress          => "",
            manufactureDate     => "",
            meid                => "",
            model               => "",
            notes               => "",
            orderNumber         => "",
            orgUnitPath         => "",
            osVersion           => "",
            platformVersion     => "",
            recentUsers     => [ {} ],
            screenshotFiles => [
                { createTime => "", downloadUrl => "", name => "", type => "" },
            ],
            serialNumber   => "",
            status         => "",
            supportEndDate => "",
            systemRamFreeReports =>
              [ { reportTime => "", systemRamFreeInfo => [""] } ],
            systemRamTotal => "",
            tpmVersionInfo => {
                family          => "",
                firmwareVersion => "",
                manufacturer    => "",
                specLevel       => "",
                tpmModel        => "",
                vendorSpecific  => "",
            },
            willAutoRenew =>
              bless( do { \( my $o = 0 ) }, "JSON::PP::Boolean" ),
        },
    ],
    etag          => "",
    kind          => "",
    nextPageToken => "",
};

$provision->process_devices($response->{chromeosdevices});


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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

