#!/usr/bin/perl
=head1 NAME

overload add documentation

=cut

=head1 DESCRIPTION

overload

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use Net::Radius::Packet;
use pf::ConfigStore::Switch;
use Net::Radius::Dictionary;
use IO::Select;
use IO::Socket qw/:DEFAULT :crlf/;

my $dictionary = Net::Radius::Dictionary->new("/usr/local/pf/lib/pf/util/dictionary");

my %radiusDefaultData = (
    'NAS-IP-Address'        => '209.53.121.70',
    'NAS-Port'              => 0,
    'NAS-Port-Type'         => 'Wireless-802.11',
    'Service-Type'          => 'Login-User',
    'Calling-Station-Id'    => "00C6106FF98D",
    'Called-Station-Id'     => "9C1C12C1E5C6",
);


my $socket = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1',
    PeerAddr => '127.0.0.1',
    PeerPort => 3799,
    Proto => 'udp',
) or die ("Couldn't create UDP connection: $@");

my $radius_code = 'Login-User';

use Data::Dumper;
print Dumper($dictionary);
while(1) {
    foreach my $switchId (keys %SwitchConfig) {
        my $switchData = $SwitchConfig{$switchId};
        my $secret = $switchData->{radiusSecret};
        next unless defined $secret && $secret !~ /^\s+$/;
        my $randomNameByte = int(rand(256));
        my $randomName = sprintf("00c6106ff9%x",$randomNameByte);
        my $callingStationId = uc($randomName);
        my $calledStationId = uc($switchId);
        $calledStationId =~ s/://g;
        my $radius_request = Net::Radius::Packet->new($dictionary);
        $radius_request->set_code($radius_code);
        # sets a random byte into id
        $radius_request->set_identifier( int(rand(256)) );
        # avoids unnecessary warnings
        $radius_request->set_authenticator("");

        # pushing attributes
        # TODO deal with attribute merging
        while( my ($attr,$val) = each %radiusDefaultData) {
            $radius_request->set_attr($attr, $val);
        }
        $radius_request->set_attr('User-Name',$randomName);
        $radius_request->set_attr('User-Password',$randomName);
        $radius_request->set_attr('Calling-Station-Id',$callingStationId);
        $radius_request->set_attr('Called-Station-Id',$calledStationId);

        $socket->send(auth_resp($radius_request->pack(), $secret));

        # Listen for the response.
        # Using IO::Select because otherwise we can't do timeout without using alarm()
        # and signals don't play nice with threads
        my $select = IO::Select->new($socket);
        if ($select->can_read(10)) {
            my $rad_data;
            my $MAX_TO_READ = 2048;
            print("No answer from radius\n")
                if (!$socket->recv($rad_data, $MAX_TO_READ));
        }
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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

