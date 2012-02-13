package pf::scan;

=head1 NAME

pf::scan - Module that performs the vulnerability scan operations

=cut

=head1 DESCRIPTION

pf::scan contains the general functions required to lauch and complete a vulnerability scan on a host

=cut

use strict;
use warnings;

use Log::Log4perl;
use Parse::Nessus::NBE;
use Readonly;

BEGIN {
    use Exporter ();
    our (@ISA, @EXPORT, @EXPORT_OK);
    @ISA = qw(Exporter);
    @EXPORT = qw(run_scan $SCAN_VID $scan_db_prepared scan_db_prepare);
    @EXPORT_OK = qw(scan_insert_sql scan_select_sql scan_update_sql);
}

use pf::config;
use pf::db;
use pf::iplog qw(ip2mac);
use pf::scan::nessus;
use pf::scan::openvas;
use pf::util;
use pf::violation qw(violation_exist_open violation_trigger violation_modify);

Readonly our $SCAN_VID          => 1200001;
Readonly our $SEVERITY_HOLE     => 1;
Readonly our $SEVERITY_WARNING  => 2;
Readonly our $SEVERITY_INFO     => 3;


=head1 DATABASE HANDLING

=cut
use constant SCAN       => 'scan';
our $scan_db_prepared   = 0;
our $scan_statements    = {};

sub scan_db_prepare {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $logger->debug("Preparing database statements.");

    $scan_statements->{'scan_insert_sql'} = get_db_handle()->prepare(qq[
            INSERT INTO scan (
                id, ip, mac, type, start_date, update_date, status, report_id
            ) VALUES (
                ?, ?, ?, ?, ?, ?, ?, ?
            )
    ]);

    $scan_statements->{'scan_select_sql'} = get_db_handle()->prepare(qq[
            SELECT id, ip, mac, type, start_date, update_date, status, report_id
            FROM scan
            WHERE id = ?
    ]);

    $scan_statements->{'scan_update_sql'} = get_db_handle()->prepare(qq[
            UPDATE scan SET
                status = ?, report_id =?
            WHERE id = ?
    ]);

    $scan_db_prepared = 1;
    return 1;
}


=head1 SUBROUTINES

=over

=item instantiate_scan_engine

Instantiate the correct vulnerability scanning engine with attributes

=cut
sub instantiate_scan_engine {
    my ( $type, %scan_attributes ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $scan_engine = 'pf::scan::' . $type;

    $logger->info("Instantiate a new vulnerability scanning engine object of type $scan_engine.");

    return $scan_engine->new(%scan_attributes);
}

=item parse_scan_report

Parse a scan report and trigger violations if needed

=cut
sub parse_scan_report {
    my ( $scan_report, %args ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($ip, $mac, $type, $report_id) = @args{'ip', 'mac', 'type', 'report_id'};
    $logger->debug("Scan report to analyze from $type: $report_id"); 

    my @count_vulns = (
        Parse::Nessus::NBE::nstatvulns(@$scan_report, $SEVERITY_HOLE),
        Parse::Nessus::NBE::nstatvulns(@$scan_report, $SEVERITY_WARNING),
        Parse::Nessus::NBE::nstatvulns(@$scan_report, $SEVERITY_INFO),
    );

    # Trigger a violation for each vulnerability
    my $failed_scan = 0;    
    foreach my $current_vuln (@count_vulns) {
        # Parse nstatvulns format
        my ( $trigger_id, $number ) = split(/\|/, $current_vuln);

        $logger->info("Calling violation_trigger for ip: $ip, mac: $mac, type: $type, trigger: $trigger_id");
        my $violation_added = violation_trigger($mac, $trigger_id, 'scan', (ip => $ip));

        # If a violation has been added, consider the scan failed
        if ( $violation_added ) {
            $failed_scan = 1;
        }
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
                return 0;
            }

        # Scan completed but a violation has been found
        # HACK: we empty the violation's ticket_ref field which we use to track if scan is in progress or not
        } else {
            $logger->debug("Modifying violation id $violation_id to empty its ticket_ref field");
            violation_modify($violation_id, (ticket_ref => ""));
        }
    }
}

=item retrieve_scan_infos

Retrieve scan informations from the database using the scan id

=cut
sub retrieve_scan_infos {
    my ( $scan_id ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $query = db_query_execute(SCAN, $scan_statements, 'scan_select_sql', $scan_id) || return 0;
    my $scan_infos = $query->fetchrow_hashref();

    $query->finish();

    return $scan_infos;
}

=item run_scan

Prepare the scan attributes, call the engine instantiation and start the scan

=cut
sub run_scan {
    my ( $host_ip ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $host_ip =~ s/\//\\/g;          # escape slashes
    $host_ip = clean_ip($host_ip);  # untainting ip

    # Resolve mac address
    my $host_mac = ip2mac($host_ip);
    if ( !$host_mac ) {
        $logger->warn("Unable to fin MAC address for the scanned host $host_ip. Scan aborted.");
        return;
    }

    # Preparing the scan attributes
    my $epoch   = time;
    my $date    = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime($epoch));
    my $id      = generate_id($epoch, $host_mac);
    my $type    = lc($Config{'scan'}{'engine'});

    # Check the scan engine
    # If set to "none" we abort the scan
    if ( $type eq "none" ) {
        return;
    }

    my %scan_attributes = (
            _id         => $id,
            _host       => $Config{'scan'}{'host'},
            _user       => $Config{'scan'}{'user'},
            _pass       => $Config{'scan'}{'pass'},
            _scanIp     => $host_ip,
            _scanMac    => $host_mac,
    );

    db_query_execute(SCAN, $scan_statements, 'scan_insert_sql',
            $id, $host_ip, $host_mac, $type, $date, '0000-00-00 00:00:00', 'new', 'NULL'
    ) || return 0;

    # Instantiate the new scan object
    my $scan = instantiate_scan_engine($type, %scan_attributes);

    # Start the scan
    $scan->startScan();
}

=item update_scan_infos

Update the database informations of a scan using the scan id

=cut
sub update_scan_infos {
    my ( $scan_id, $status, $report_id ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    db_query_execute(SCAN, $scan_statements, 'scan_update_sql', $status, $report_id, $scan_id) || return 0;
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
