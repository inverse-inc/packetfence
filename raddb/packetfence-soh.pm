#!/usr/bin/perl

=head1 NAME

packetfence-soh.pm - FreeRADIUS PacketFence integration module for SoH support

=head1 DESCRIPTION

This module forwards SoH authorization requests to PacketFence.

=head1 NOTES

Note1:

Our pf::config package is loading all kind of stuff and should be reworked a bit. We need to use that package to load
configuration parameters from the configuration file. Until the package is cleaned, we will define the configuration
parameter here.

Once cleaned:

- Uncommented line: use pf::config

- Remove line: use constant SOAP_PORT => '9090';

- Remove line: $curl->setopt(CURLOPT_URL, 'http://127.0.0.1:' . SOAP_PORT);

- Uncomment line: $curl->setopt(CURLOPT_URL, 'http://127.0.0.1:' . $Config{'ports'}{'soap'});

Search for 'note1' to find the appropriate lines.

=cut

use strict;
use warnings;


use lib '/usr/local/pf/lib/';

#use pf::config; # TODO: See note1
use pf::radius::constants;
use pf::radius::soapclient;


require 5.8.8;

# This is very important! Without this, the script will not get the filled hashes from FreeRADIUS.
our (%RAD_REQUEST, %RAD_REPLY, %RAD_CHECK);


=head1 SUBROUTINES

=over

=item * authorize

This function is called to evaluate and react to an SoH packet. It is
the only callback available inside an SoH virtual server.

=cut

sub authorize {
    my $radius_return_code = $RADIUS::RLM_MODULE_REJECT;
    eval {
        my $data = send_soap_request("soh_authorize",\%RAD_REQUEST);
        if ( $data) {

            my $elements = $data->{'soap:Body'}->{'soh_authorizeResponse'}->{'soapenc:Array'}->{'item'};

            $elements = [$elements] unless ref($elements) eq 'ARRAY';
            # Get RADIUS SoH return code
            $radius_return_code = shift @$elements;

            if ( !defined($radius_return_code) || !($radius_return_code > $RADIUS::RLM_MODULE_REJECT && $radius_return_code < $RADIUS::RLM_MODULE_NUMCODES) ) {
                return $RADIUS::RLM_MODULE_FAIL;
            }
        } else {
            return $RADIUS::RLM_MODULE_FAIL;
        }

        &radiusd::radlog($RADIUS::L_DBG, "StatementOfHealth RESULT RESPONSE CODE: $radius_return_code (2 means OK)");

        # Uncomment for verbose debugging with radius -X
        # Warning: This is a native module so you shouldn't run it with radiusd in threaded mode (default)
        # use Data::Dumper;
        # $Data::Dumper::Terse = 1; $Data::Dumper::Indent = 0; # pretty output for rad logs
        # &radiusd::radlog($RADIUS::L_DBG, "StatementOfHealth COMPLETE REPLY: ". Dumper(\%RAD_REPLY));
    };
    return $radius_return_code;
}


=back

=head1 SEE ALSO

L<http://wiki.freeradius.org/Rlm_perl>

=head1 COPYRIGHT

Copyright (C) 2011-2013 Inverse inc.

=head1 LICENSE

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut

1;
