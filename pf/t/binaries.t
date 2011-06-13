#!/usr/bin/perl
=head1 NAME

binaries.t

=head1 DESCRIPTION

Compile check on perl binaries

=cut
use strict;
use warnings;
use diagnostics;

use Test::More tests => 26;

my @binaries = (
    '/usr/local/pf/configurator.pl',
    '/usr/local/pf/installer.pl',
    '/usr/local/pf/addons/accounting.pl',
    '/usr/local/pf/addons/autodiscover.pl',
    '/usr/local/pf/addons/connect_and_read.pl',
    '/usr/local/pf/addons/convertToPortSecurity.pl',
    '/usr/local/pf/addons/dhcp_dumper',
    '/usr/local/pf/addons/monitorpfsetvlan.pl',
    '/usr/local/pf/addons/recovery.pl',
    '/usr/local/pf/addons/802.1X/packetfence.pm',
    '/usr/local/pf/addons/mrtg/mrtg-wrapper.pl',
    '/usr/local/pf/addons/upgrade/update-all-useragents.pl',
    '/usr/local/pf/bin/flip.pl',
    '/usr/local/pf/bin/pfcmd_vlan',
    '/usr/local/pf/cgi-bin/redir.cgi',
    '/usr/local/pf/cgi-bin/register.cgi',
    '/usr/local/pf/cgi-bin/release.cgi',
    '/usr/local/pf/cgi-bin/wispr.cgi',
    '/usr/local/pf/lib/pf/WebAPI.pm',
    '/usr/local/pf/lib/pf/web/backend_modperl_require.pl',
    '/usr/local/pf/lib/pf/web/captiveportal_modperl_require.pl',
    '/usr/local/pf/sbin/pfdetect',
    '/usr/local/pf/sbin/pfdhcplistener',
    '/usr/local/pf/sbin/pfmon',
    '/usr/local/pf/sbin/pfredirect',
    '/usr/local/pf/sbin/pfsetvlan',
);

foreach my $currentBinary (@binaries) {
    ok( system("/usr/bin/perl -c $currentBinary 2>&1") == 0,
        "$currentBinary compiles" );
}

=head1 AUTHOR

Dominik Ghel <dghel@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2009-2011 Inverse inc.

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

