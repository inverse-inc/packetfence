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
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(perform_disconnect perform_coa perform_rsso);
}

use Digest::HMAC_MD5 qw(hmac_md5);
use pf::constants qw($TRUE);
use Net::Radius::Packet;
use Net::Radius::Dictionary;
use IO::Select;
use IO::Socket qw/:DEFAULT :crlf/;

my $dictionary = new Net::Radius::Dictionary "/usr/local/pf/lib/pf/util/dictionary";
my $default_port = '3799';
my $default_timeout = 10;

=head1 SUBROUTINES

=over

=item perform_dynauth

dynauth (Dynamic Authentication) refers to the concept of a Server-initiated RADIUS dialog with a NAS

Note: It doesn't support attribute stacking on the same key.

$connection_info is an hashref with following supported attributes:

  nas_ip - IP of the dynauth server
  nas_port - port of the dynauth server (default: 3799)
  secret - secret of the dynauth server
  timeout - number of seconds before the socket times out (default: 5)
  LocalAddr - local IP for the connection (directly passed to IO::Socket::INET)

$attributes is an hashref of the attribute_name => value form

$vsa (vendor specific attributes) is an arrayref like this:

  { attribute => $attribute_name, vendor => $vendor_name, value => $value }

Returns an hashref with

  Code => RADIUS reply code

and

  $attribute_name => $attribute_value

for every attribute returned.

=cut

# TODO Proper handling of multiple identical attributes could be done like Net::SNMP
# ex: perform_dynauth(
#         { nas_ip => 127.0.0.1, secret => qwerty },
#         'Disconnect-Message',
#         [ Attribute1 => Value1,
#           Attribute2 => Value2, ],
#         [ Vendor, VSA-Attribute1 , Value1,
#           Vendor, VSA-Attribute2 , Value2, ]
#      );
# Since its in arrayrefs, we are able to handle two identical keys here
# Return value should be of the same format
sub perform_dynauth {
    my ($connection_info, $radius_code, $attributes, $vsa) = @_;

    # setting up defaults
    $connection_info->{'nas_port'} ||= $default_port;
    $connection_info->{'timeout'} ||= $default_timeout;

    # Warning: original code had Reuse => 1 (Note: Reuse is deprecated in favor of ReuseAddr)
    my $socket = IO::Socket::INET->new(
        LocalAddr => $connection_info->{'LocalAddr'},
        PeerAddr => $connection_info->{'nas_ip'},
        PeerPort => $connection_info->{'nas_port'},
        Proto => 'udp',
    ) or die ("Couldn't create UDP connection: $@");

    my $radius_request = Net::Radius::Packet->new($dictionary);
    $radius_request->set_code($radius_code);
    # sets a random byte into id
    $radius_request->set_identifier( int(rand(256)) );
    # avoids unnecessary warnings
    $radius_request->set_authenticator("");

    if($connection_info->{add_message_authenticator}) {
        # Add an empty Message-Authenticator if told to add one
        # This is needed since the signature of the packet must include the empty authenticator attribute
        $radius_request->set_attr("Message-Authenticator", pack("H*", "0" x 32));
    }
    
    # pushing attributes
    # TODO deal with attribute merging
    foreach my $attr (keys %$attributes) {
        next unless defined $attributes->{$attr};
        $radius_request->set_attr($attr, $attributes->{$attr});
    }

    # Warning: untested
    # TODO deal with attribute merging
    foreach my $vsa_ref (@$vsa) {
        $radius_request->set_vsattr($vsa_ref->{'vendor'}, $vsa_ref->{'attribute'}, $vsa_ref->{'value'});
    }


    my $packet_data;
    if($connection_info->{add_message_authenticator}) {
        $packet_data = auth_resp($radius_request->pack(), $connection_info->{'secret'});
        $radius_request = Net::Radius::Packet->new($dictionary, $packet_data);
        $radius_request->set_attr("Message-Authenticator", hmac_md5($packet_data, $connection_info->{'secret'}), $TRUE);
        $packet_data = $radius_request->pack();
    }
    else {
        $packet_data = auth_resp($radius_request->pack(), $connection_info->{'secret'});
    }


    # applying shared-secret signing then send
    $socket->send($packet_data);

    # Listen for the response.
    # Using IO::Select because otherwise we can't do timeout without using alarm()
    # and signals don't play nice with threads
    my $select = IO::Select->new($socket);
    while (1) {
        if ($select->can_read($connection_info->{'timeout'})) {

            my $rad_data;
            my $MAX_TO_READ = 2048;
            die("No answer from $connection_info->{'nas_ip'} on port $connection_info->{'nas_port'}")
                if (!$socket->recv($rad_data, $MAX_TO_READ));

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

        } else {
            die("Timeout waiting for a reply from $connection_info->{'nas_ip'} on port $connection_info->{'nas_port'}");
        }
    }
}

=item perform_disconnect

Sending RADIUS disconnect message to a NAS. Attributes must be provided.

Note: It doesn't support attribute stacking on the same key.

$connection_info is an hashref with following supported attributes:

  nas_ip - IP of the dynauth server
  nas_port - port of the dynauth server (default: 3799)
  secret - secret of the dynauth server
  timeout - number of seconds before the socket times out (default: 5)

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
    my ($connection_info, $attributes, $vsa) = @_;

    return perform_dynauth($connection_info, 'Disconnect-Request', $attributes, $vsa);
}


=item perform_coa

Sending RADIUS Change of Authorization (CoA) message to a NAS. Attributes must be provided.

Note: It doesn't support attribute stacking on the same key.

$connection_info is an hashref with following supported attributes:

  nas_ip - IP of the dynauth server
  nas_port - port of the dynauth server (default: 3799)
  secret - secret of the dynauth server
  timeout - number of seconds before the socket times out (default: 5)

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

    return perform_dynauth($connection_info, 'CoA-Request', $attributes, $vsa);
}

sub perform_rsso {
    my ($connection_info, $attributes, $vsa) = @_;

    return perform_dynauth($connection_info, 'Accounting-Request', $attributes, $vsa);
}

=back

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
