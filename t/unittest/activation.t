#!/usr/bin/perl

=head1 NAME

activation

=head1 DESCRIPTION

unit test for activation

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 13;
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

like (pf::activation::digits_generator({ code_length => 6 }), qr/^[0-9]{6}\z/, "digits code has the requested length");
like (pf::activation::digits_generator({}), qr/^[0-9]{10}\z/, "digits code has the default length without code_length");

{
    my %first_digits = map { substr(pf::activation::digits_generator({ code_length => 6 }), 0, 1) => 1 } 1 .. 500;
    is (scalar(keys %first_digits), 10, "every digit, 0 included, can start a digits code");
}

like (pf::activation::hex_generator(\%data), qr/^[0-9a-f]{32}\z/, "hex code is 32 hexadecimal characters");
isnt (pf::activation::hex_generator(\%data), pf::activation::hex_generator(\%data), "hex code does not depend on the request data");

like (
    pf::activation::_generate_activation_code(type => 'sms', style => 'digits', code_length => 6, no_unique => 1),
    qr/^[0-9]{6}\z/,
    "digits activation code has the requested length"
);

like (
    pf::activation::_generate_activation_code(type => 'guest', style => 'md5', no_unique => 1),
    qr/^[0-9a-f]{32}\z/,
    "md5 style activation code keeps its format"
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
