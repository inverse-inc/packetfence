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
use Try::Tiny;

use overload '""' => "toString";

BEGIN {
    use Exporter ();
    our (@ISA, @EXPORT, @EXPORT_OK);
    @ISA = qw(Exporter);
    @EXPORT = qw(run_scan $SCAN_VID $scan_db_prepared scan_db_prepare);
    @EXPORT_OK = qw(scan_insert_sql scan_select_sql scan_update_status_sql);
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
Readonly our $STATUS_NEW => 'new';
Readonly our $STATUS_STARTED => 'started';
Readonly our $STATUS_CLOSED => 'closed';

# DATABASE HANDLING
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
    $scan_engine = untaint_chain($scan_engine);
    try {
        # try to import module and re-throw the error to catch if there's one
        eval "$scan_engine->require()";
        die($@) if ($@);

    } catch {
        chomp($_);
        $logger->error("Initialization of scan engine $scan_engine failed: $_");
    };

    return $scan_engine->new(%scan_attributes);
}

=item parse_scan_report

Parse a scan report from the scan object and trigger violations if needed

=cut
sub parse_scan_report {
    my ( $scan ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $logger->debug("Scan report to analyze. Scan id: $scan"); 

    my $scan_report = $scan->getReport();
    my @count_vulns = (
        Parse::Nessus::NBE::nstatvulns(@$scan_report, $SEVERITY_HOLE),
        Parse::Nessus::NBE::nstatvulns(@$scan_report, $SEVERITY_WARNING),
        Parse::Nessus::NBE::nstatvulns(@$scan_report, $SEVERITY_INFO),
    );

    # FIXME we shouldn't poke directly into the scan object, we should rely on accessors
    # we are slicing out the parameters out of the $scan objectified hashref
    my ($mac, $ip, $type) = @{$scan}{qw(_scanMac _scanIp _type)};

    # Trigger a violation for each vulnerability
    my $failed_scan = 0;    
    foreach my $current_vuln (@count_vulns) {
        # Parse nstatvulns format
        my ( $trigger_id, $number ) = split(/\|/, $current_vuln);

        $logger->info("Calling violation_trigger for ip: $ip, mac: $mac, type: $type, trigger: $trigger_id");
        my $violation_added = violation_trigger($mac, $trigger_id, $type, (ip => $ip));

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

=item retrieve_scan

Retrieve a scan object populated from the database using the scan id

=cut
sub retrieve_scan {
    my ( $scan_id ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $query = db_query_execute(SCAN, $scan_statements, 'scan_select_sql', $scan_id) || return 0;
    my $scan_infos = $query->fetchrow_hashref();
    $query->finish();

    if (!defined($scan_infos) || $scan_infos->{'id'} ne $scan_id) {
        $logger->warn("Invalid scan object requested");
        return;
    }

    my %scan_args;
    # here we map parameters expected by the object (left) with fields of the database (right)
    @scan_args{qw(id scanIp scanMac reportId status type)} = @$scan_infos{qw(id ip mac report_id status type)};
    my $scan = instantiate_scan_engine($scan_infos->{'type'}, %scan_args);

    return $scan;
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
        $logger->warn("Unable to find MAC address for the scanned host $host_ip. Scan aborted.");
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
            id         => $id,
            scanIp     => $host_ip,
            scanMac    => $host_mac,
            type       => $type,
    );

    db_query_execute(SCAN, $scan_statements, 'scan_insert_sql',
            $id, $host_ip, $host_mac, $type, $date, '0000-00-00 00:00:00', $STATUS_NEW, 'NULL'
    ) || return 0;

    # Instantiate the new scan object
    my $scan = instantiate_scan_engine($type, %scan_attributes);

    # Start the scan
    my $failed_scan = $scan->startScan();
    
    # Hum ... somethings wrong in the scan ?
    if ( $failed_scan ) {
        my $cmd = $bin_dir . "/pfcmd manage vclose $host_mac $SCAN_VID";
        $logger->info("Calling $cmd");
        my $grace = pf_run("$cmd");
        # FIXME shouldn't we focus on return code instead of output? pretty sure this is broken
        if ( $grace == -1 ) {
            $logger->warn("Problem trying to close scan violation");
        }
    }
}

=back

=head1 METHODS

We are also a lean base class for pf::scan::*.

=over

=item statusReportSyncToDb

Update the status and reportId of the scan in the database.

=cut
sub statusReportSyncToDb {
    my ( $self ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    db_query_execute(SCAN, $scan_statements, 'scan_update_sql', 
        $self->{'_status'}, $self->{'_reportId'}, $self->{'_id'}
    ) || return 0;
    return $TRUE;
}

=item isNotExpired

Returns true or false based on wether scan is considered expired or not.

This basically means can we still apply the result of a scan to a node or was it already applied.

=cut
sub isNotExpired {
    my ($self) = @_;
    return ($self->{'_status'} eq $STATUS_STARTED);
}

sub setStatus {
    my ($self, $status) = @_;
    $self->{'_status'} = $status;
    return $TRUE;
}

sub getReport {
    my ($self) = @_;
    return $self->{'_report'};
}

sub toString {
    my ($self) = @_;
    return $self->{'_id'};
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
