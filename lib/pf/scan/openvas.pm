package pf::scan::openvas;

=head1 NAME

pf::scan::openvas

=cut

=head1 DESCRIPTION

pf::scan::openvas is a module to add OpenVAS scanning option.

=cut

use strict;
use warnings;

use Text::CSV;
use pf::log;
use MIME::Base64;
use Readonly;

use base ('pf::scan');

use pf::CHI;
use pf::constants;
use pf::constants::scan qw($SCAN_VID $PRE_SCAN_VID $POST_SCAN_VID $STATUS_STARTED);
use pf::config qw(%Config);
use pf::util;
use pf::violation;
use Time::HiRes qw(time);

sub description { 'Openvas Scanner' }

Readonly our $RESPONSE_OK                   => 200;
Readonly our $RESPONSE_RESOURCE_CREATED     => 201;
Readonly our $RESPONSE_REQUEST_SUBMITTED    => 202;

=head2 _get_scan_id

Get or generate the scan ID

=cut

sub _get_scan_id {
    my ($self) = @_;
    $self->{_scanId} = $self->{_scanId} // $self->{_id} . time;
    return $self->{_scanId};
}

=head1 METHODS

=over

=item createTarget

Create a target (a target is a host to scan)

=cut

sub createTarget {
    my ( $self ) = @_;
    my $logger = get_logger();

    my $name = $self->_get_scan_id();
    my $target_host = $self->{_scanIp};
    my $command = "<create_target><name>$name</name><hosts>$target_host</hosts></create_target>";

    $logger->info("Creating a new scan target named $name for host $target_host");

    my $cmd = "omp -h $self->{_ip} -p $self->{_port} -u $self->{_username} -w $self->{_password} -X '$command'";
    $logger->info("Scan target creation command: $cmd");
    my $output = pf_run($cmd);
    chomp($output);
    $logger->info("Scan target creation output: $output");

    # Fetch response status and target id
    my ($target_id, $response) = ($output =~ /<create_target_response.*id="([a-zA-Z0-9\-]+)".*status="([0-9]+)"/x);

    # Scan target successfully created
    if ( defined($response) && $response eq $RESPONSE_RESOURCE_CREATED ) {
        $logger->info("Scan target named $name successfully created with id: $target_id");
        $self->{_targetId} = $target_id;
        return $TRUE;
    }

    $logger->warn("There was an error creating scan target named $name, here's the output: $output");
    return;
}

=item createTask

Create a task (a task is a scan) with the existing config id and previously created target and escalator

=cut

sub createTask {
    my ( $self )  = @_;
    my $logger = get_logger();

    my $name = $self->_get_scan_id();

    $logger->info("Creating a new scan task named $name");

    my $command = $self->_get_task_string($name, $self->{_openvas_configid}, $self->{_targetId});
    my $cmd = "omp -h $self->{_ip} -p $self->{_port} -u $self->{_username} -w $self->{_password} -X '$command'";
    $logger->info("Scan task creation command: $cmd");
    my $output = pf_run($cmd);
    chomp($output);
    $logger->info("Scan task creation output: $output");

    # Fetch response status and task id
    my ($task_id, $response) = ($output =~ /<create_task_response.*id="([a-zA-Z0-9\-]*)".*status="([0-9]+)"/x);

    # Scan task successfully created
    if ( defined($response) && $response eq $RESPONSE_RESOURCE_CREATED ) {
        $logger->info("Scan task named $name successfully created with id: $task_id");
        $self->{_taskId} = $task_id;
        return $TRUE;
    }

    $logger->warn("There was an error creating scan task named $name, here's the output: $output");
    return;
}

=item processReport

Retrieve the report associated with a task.
When retrieving a report in other format than XML, we received the report in base64 encoding.

Report processing's duty is to ensure that the proper violation will be triggered.

=cut

sub processReport {
    my ( $self, $task_name ) = @_;
    my $logger = get_logger();

    my $info           = $self->getScanInfo($task_name);
    my $report_id = $info->{report_id};
    my $mac = $info->{mac};
    my $report_format_id    = $self->{'_openvas_reportformatid'};
    my $command             = "<get_reports report_id=\"$report_id\" format_id=\"$report_format_id\"/>";

    $logger->info("Getting the scan report for the finished scan task named $task_name");

    my $cmd = "omp -h $self->{_ip} -p $self->{_port} -u $self->{_username} -w $self->{_password} -X '$command'";
    $logger->info("Report fetching command: $cmd");
    my $output = pf_run($cmd);
    chomp($output);
    $logger->info("Report fetching output: $output");

    # Fetch response status and report
    my ($response, $raw_report) = ($output =~ /<get_reports_response.*status="([0-9]+)".*"text\/csv">([a-zA-Z0-9\=\+\/]+)/x);

    # Scan report successfully fetched
    if ( defined($response) && $response eq $RESPONSE_OK && defined($raw_report) ) {
        $logger->info("Report id $report_id successfully fetched for task named $task_name");
        my $report = decode_base64($raw_report);   # we need to decode the base64 report

        my $csv = Text::CSV->new ( { binary => 1, auto_diag => 2 } );
        open my $io, "<", \$report;
        $csv->column_names($csv->getline($io));
        while(my $row = $csv->getline_hr($io)) {
            violation_trigger( { 'mac' => $mac, 'tid' => $row->{'NVT OID'}, 'type' => 'OpenVAS' } );
        }

        return $TRUE;
    }

    $logger->warn("There was an error fetching the scan report for the task named $task_name, here's the output: $output");
    return;
}

=item new

Create a new Openvas scanning object with the required attributes

=cut

sub new {
    my ( $class, %data ) = @_;
    my $logger = get_logger();

    $logger->debug("Instantiating a new pf::scan::openvas scanning object");

    my $self = bless {
            '_id'               => undef,
            '_ip'               => undef,
            '_port'             => undef,
            '_username'         => undef,
            '_password'         => undef,
            '_scanIp'           => undef,
            '_scanMac'          => undef,
            '_report'           => undef,
            '_openvas_alertid'         => undef,
            '_openvas_configid'         => undef,
            '_openvas_reportformatid'   => undef,
            '_targetId'         => undef,
            '_escalatorId'      => undef,
            '_taskId'           => undef,
            '_status'           => undef,
            '_type'             => undef,
            '_oses'             => undef,
            '_categories'         => undef,
    }, $class;

    foreach my $value ( keys %data ) {
        $self->{'_' . $value} = $data{$value};
    }

    return $self;
}

=item startScan

That's where we use all of these method to run a scan

=cut

sub startScan {
    my ( $self ) = @_;
    my $logger = get_logger();

    $self->createTarget();
    $self->createTask();
    $self->startTask();

    my $scan_vid = $pf::constants::scan::POST_SCAN_VID;
    $scan_vid = $pf::constants::scan::SCAN_VID if ($self->{'_registration'});
    $scan_vid = $pf::constants::scan::PRE_SCAN_VID if ($self->{'_pre_registration'});

    my $apiclient = pf::api::jsonrpcclient->new;
    my %data = (
       'vid' => $scan_vid,
       'mac' => $self->{'_scanMac'},
    );
    $apiclient->notify('close_violation', %data );

    # Clear the scan ID
    $self->{_scanId} = undef;
}

=item startTask

Start a scanning task with the previously created target and escalator

=cut

sub startTask {
    my ( $self ) = @_;
    my $logger = get_logger();

    my $name    = $self->_get_scan_id();
    my $task_id = $self->{_taskId};
    my $command = "<start_task task_id=\"$task_id\"/>";

    $logger->info("Starting scan task named $name");

    my $cmd = "omp -h $self->{_ip} -p $self->{_port} -u $self->{_username} -w $self->{_password} -X '$command'";
    $logger->info("Scan task starting command: $cmd");
    my $output = pf_run($cmd);
    chomp($output);
    $logger->info("Scan task starting output: $output");

    # Fetch response status and report id
    my ($response, $report_id) = ($output =~ /<start_task_response.*status="([0-9]+)"[^\<]+[\<].*report_id>([a-zA-Z0-9\-]+)/x);

    # Scan task successfully started
    if ( defined($response) && $response eq $RESPONSE_REQUEST_SUBMITTED ) {
        $logger->info("Scan task named $name successfully started");
        $self->setScanInfo($name, {report_id => $report_id, mac => $self->{_scanMac}, ip => $self->{_scanIp}, scan_id => $self->{_scanner_id}});
        $self->{'_status'} = $STATUS_STARTED;
        $self->statusReportSyncToDb();
        return;
    }

    $logger->warn("There was an error starting the scan task named $name, here's the output: $output");
}

=head2 setScanInfo

Set the scan info for a scan ID

=cut

sub setScanInfo {
    my ($self, $scan_id, $info) = @_;
    return $self->cache->set("info-$scan_id", $info);
}

=head2 getScanInfo

Get the scan info for a scan ID

=cut

sub getScanInfo {
    my ($self, $scan_id) = @_;
    return $self->cache->get("info-$scan_id");
}

=head2 _to_single_line

Take a multi-line OpenVAS XML payload and make it one line for usage with the omp command line

=cut

sub _to_single_line {
    my ($self, $s) = @_;
    $s =~ s/>\s*</></g;
    return join("", split(/\n/, $s));
}

=item _get_task_string

create_task string creation.

=cut

sub _get_task_string {
    my ($self, $name, $config_id, $target_id) = @_;

    my $s = <<"EOF";
<create_task>
  <name>$name</name>
  <config id=\"$config_id\"/>
  <target id=\"$target_id\"/>
  <alert id=\"$self->{_openvas_alertid}\"/>
</create_task>
EOF
    return $self->_to_single_line($s);
}

=head2 cache

Get the cache for the OpenVAS engines

=cut

sub cache {
    my ($self) = @_;
    return pf::CHI->new(namespace => "openvas_scans");
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
