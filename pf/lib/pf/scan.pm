package pf::scan;

=head1 NAME

pf::scan - module that perform the Nessus scans (if enabled)

=cut

=head1 DESCRIPTION

pf::scan contains the functions necessary to perform tasks related to the Nessus scans.

=head1 CONFIGURATION AND ENVIRONMENT

Read the F<pf.conf> configuration file.

=cut

use strict;
use warnings;

use Log::Log4perl;
use Parse::Nessus::NBE;
use Readonly;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(runScan $SCAN_VID);
}

use pf::config;
use pf::iplog qw(ip2mac);
use pf::util;
use pf::violation qw(violation_exist_open violation_trigger violation_modify);

Readonly our $SCAN_VID => 1200001;

use constant {
    SEVERITY_HOLE => 1,
    SEVERITY_WARNING => 2,
    SEVERITY_INFO => 3,
};

=head1 SUBROUTINES

=over   

=item * runScan - perform a Nessus scan against target
        
=cut
# WARNING: A lot of extra single quoting has been done to fix perl taint mode issues: #1087
sub runScan {

    my ($hostaddr, %params) = @_;
    my $logger = Log::Log4perl::get_logger('pf::scan');

    my $date = mysql_date();
    $date     =~ s/ /-/g;
    $hostaddr =~ s/\//\\/g; # escape slashes 

    # resolve MAC address
    my $mac = ip2mac ($hostaddr);
    if (!$mac) {
        $logger->warn("Unable to find MAC for the scanned host $hostaddr. Scan aborted!");
        return 0;
    }

    # untainting critical data
    $hostaddr = clean_ip($hostaddr);

    # nessus scan setup
    my $host = $Config{'scan'}{'host'};
    my $port = $Config{'scan'}{'port'};
    my $user = $Config{'scan'}{'user'};
    my $pass = $Config{'scan'}{'pass'};
    my $nessusclient_file = $install_dir . '/conf/nessus/' . $Config{'scan'}{'nessusclient_file'};
    my $nessusclient_policy = $Config{'scan'}{'nessusclient_policy'};
    my $nessusRcHome = 'HOME=' . $install_dir . '/conf/nessus/';

    # preparing host to scan temporary file and result file
    my $infileName = '/tmp/pf_nessus_' . $hostaddr . '_' . $date . '.txt';
    my $outfileName = $install_dir . '/html/admin/scan/results/dump_' . $hostaddr . '_' . $date . '.nbe';
    my $infile_fh;
    open( $infile_fh, '>', $infileName );
    print {$infile_fh} $hostaddr;
    close( $infile_fh );

    # the scan
    $logger->info("executing $nessusRcHome /opt/nessus/bin/nessus -q -V -x --dot-nessus $nessusclient_file --policy-name $nessusclient_policy $host $port $user <password> --target-file $infileName $outfileName");
    my $output = pf_run("$nessusRcHome /opt/nessus/bin/nessus -q -V -x --dot-nessus $nessusclient_file --policy-name $nessusclient_policy $host $port $user $pass --target-file $infileName $outfileName 2>&1");
    unlink($infileName);

    # did it went well?
    if ($?) { $logger->warn("nessus scan failed, it returned: $output"); }
    if ( ! -r $outfileName ) {
        $logger->warn("unable to open $outfileName for reading; Nessus scan might have failed");
        return 1;
    }

    # Preparing and parsing output file
    chmod 0644, $outfileName;
    open( $infile_fh, '<', $outfileName);
    my @nessusdata = <$infile_fh>;
    close( $infile_fh );

    my @countvulns = ( 
        Parse::Nessus::NBE::nstatvulns(@nessusdata, SEVERITY_HOLE), 
        Parse::Nessus::NBE::nstatvulns(@nessusdata, SEVERITY_WARNING), 
        Parse::Nessus::NBE::nstatvulns(@nessusdata, SEVERITY_INFO),
    );
    
    # for each vuln, trigger the violation
    my $failedScan = 0;
    foreach my $current_vul (@countvulns) {
        # Parse nstatvulns format
        my ($tid, $number) = split(/\|/, $current_vul);

        $logger->info("calling violation_trigger for ip: $hostaddr, mac: $mac, Nessus ScanID: $tid");
        my $violationAdded = violation_trigger($mac, $tid, "scan", ( ip => $hostaddr ));

        # if a violation has been added consider the scan failed
        if ($violationAdded) {
            $failedScan = 1;
        }
    }

    if (!$failedScan) {
        $logger->info("Nessus scan did not detect any vulnerabilities on $hostaddr");
    }

    # If scan is requested because of registration scanning
    #   Clear scan violation if the host didn't generate any violation
    #   Otherwise we keep the violation and clear the ticket_ref. (so we can re-scan once he remediates)
    # If scan came from elsewhere
    #   Do nothing
    #
    # The way we accomplish the above workflow is to differentiate by checking if special violation exists or not
    if (my $violationId = violation_exist_open($mac, $SCAN_VID)) {
        $logger->trace("Scan is completed and there is an open scan violation. We have something to do!");
        # we passed the scan so we can close the scan violation
        if (!$failedScan) {

            my $cmd = $bin_dir."/pfcmd manage vclose $mac $SCAN_VID";
            $logger->info("calling $bin_dir/pfcmd manage vclose $mac $SCAN_VID");
            my $grace = pf_run("$cmd");
            if ($grace == -1) {
                $logger->warn("problem trying to close scan violation");
                return 0;
            }
        # scan completed but it found a violation
        # HACK: we empty the violation's ticket_ref field which we use to track if scan is in progress or not
        } else {
           $logger->debug("Modifying violation id $violationId to empty its ticket_ref field.");
           violation_modify($violationId, (ticket_ref => "" ));
        }
    }
    return 1;
}

=back

=head1 AUTHOR

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


1;
