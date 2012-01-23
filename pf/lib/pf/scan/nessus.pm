package pf::scan::nessus;

=head1 NAME

pf::scan::nessus

=cut

=head1 DESCRIPTION

pf::scan::nessus is a module to add Nessus scanning option.

=cut

=head1 DEVELOPMENT NOTE

This module is in progress to be merged with pf::scan (like Openvas)
There's some duplicates for the moment and those will be removed when merge will be completed.

=cut

use strict;
use warnings;

use Log::Log4perl;
use Parse::Nessus::NBE; # TODO: To remove when merge completed
use Readonly;

use pf::config;
use pf::util;
use pf::violation qw(violation_exist_open violation_trigger violation_modify);  #TODO: To remove when merge completed

Readonly our $LOGGER_SCOPE  => 'pf::scan::nessus';
Readonly our $SCAN_VID => 1200001;  # TODO: To remove when merge completed

use constant {  # TODO: To remove when merge completed
    SEVERITY_HOLE => 1,
    SEVERITY_WARNING => 2,
    SEVERITY_INFO => 3,
};

=head1 SUBROUTINES

=over   

=item new

Create a new Nessus scanning object with the required attributes

=cut
sub new {
    my ( $class, %data ) = @_;
    my $logger = Log::Log4perl::get_logger($LOGGER_SCOPE);

    $logger->debug("Instantiating a new pf::scan::nessus scanning object");

    my $this = bless {
            '_id'       => undef,
            '_host'     => undef,
            '_port'     => undef,
            '_user'     => undef,
            '_pass'     => undef,
            '_scanHost' => undef,
            '_scanMac'  => undef,
            '_report'   => undef,
            '_file'     => undef,
            '_policy'   => undef
    }, $class;

    foreach my $value ( keys %data ) {
        $this->{$value} = $data{$value};
    }

    # Nessus specific attributes
    $this->{_file}      = $install_dir . '/conf/nessus/' . $Config{'scan'}{'nessusclient_file'};
    $this->{_policy}    = $Config{'scan'}{'nessusclient_policy'};

    return $this;
}

=item startScan

=cut
sub startScan {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger($LOGGER_SCOPE);

    # nessus scan setup
    my $id                  = $this->{_id};
    my $hostaddr            = $this->{_scanHost};
    my $mac                 = $this->{_scanMac};
    my $host                = $this->{_host};
    my $port                = $this->{_port};
    my $user                = $this->{_user};
    my $pass                = $this->{_pass};
    my $nessusclient_file   = $this->{_file};
    my $nessusclient_policy = $this->{_policy};
    my $nessusRcHome        = 'HOME=' . $install_dir . '/conf/nessus/';

    # preparing host to scan temporary file and result file
    my $infileName = '/tmp/pf_nessus_' . $id . '.txt';
    my $outfileName = $install_dir . '/html/admin/scan/results/dump_' . $id . '.nbe';
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

Derek Wuelfrath <dwuelfrath@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009-2012 Inverse inc.

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
