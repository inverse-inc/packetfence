#!/usr/bin/perl

=head1 NAME

wireless.t

=head1 DESCRIPTION

Test for wireless network devices modules

=cut

use strict;
use warnings;
use diagnostics;

use UNIVERSAL::require;

use lib '/usr/local/pf/lib';
use Test::More;
use Test::NoWarnings;

use TestUtils;

my @wireless_devices;
foreach my $networkdevice_class (TestUtils::get_networkdevices_classes()) {
    # create the object
    $networkdevice_class->require();
    my $networkdevice_object = $networkdevice_class->new();
    if ($networkdevice_object->supportsWirelessMacAuth() || $networkdevice_object->supportsWirelessDot1x()) {
        # if a wireless device we keep for the tests
        push(@wireless_devices, $networkdevice_object);
    }
}

# + no warnings
plan tests => scalar @wireless_devices * 2 + 1;

foreach my $wireless_object (@wireless_devices) {

    # test the object's heritage
    isa_ok($wireless_object, 'pf::SNMP');

    # test its interface
    can_ok($wireless_object, qw(
        parseTrap getVersion extractSsid deauthenticateMac
    ));

}

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2011 Inverse inc.

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

