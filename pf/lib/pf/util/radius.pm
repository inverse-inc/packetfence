package pf::util::radius;

=head1 NAME

pf::util::radius - RADIUS related utilities

=cut

=head1 DESCRIPTION

RADIUS related functions necessary to send, receive and understand RADIUS packets.

RFC2882 Network Access Servers Requirements: Extended RADIUS Practices

  Disconnect-Request 
  Disconnect-ACK
  Disconnect-NAK

  CoA-Request
  CoA-ACK
  CoA-NAK

RFC3576 Dynamic Authorization Extensions to RADIUS

=head1 WARNING

This module is not afraid to die (throw exceptions) when something goes wrong.

=cut
use strict;
use warnings;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT = qw();
    @EXPORT_OK = qw(perform_disconnect);
}

use Net::Radius::Packet;
use Net::Radius::Dictionary;
use IO::Socket qw/:DEFAULT :crlf/;

my $dictionary = new Net::Radius::Dictionary "/usr/local/pf/lib/pf/util/dictionary";

=head1 SUBROUTINES

=over

=item perform_dynauth

dynauth (Dynamic Authentication) refers to the concept of a Server-initiated RADIUS dialog with a NAS

Note: It doesn't support attribute stacking on the same key.

$connection_info is an hashref with following supported attributes:

  nas_ip - IP of the dynauth server
  nas_port - port of the dynauth server
  secret - secret of the dynauth server

$attributes is an hashref of the attribute_name => value form

$vsa (vendor specific attributes) is an arrayref like this:

  { attribute => $attribute_name, vendor => $vendor_name, value => $value }

Returns an hashref with 

  Code => RADIUS reply code

and

  $attribute_name => $attribute_value

for every attribute returned.

=cut
sub perform_dynauth {
    my ($connection_info, $radius_code, $attributes, $vsa) = @_;

    # Warning: original code had Reuse => 1 (Note: Reuse is deprecated in favor of ReuseAddr)
    my $socket = IO::Socket::INET->new(
        PeerAddr => $connection_info->{'nas_ip'}, 
        PeerPort => ( $connection_info->{'nas_port'} || '3799' ),
        LocalAddr => $connection_info->{'local_ip'}, 
        Proto => 'udp',
    );

    my $radius_request = Net::Radius::Packet->new($dictionary);
    $radius_request->set_code($radius_code);
    # sets a random byte into id
    $radius_request->set_identifier( int(rand(256)) );

    # pushing attributes
    # TODO deal with attribute merging
    foreach my $attr (keys %$attributes) {
        $radius_request->set_attr($attr, $attributes->{$attr});
    }

    # Warning: untested
    # TODO deal with attribute merging
    foreach my $vsa_ref (@$vsa) {
        $radius_request->set_vsattr($vsa_ref->{'vendor'}, $vsa_ref->{'attribute'}, $vsa_ref->{'value'});
    }

    # applying shared-secret signing then send
    $socket->send(auth_resp($radius_request->pack(), $connection_info->{'secret'}));

    # Listen for the response
    my $MAX_TO_READ = 2048;
    my $rad_data;
    while (my $reply = $socket->recv($rad_data, $MAX_TO_READ)) {

        next if (!$rad_data);

        my $radius_reply = Net::Radius::Packet->new($dictionary, $rad_data);

        # identifies if the reply is related to the request? damn you udp...
        if ($radius_reply->identifier() != $radius_request->identifier()) { 
            die("Received an invalid RADIUS packet identifier: " . $radius_reply->identifier());
        }

        my %return = ( 'Code' => $radius_reply->code() );
        # TODO deal with attribute merging
        # TODO deal with vsa attributes merging
        foreach my $key ($radius_reply->attributes()) {
            $return{$key} = $radius_reply->attr($key);
        }
        return \%return;
    }
}

=item perform_disconnect

Sending RADIUS disconnect message to a NAS. It overrides attributes as necessary.

Note: It doesn't support attribute stacking on the same key.

$connection_info is an hashref with following supported attributes:

  nas_ip - IP of the dynauth server
  nas_port - port of the dynauth server
  secret - secret of the dynauth server

$deauth_mac - MAC to deauthenticate

$attributes is an hashref of the attribute_name => value form

$vsa (vendor specific attributes) is an arrayref like this:

  { attribute => $attribute_name, vendor => $vendor_name, value => $value }

Returns an hashref with 

  Code => RADIUS reply code

and

  $attribute_name => $attribute_value

for every attribute returned.

=cut
sub perform_disconnect {
    my ($connection_info, $deauth_mac, $attributes, $vsa) = @_;

    # Apparently Cisco expects format 00-11-22-33-44-55
    # TODO validate if we need to uppercase or not
    $deauth_mac =~ s/:/-/g;

    # Prepare standard attributes for disconnect
    # TODO deal with attribute merging
    $attributes = {
        'Calling-Station-Id' => $deauth_mac,
        'NAS-IP-Address' => $connection_info->{'nas_ip'},
    };

    return perform_dynauth($connection_info, 'Disconnect-Request', $attributes, $vsa);
}


=item perform_coa

Sending RADIUS Change of Authorization (CoA) message to a NAS. It overrides attributes as necessary.

Note: It doesn't support attribute stacking on the same key.

$connection_info is an hashref with following supported attributes:

  nas_ip - IP of the dynauth server
  nas_port - port of the dynauth server
  secret - secret of the dynauth server

$attributes is an hashref of the attribute_name => value form

$vsa (vendor specific attributes) is an arrayref like this:

  { attribute => $attribute_name, vendor => $vendor_name, value => $value }

Returns an hashref with 

  Code => RADIUS reply code

and

  $attribute_name => $attribute_value

for every attribute returned.

=cut
sub perform_coa {
    my ($connection_info, $attributes, $vsa) = @_;

    # CoA related
    #    $coa_request->set_vsattr('9', 'cisco-avpair', 'subscriber:command=bounce-host-port');
    #    $coa_request->set_attr('Acct-Terminate-Cause' => 6);  # admin reset
    # + NAS-IP-Address

    return perform_dynauth($connection_info, 'CoA-Request', $attributes, $vsa);
}

=back

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

1;
