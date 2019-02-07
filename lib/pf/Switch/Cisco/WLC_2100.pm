package pf::Switch::Cisco::WLC_2100;

=head1 NAME

pf::Switch::Cisco::WLC_2100

=head1 SYNOPSIS

The pf::Switch::Cisco::WLC_2100 module implements an object oriented interface to manage Wireless LAN Controllers.

=head1 STATUS

Developed and tested a long time ago on an undocumented IOS.

With time and product line evolution, this module mostly became a placeholder,
you should see L<pf::Switch::Cisco::WLC> for other relevant support items and
issues.

=over

=item Supports

=over

=item Deauthentication with RADIUS Disconnect (RFC3576)

Requires IOS 5 or later.

=item Deauthentication with CLI (Telnet or SSH)

=back

=back

=cut

use strict;
use warnings;

use Net::SNMP;

use base ('pf::Switch::Cisco::WLC');

use pf::constants;
use pf::config qw(
    $MAC
    $SSID
);
use pf::util qw(format_mac_as_cisco);

sub description { 'Cisco Wireless (WLC) 2100 Series' }

=head1 SUBROUTINES

TODO: This list is incomplete

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }
# special features
sub supportsSaveConfig { return $FALSE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

=item _deauthenticateMacSNMP

Deprecated: This is no longer required since IOS 5.x+. New implementation is
in pf::Switch::Cisco::WLC and relies on Disconnect-Message (RFC3576).

Warning: this method should _never_ be called in a thread. Net::Appliance::Session is not thread
safe:

L<http://www.cpanforum.com/threads/6909/>

Warning: this code doesn't support elevating to privileged mode. See #900 and #1370.

=cut

sub _deauthenticateMacSNMP {
    my ( $self, $mac ) = @_;
    my $logger = $self->logger;

    $mac = format_mac_as_cisco($mac);
    if ( !defined($mac) ) {
        $logger->error("ERROR: MAC format is incorrect. Aborting deauth...");
        # TODO return 1, really?
        return 1;
    }

    my $session;
    eval {
        require Net::Appliance::Session;
        $session = Net::Appliance::Session->new(
            Host      => $self->{_ip},
            Timeout   => 5,
            Transport => $self->{_cliTransport}
        );
        $session->connect(
            Name     => $self->{_cliUser},
            Password => $self->{_cliPwd}
        );
        # Session not already privileged are not supported at this point. See #1370
        #$session->begin_privileged( $self->{_cliEnablePwd} );
        $session->do_privileged_mode(0);
        $session->begin_configure();
    };

    if ($@) {
        $logger->error( "ERROR: Can not connect to WLC $self->{'_ip'} using "
                . $self->{_cliTransport} );
        return 1;
    }

    #if (! $session->enable($self->{_cliEnablePwd})) {
    #    $logger->error("ERROR: Can not 'enable' telnet connection");
    #    return 1;
    #}
    $session->cmd("client deauthenticate $mac");
    $session->close();

    return 1;
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
