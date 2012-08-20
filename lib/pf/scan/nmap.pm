package pf::scan::nmap;

=head1 NAME

pf::scan::nmap

=cut

=head1 DESCRIPTION

pf::scan::nmap is a module to add Nmap scanning option.

=cut

use strict;
use warnings;

use Log::Log4perl;
use Readonly;

use base ('pf::scan');

use pf::config;
use pf::scan;
use pf::util;
use pf::violation qw(violation_exist_open violation_trigger violation_modify);

Readonly our $STATUS_STARTED => 'started';
Readonly our $STATUS_CLOSED => 'closed';

=head1 SUBROUTINES

=over   

=item new

Create a new Nmap scanning object with the required attributes

=cut
sub new {
    my ( $class, %data ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $logger->debug("Instantiating a new pf::scan::nmap scanning object");

    my $this = bless {
            '_id'               => undef,
            '_host'             => $Config{'scan'}{'host'},
            '_port'             => undef,
            '_user'             => $Config{'scan'}{'user'},
            '_pass'             => $Config{'scan'}{'pass'},
            '_nmap_syn_scan'    => $Config{'scan'}{'nmap_syn_scan'},
            '_nmap_port_start'  => $Config{'scan'}{'nmap_port_start'},
            '_nmap_port_end'    => $Config{'scan'}{'nmap_port_end'},
            '_nmap_vdetection'  => $Config{'scan'}{'nmap_version_detection'},
            '_nmap_osdetection' => $Config{'scan'}{'nmap_os_detection'},
            '_scanIp'           => undef,
            '_scanMac'          => undef,
            '_report'           => undef,
            '_file'             => undef,
            '_policy'           => undef,
            '_type'             => undef,
            '_status'           => undef,
    }, $class;

    foreach my $value ( keys %data ) {
        $this->{'_' . $value} = $data{$value};
    }

    return $this;
}

=item startScan

=cut
sub nmap_parse_port {
    my $port = $_[0];
    my $svc = $_[1];
    my $logger = $_[2];
    my $np = $_[3];

    my @host_list = $np->all_hosts();
    my $host = $host_list[0];
    my $mac = $host->mac_addr();
    my $ip = $host->ipv4_addr();
    my $type = "nmap";
    my $failed_scan = 0;

    # Check if the port is a violation by itself
    my $trigger_id = $port;

    $logger->info("Calling violation_trigger for ip: $ip, mac: $mac, type: $type, trigger: $trigger_id");
    my $violation_added = pf::scan::violation_trigger($mac, "1.$trigger_id", $type, (ip => $ip));
    # If a violation has been added, consider the scan failed
    if ( $violation_added ) {
        $failed_scan = 1;
    }

    # Check if the port is a violation based on a script
    for my $script ($svc->scripts()) {
        my $trigger_string = "UNKNOWN";
        my $scriptoutput = $svc->scripts($script);

        if ($script =~ /afp-brute/) {
            $trigger_id = "2";
            $trigger_string = "Valid credentials";
        } elsif ($script =~ /afp-path-vuln/) {
            $trigger_id = "3";
            $trigger_string = "VULNERABLE";
        } elsif ($script =~ /backorifice-brute/) {
            $trigger_id = "4";
            $trigger_string = "Valid credentials";
#            } elsif ($script =~ /backorifice-info/) {
#                $trigger_id = "5";
#                $trigger_string = "VULNERABLE";
        } elsif ($script =~ /dns-blacklist/) {
            $trigger_id = "6";
            $trigger_string = "SPAM";
        } elsif ($script =~ /ip-forwarding/) {
            $trigger_id = "7";
            $trigger_string = "The host has ip forwarding enabled";
        } elsif ($script =~ /netbus-info/) {
            $trigger_id = "8";
            $trigger_string = "Restart persistent: Yes";
        } elsif ($script =~ /smb-brute/) {
            $trigger_id = "9";
            $trigger_string = "Valid credentials";
        } elsif ($script =~ /smb-check-vulns/) {
            $trigger_id = "10";
            $trigger_string = "VULNERABLE";
        } elsif ($script =~ /sniffer-detect/) {
            $trigger_id = "11";
            $trigger_string = "Likely in promiscuous mode";
        } elsif ($script =~ /stuxnet-detect/) {
            $trigger_id = "12";
            $trigger_string = "INFECTED";
        }

        if ($scriptoutput =~ /$trigger_string/) {
            $logger->info("Calling violation_trigger for ip: $ip, mac: $mac, type: $type, trigger: $trigger_id");
            $violation_added = violation_trigger($mac, "2.$trigger_id", $type, (ip => $ip));
            # If a violation has been added, consider the scan failed
            print ">>> found output for script $script\n";
            if ( $violation_added ) {
                $failed_scan = 1;
                print ">>> found violation by script \"$script\", trigger=\"$trigger_string\", id=$trigger_id\n";
            }
        }
    }
}

sub nmap_parse_script {
    my $script = $_[0];
    my $logger = $_[1];
    my $np = $_[2];

    my @host_list = $np->all_hosts();
    my $host = $host_list[0];
    my $mac = $host->mac_addr();
    my $ip = $host->ipv4_addr();
    my $type = "nmap";
    my $failed_scan = 0;

    my $trigger_id = "0";
    my $trigger_string = "UNKNOWN";
    my $scriptoutput = $host->hostscripts($script);

    if ($script =~ /p2p-conficker/) {
        $trigger_id = "1";
        $trigger_string = "INFECTED";
    }

    if ($scriptoutput =~ /$trigger_string/) {
        $logger->info("Calling violation_trigger for ip: $ip, mac: $mac, type: $type, trigger: $trigger_id");
        my $violation_added = violation_trigger($mac, "2.$trigger_id", $type, (ip => $ip));
        # If a violation has been added, consider the scan failed
        if ( $violation_added ) {
            $failed_scan = 1;
        }
    }
}

sub nmap_scan_report {
    my ( $scan ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $logger->debug("Nmap report to analyze. Scan id: $scan");

    my $outfilename = $scan->{'_outfilename'};

    my $np = new Nmap::Parser;
    $np->parsefile($outfilename);

    # Getting scan information
    my @host_list = $np->all_hosts();
    my $host = $host_list[0];
    my $mac = $host->mac_addr();
    my $ip = $host->ipv4_addr();
    my $type = "nmap";

    # Trigger a violation for registered tcp port
    my $failed_scan = 0;
    for my $port ($host->tcp_ports('open')) {
        my $svc = $host->tcp_service($port);
        nmap_parse_port($port, $svc, $logger, $np);
    }

    # Trigger a violation for registered udp port
    for my $port ($host->udp_ports('open')) {
        my $svc = $host->upd_service($port);
        nmap_parse_port($port, $svc, $logger, $np);
    }

    for my $script ($host->hostscripts()) {
        nmap_parse_script($script, $logger, $np);
    }

    # If scan is requested because of registration scanning
    #   Clear scan violation if the host didn't generate any violation
    #   Otherwise we keep the violation and clear the ticket_ref (so we can re-scan once he remediates)
    # If the scan came from elsewhere
    #   Do nothing

    # The way we accomplish the above workflow is to differentiate by checking if special violation exists or not
    if ( my $violation_id = violation_exist_open($mac, $SCAN_VID) ) {
        $logger->trace("Scan is completed and there is an open scan violation. We have something to do!");

        # We passed the scan so we can close the scan violation
        if ( !$failed_scan ) {
            my $cmd = $bin_dir . "/pfcmd manage vclose $mac $SCAN_VID";
            $logger->info("Calling $cmd");
            my $grace = pf_run("$cmd");
            # FIXME shouldn't we focus on return code instead of output? pretty sure this is broken
            if ( $grace == -1 ) {
                $logger->warn("Problem trying to close scan violation");
                return;
            }

        # Scan completed but a violation has been found
        # HACK: we empty the violation's ticket_ref field which we use to track if scan is in progress or not
        } else {
            $logger->debug("Modifying violation id $violation_id to empty its ticket_ref field");
            violation_modify($violation_id, (ticket_ref => ""));
        }
    }

    $scan->setStatus($STATUS_CLOSED);
    $scan->statusReportSyncToDb();
}

sub startScan {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # nmap scan setup
    my $id                  = $this->{_id};
    my $hostaddr            = $this->{_scanIp};
    my $nmap_port_start     = $this->{_nmap_port_start};
    my $nmap_port_end       = $this->{_nmap_port_end};
    my $nmap_ss             = $this->{_nmap_syn_scan};
    my $nmap_vd             = $this->{_nmap_vdetection};
    my $nmap_osd            = $this->{_nmap_osdetection};

    # setup of nmap parameters
    if ($nmap_ss eq 'yes') {
        $nmap_ss = '-sS'
    } else {
        $nmap_ss = ''
    }

    if ($nmap_vd eq 'yes') {
        $nmap_vd = '-sV'
    } else {
        $nmap_vd = ''
    }

    if ($nmap_osd eq 'yes') {
        $nmap_osd = '-O'
    } else {
        $nmap_osd = ''
    }



    # preparing host to scan temporary file and result file
    my $outfileName = $install_dir . '/html/admin/scan/results/dump_nmap' . $id . '.xml';

    my $cmd =
        "/usr/bin/nmap $nmap_ss -p$nmap_port_start-$nmap_port_end $hostaddr"
        . " $nmap_vd $nmap_osd"
        . " --script=p2p-conficker,afp-brute,afp-path-vuln,backorifice-brute,"
        . "backorifice-info,dns-blacklist,ip-forwarding,netbus-info,smb-brute,"
        . "smb-check-vulns,sniffer-detect,stuxnet-detect"
        . " -oX $outfileName 2>&1"
    ;
    $logger->info("executing $cmd");
    $this->{'_status'} = $pf::scan::STATUS_STARTED;
    $this->statusReportSyncToDb();
    my $output = pf_run($cmd);

    # did it went well?
    if ($?) { $logger->warn("nmap scan failed, it returned: $output"); }
    if ( ! -r $outfileName ) {
        $logger->warn("unable to open $outfileName for reading; Nmap scan might have failed");
        return 1;
    }

    # Preparing and parsing output file
    my $infile_fh;
    chmod 0644, $outfileName;

    $this->{'_outfilename'} = $outfileName;

    nmap_scan_report($this);

#    open( $infile_fh, '<', $outfileName);
#
#    # slurp the whole file in arrayref
#    $this->{'_report'} = [ <$infile_fh> ];
#
#    close( $infile_fh );


#    pf::scan::parse_scan_report($this);
}

=back

=head1 AUTHOR

João Moreira <joao.lvwr@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2012-2012

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
