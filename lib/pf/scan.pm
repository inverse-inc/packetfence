package pf::scan;

=head1 NAME

pf::scan - Module that performs the vulnerability scan operations

=cut

=head1 DESCRIPTION

pf::scan contains the general functions required to lauch and complete a vulnerability scan on a host

=cut

use strict;
use warnings;

use pf::log;
use Parse::Nessus::NBE;
use Readonly;
use Try::Tiny;

use overload '""' => "toString";

BEGIN {
    use Exporter ();
    our (@ISA, @EXPORT_OK);
    @ISA = qw(Exporter);
}

use pf::constants;
use pf::constants::scan qw($SEVERITY_HOLE $SEVERITY_WARNING $SEVERITY_INFO $STATUS_CLOSED $STATUS_NEW $STATUS_STARTED);
use pf::config;
use pf::dal::scan;
use pf::error qw(is_error is_success);
use pf::ip4log;
use pf::scan::nessus;
use pf::scan::openvas;
use pf::scan::wmi;
use pf::util;
use pf::violation qw(violation_close violation_exist_open violation_trigger violation_modify);
use pf::Connection::ProfileFactory;
use pf::api::jsonrpcclient;
use Text::CSV_XS;
use List::MoreUtils qw(any);

=head1 SUBROUTINES

=over

=item instantiate_scan_engine

Instantiate the correct vulnerability scanning engine with attributes

=cut

sub instantiate_scan_engine {
    my ( $type, %scan_attributes ) = @_;
    my $logger = get_logger();

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
    my ( $scan, $scan_vid ) = @_;
    my $logger = get_logger();

    $logger->debug("Scan report to analyze. Scan id: $scan");

    my $scan_report = $scan->getReport();

    my ($mac, $ip, $type) = @{$scan}{qw(_scanMac _scanIp _type)};

    # Trigger a violation for each vulnerability
    my $failed_scan = 0;

    my $csv = Text::CSV_XS->new ({ binary => 1, sep_char => ',' });
    open my $io, "<", \$scan_report;
    my $row = $csv->getline($io);
    if ($row->[0] eq 'Plugin ID') {
        while (my $row = $csv->getline($io)) {
            $logger->info("Calling violation_trigger for ip: $ip, mac: $mac, type: $type, trigger: ".$row->[0]);
            my $violation_added = violation_trigger( { 'mac' => $mac, 'tid' => $row->[0], 'type' => $type } );

            # If a violation has been added, consider the scan failed
            if ( $violation_added ) {
                $failed_scan = 1;
            }
        }
    } else {
        my @count_vulns = (
            Parse::Nessus::NBE::nstatvulns(@$scan_report, $SEVERITY_HOLE),
            Parse::Nessus::NBE::nstatvulns(@$scan_report, $SEVERITY_WARNING),
            Parse::Nessus::NBE::nstatvulns(@$scan_report, $SEVERITY_INFO),
        );
        # Trigger a violation for each vulnerability
        foreach my $current_vuln (@count_vulns) {
            # Parse nstatvulns format
            my ( $trigger_id, $number ) = split(/\|/, $current_vuln);

            $logger->info("Calling violation_trigger for ip: $ip, mac: $mac, type: $type, trigger: $trigger_id");
            my $violation_added = violation_trigger( { 'mac' => $mac, 'tid' => $trigger_id, 'type' => $type } );

            # If a violation has been added, consider the scan failed
            if ( $violation_added ) {
                $failed_scan = 1;
            }
        }
    }

    # If scan is requested because of registration scanning
    #   Clear scan violation if the host didn't generate any violation
    #   Otherwise we keep the violation and clear the ticket_ref (so we can re-scan once he remediates)
    # If the scan came from elsewhere
    #   Do nothing

    # The way we accomplish the above workflow is to differentiate by checking if special violation exists or not
    if ( my $violation_id = violation_exist_open($mac, $scan_vid) ) {
        $logger->trace("Scan is completed and there is an open scan violation. We have something to do!");

        # We passed the scan so we can close the scan violation
        if ( !$failed_scan ) {
            my $apiclient = pf::api::jsonrpcclient->new;
            my %data = (
               'vid' => $scan_vid,
               'mac' => $mac,
               'reason' => 'manage_vclose',
            );
            $apiclient->notify('close_violation', %data );
            $apiclient->notify('reevaluate_access', %data );
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
    my $logger = get_logger();
    my ($status, $scan_infos) = pf::dal::scan->find({id => $scan_id});
    if (is_error($status)) {
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
    my ( $host_ip, $mac ) = @_;
    my $logger = get_logger();


    $host_ip =~ s/\//\\/g;          # escape slashes
    $host_ip = clean_ip($host_ip);  # untainting ip

    # Resolve mac address
    my $host_mac = $mac || pf::ip4log::ip2mac($host_ip);
    if ( !$host_mac ) {
        $logger->warn("Unable to find MAC address for the scanned host $host_ip. Scan aborted.");
        return;
    }

    my $profile = pf::Connection::ProfileFactory->instantiate($host_mac);
    my $scanner = $profile->findScan($host_mac);
    # If no scan detected then we abort
    if (!$scanner) {
        return $FALSE;
    }
    # Preparing the scan attributes
    my $epoch   = time;
    my $date    = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime($epoch));
    my $id      = generate_id($epoch, $host_mac);
    my $type    = lc($scanner->{'_type'});

    # Check the scan engine
    # If set to "none" we abort the scan
    if ( $type eq "none" ) {
        return $FALSE;
    }

    my %scan_attributes = (
            scanner_id => $scanner->{_id},
            id         => $id,
            scanIp     => $host_ip,
            scanMac    => $host_mac,
            type       => $type,
    );
    while(my ($key, $val) = each(%scan_attributes)) {
        $scanner->{"_".$key}=$val;
    }

    my $status = pf::dal::scan->create({
        id => $id,
        ip => $host_ip,
        mac => $host_ip,
        type => $type,
        start_date => $date,
        update_date => $ZERO_DATE,
        status => $STATUS_NEW,
        report_id => 'NULL',
    });

    if (is_error($status)) {
        return 0;
    }

    # Instantiate the new scan object
    my $scan = $scanner;

    # Start the scan (it return the scan_id if it failed)
    my $failed_scan = $scan->startScan();

    # Hum ... somethings wrong in the scan ?
    if ( $failed_scan ) {

        my $apiclient = pf::api::jsonrpcclient->new;
        my %data = (
           'vid' => $failed_scan,
           'mac' => $host_mac,
        );
        $apiclient->notify('close_violation', %data );
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
    my $logger = get_logger();
    my ($status, $rows) = pf::dal::scan->update_items(
        -set => {
            status => $self->{_status},
            report_id => $self->{_reportId},
        },
        -where => {
            id => $self->{'_id'}
        }
    );
    if (is_error($status)) {
        return $FALSE;
    }
    return $rows ? $TRUE : $FALSE;
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

=item matchCategory

Check if the category matches the configuration of the scanner

=cut

sub matchCategory {
    my ($self, $node_attributes) = @_;
    my $category = [split(/\s*,\s*/, $self->{_categories})];
    my $node_cat = $node_attributes->{'category'};

    get_logger->debug( sub { "Tring to match the role '$node_cat' against " . join(",", @$category) });
    # validating that the node is under the proper category for provisioner
    return @$category == 0 || any { $_ eq $node_cat } @$category;
}

=item matchOS

Check if the OS matches the configuration of the scanner

=cut

sub matchOS {
    my ($self, $node_attributes) = @_;
    my @oses = @{$self->{_oses} || []};

    #if no oses are defined then it will match all the oses
    return $TRUE if @oses == 0;

    my $device_name = $node_attributes->{device_type};
    get_logger->debug( sub { "Trying see if device $device_name is one of: " . join(",", @oses) });

    for my $os (@oses) {
        return $TRUE if fingerbank::Model::Device->is_a($device_name, $os);
    }

    return $FALSE;
}

=item match

Check if the device matches the configuration of the scanner

=cut

sub match {
    my ($self, $os, $node_attributes) = @_;
    $node_attributes->{device_type} = defined($os) ? $os : $node_attributes->{device_name};
    return $self->matchCategory($node_attributes) && $self->matchOS($node_attributes) ;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
