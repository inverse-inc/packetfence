package pf::Connection;

use Moose;
use Log::Log4perl qw(get_logger);

has 'type'          => (is => 'rw', isa => 'Str');                  # Printable string to display the type of a connection
has 'transport'     => (is => 'rw', isa => 'Str');                  # Wired or wireless
has 'isEAP'         => (is => 'rw', isa => 'Bool', default => 0);   # 0: NoEAP / 1: EAP
has 'isSNMP'        => (is => 'rw', isa => 'Bool', default => 0);   # 0: NoSNMP | 1: SNMP
has 'isMacAuth'     => (is => 'rw', isa => 'Bool', default => 0);   # 0: NoMacAuth | 1: MacAuth
has 'is8021X'       => (is => 'rw', isa => 'Bool', default => 0);   # 0: No8021X | 1: 8021X
has '8021XAuth'     => (is => 'rw', isa => 'Str');                  # Authentication used for 8021X connection
has 'enforcement'   => (is => 'rw', isa => 'Str');                  # PacketFence enforcement technique

our $logger = get_logger();


=item _attributesToString

We create a printable string based on the connection attributes which will be used for display purposes and 
database storage purpose.

=cut
sub _attributesToString {
    my ( $this ) = @_;

    # We first set the transport type
    my $type = $this->transport;

    # SNMP is kind of unique and can only apply on a wired connection without anything else
    $type .= ( (lc($this->transport) eq "wired" && $this->isSNMP) ? "-SNMP" : "" );

    # Handling mac authentication for both NoEAP and EAP connections
    if ( $this->isMacAuth ) {
        $type .= "-MacAuth";
        $type .= ( $this->isEAP ? "-EAP" : "-NoEAP" );
    }

    # Handling 802.1X
    $type .= ( $this->is8021X ? "-8021X" : "" );

    return $type;
}


__PACKAGE__->meta->make_immutable;


=back

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

1;
