#!/usr/bin/perl

=head1 NAME

activation

=head1 DESCRIPTION

unit test for activation

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

use Test::More tests => 6;
use Utils;

#This test will running last
use Test::NoWarnings;
use pf::activation qw($UNVERIFIED $SMS_ACTIVATION);
my $mac =  Utils::test_mac();
my $mac2 = Utils::test_mac();
my $pid = "default";

my %data = (
    'pid' => $pid,
    'mac' => $mac,
    'contact_info' => 'test@inverse.ca',
    'status' => $UNVERIFIED,
    'type' => 'sms',
    'portal' => 'portal',
    'carrier_id' => 100056,
    'code_length' => 8,
    'style'    => 'md5',
    timeout    => 2,
    'source_id' => 'local',
);

my $code = pf::activation::create(\%data);

ok (defined $code ,"Code generated for $mac for $pid");

ok (pf::activation::is_code_in_use('sms', $code, $mac), "code in use");
ok (!pf::activation::is_code_in_use('sms', $code, $mac2), "code not in use for mac2");
ok (!pf::activation::is_code_in_use('sms', "${code}_$$", $mac), "Is not code in use");

sleep(3);

ok (!pf::activation::is_code_in_use('sms', $code, $mac), "Is not in use");

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
