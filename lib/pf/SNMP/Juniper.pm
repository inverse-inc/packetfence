package pf::SNMP::Juniper;

=head1 NAME

pf::SNMP::Juniper - Object oriented module manage Juniper' switches

=head1 STATUS

Supports 
 MAC Authentication (MAC RADIUS in Juniper's terms)

Developed and tested on Juniper ex4200-48t running on JUNOS 10.3R1.9

=head1 BUGS AND LIMITATIONS
 
=over

=item Bouncing a port is slow

Bouncing a port is done on a VLAN change when in MAC Authentication. 
Because of the lack of SNMP read-write capabilities on the IF-MIB, 
a full disable / commit / enable / commit is performed on the switch making it very slow.

=item Voice over IP

Users behind VoIP phones are not supported yet.

=back

=cut
use strict;
use warnings;

use base ('pf::SNMP');
use Log::Log4perl;
use Net::Appliance::Session;

use pf::config;
use pf::locationlog;
# importing switch constants
use pf::SNMP::constants;
use pf::util;

# capabilities
# TODO implement supportsSnmpTraps globally
sub supportsSnmpTraps { return $FALSE; }
sub supportsWiredMacAuth { return $TRUE; }
# TODO to support Wired dot1x, we'll need to refactor pfsetvlan to send control over here to do a clear dot1x
# (instead of SNMP PAE reAuthenticate because the switch doesn't support writing to the IF-MIB)
sub supportsWiredDot1x { return $FALSE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$PORT); }

=head1 SUBROUTINES

=over

=cut

=item NasPortToIfIndex

NAS-Port's number is the ifIndex index.
Ex: NAS-Port 115 is the 115th ifIndex entry  which is ifIndex 598.

=cut
sub NasPortToIfIndex {
    my ($this, $NAS_port) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    # grab ifName -> ifIndex hash
    my %ifNameIfIndexHash = $this->getIfNameIfIndexHash();

    # get numerically sorted ifIndexes (hash values)
    my @sortedIfIndexes = sort {$a <=> $b} values %ifNameIfIndexHash;

    # ifIndex matching NAS-Port's index is the ifIndex we are looking for
    if (!defined($sortedIfIndexes[$NAS_port])) {
        $logger->warn(
            "Couldn't find ifIndex for NAS-Port. "
            . "VLAN re-assignment and switch/port accounting will be affected."
        );
        return $NAS_port;
    }
    #return $sortedIfIndexes[$NAS_port];

    # at this point we have the sub-interface ifIndex
    my $subIntIfIndex = $sortedIfIndexes[$NAS_port];

    # because no obvious link could be made between a sub-interface ifIndex and it's parent, we use a regexp to do it
    my $subIntName = $this->getIfName($subIntIfIndex);
    # interface: ge-0/0/46 
    # sub-interface: ge-0/0/46.0
    if ($subIntName !~ /^(.+)\.\d+$/) {
        $logger->warn(
            "Couldn't match interface name for NAS-Port. "
            . "VLAN re-assignment and switch/port accounting will be affected."
        );
        return $NAS_port;
    }

    # as found by the above regexp
    my $intName = $1;
    return $ifNameIfIndexHash{"$intName"};
}

=item setAdminStatus

Sets Admin Status of a port.

Right now the only way to do it is from the CLi (through Telnet or SSH).

Warning: This is really slow! About 6 second for the link change.

=cut
sub setAdminStatus {
    my ($this, $ifIndex, $enable) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    
    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't set the admin status for ifIndex $ifIndex");
        return 1;
    }   
    
    my $session;
    eval {
        $session = Net::Appliance::Session->new(
            Host      => $this->{_ip},
            Timeout   => 5,
            Transport => $this->{_cliTransport},
            Platform  => "JUNOS"
        );
        $session->connect(
            Name     => $this->{_cliUser},
            Password => $this->{_cliPwd}
        );  
    };  
    
    if ($@) {
        $logger->error("Unable to connect to ".$this->{'_ip'}." using ".$this->{_cliTransport}.". Failed with $@");
        return;
    }   

    my $port = $this->getIfName($ifIndex);

    my $command;
    if ($enable) {
        $logger->info("Enabling port $port");
        $command = "delete interfaces $port disable";
    } else {
        $logger->info("Shutting port $port");
        $command = "set interfaces $port disable";
    }

    my @output;
    eval {
        # fake priviledged mode
        $session->in_privileged_mode(1);
        $session->begin_configure();

        $logger->trace("sending CLI command '$command'");
        @output = $session->cmd(String => $command, Timeout => '5');
        @output = $session->cmd(String => 'commit comment "admin link status change by PacketFence"', Timeout => '10');

        $session->in_privileged_mode(0);
    };

    if ($@) {
        $logger->error("Unable to set admin status for port $port: $@");
        $session->close();
        return;
    }
    $session->close();
    return 1;
}

=item handleReAssignVlanTrapForWiredMacAuth

Called when a ReAssignVlan trap is received for a switch-port in Wired MAC Authentication.

=cut
sub handleReAssignVlanTrapForWiredMacAuth {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    my $switch_ip = $this->{_ip};

    # TODO implement VoIP device detection
    $logger->info("Bouncing $switch_ip:$ifIndex. A new VLAN will be assigned upon reconnection.");
    # we spawn a shell to workaround a thread safety bug in Net::Appliance::Session when using SSH transport
    # http://www.cpanforum.com/threads/6909
    pf_run("/usr/local/pf/bin/pfcmd_vlan -setIfAdminStatus -switch $switch_ip -ifIndex $ifIndex -ifAdminStatus 0");
    sleep(2);
    pf_run("/usr/local/pf/bin/pfcmd_vlan -setIfAdminStatus -switch $switch_ip -ifIndex $ifIndex -ifAdminStatus 1");

}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
