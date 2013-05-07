package pf::scan::openvas;

=head1 NAME

pf::scan::openvas

=cut

=head1 DESCRIPTION

pf::scan::openvas is a module to add OpenVAS scanning option.

=cut

use strict;
use warnings;

use Log::Log4perl;
use MIME::Base64;
use Readonly;

use base ('pf::scan');

use pf::config;
use pf::util;

Readonly our $RESPONSE_OK                   => 200;
Readonly our $RESPONSE_RESOURCE_CREATED     => 201;
Readonly our $RESPONSE_REQUEST_SUBMITTED    => 202;

=head1 METHODS 

=over

=item createEscalator

Create an escalator which will trigger an action on the OpenVAS server once the scan will finish

=cut
sub createEscalator {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $name = $this->{_id};
    my $callback = $this->_generateCallback();
    my $command = _get_escalator_string($name, $callback);

    $logger->info("Creating a new scan escalator named $name");

    my $cmd = "omp -h $this->{_host} -p $this->{_port} -u $this->{_user} -w $this->{_pass} -X '$command'";
    $logger->trace("Scan escalator creation command: $cmd");
    my $output = pf_run($cmd);
    chomp($output);
    $logger->trace("Scan escalator creation output: $output");

    # Fetch response status and escalator id
    my ($response, $escalator_id) = ($output =~ /<create_escalator_response\ 
            status="([0-9]+)"\      # status code
            id="([a-zA-Z0-9\-]+)"   # escalator id
            /x);

    # Scan escalator successfully created
    if ( defined($response) && $response eq $RESPONSE_RESOURCE_CREATED ) {
        $logger->info("Scan escalator named $name successfully created with id: $escalator_id");
        $this->{_escalatorId} = $escalator_id;
        return $TRUE;
    }

    $logger->warn("There was an error creating scan escalator named $name, here's the output: $output");
    return;
}

=item createTarget

Create a target (a target is a host to scan)

=cut
sub createTarget {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $name = $this->{_id};
    my $target_host = $this->{_scanIp};
    my $command = "<create_target><name>$name</name><hosts>$target_host</hosts></create_target>";

    $logger->info("Creating a new scan target named $name for host $target_host");

    my $cmd = "omp -h $this->{_host} -p $this->{_port} -u $this->{_user} -w $this->{_pass} -X '$command'";
    $logger->trace("Scan target creation command: $cmd");
    my $output = pf_run($cmd);
    chomp($output);
    $logger->trace("Scan target creation output: $output");

    # Fetch response status and target id
    my ($response, $target_id) = ($output =~ /<create_target_response\ 
            status="([0-9]+)"\      # status code
            id="([a-zA-Z0-9\-]+)"   # task id
            /x);

    # Scan target successfully created
    if ( defined($response) && $response eq $RESPONSE_RESOURCE_CREATED ) {
        $logger->info("Scan target named $name successfully created with id: $target_id");
        $this->{_targetId} = $target_id;
        return $TRUE;
    }

    $logger->warn("There was an error creating scan target named $name, here's the output: $output");
    return;
}

=item createTask

Create a task (a task is a scan) with the existing config id and previously created target and escalator

=cut
sub createTask {
    my ( $this )  = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $name = $this->{_id};

    $logger->info("Creating a new scan task named $name");

    my $command = _get_task_string(
        $name, $Config{'scan'}{'openvas_configid'}, $this->{_targetId}, $this->{_escalatorId}
    );
    my $cmd = "omp -h $this->{_host} -p $this->{_port} -u $this->{_user} -w $this->{_pass} -X '$command'";
    $logger->trace("Scan task creation command: $cmd");
    my $output = pf_run($cmd);
    chomp($output);
    $logger->trace("Scan task creation output: $output");

    # Fetch response status and task id
    my ($response, $task_id) = ($output =~ /<create_task_response\ 
            status="([0-9]+)"\      # status code
            id="([a-zA-Z0-9\-]*)"   # task id
            /x);

    # Scan task successfully created
    if ( defined($response) && $response eq $RESPONSE_RESOURCE_CREATED ) {
        $logger->info("Scan task named $name successfully created with id: $task_id");
        $this->{_taskId} = $task_id;
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
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $name                = $this->{_id};
    my $report_id           = $this->{_reportId};
    my $report_format_id    = $Config{'scan'}{'openvas_reportformatid'}; 
    my $command             = "<get_reports report_id=\"$report_id\" format_id=\"$report_format_id\"/>";

    $logger->info("Getting the scan report for the finished scan task named $name");

    my $cmd = "omp -h $this->{_host} -p $this->{_port} -u $this->{_user} -w $this->{_pass} -X '$command'";
    $logger->trace("Report fetching command: $cmd");
    my $output = pf_run($cmd);
    chomp($output);
    $logger->trace("Report fetching output: $output");

    # Fetch response status and report
    my ($response, $raw_report) = ($output =~ /<get_reports_response\ 
            status="([0-9]+)"       # status code
            [^\<]+[\<][^\>]+[\>]    # get to the report
            ([a-zA-Z0-9\=]+)        # report base64 encoded
            /x);

    # Scan report successfully fetched
    if ( defined($response) && $response eq $RESPONSE_OK && defined($raw_report) ) {
        $logger->info("Report id $report_id successfully fetched for task named $name");
        $this->{_report} = decode_base64($raw_report);   # we need to decode the base64 report

        # We need to manipulate the scan report.
        # Each line of the scan report is pushed into an arrayref
        $this->{'_report'} = [ split("\n", $this->{'_report'}) ];
        pf::scan::parse_scan_report($this);

        return $TRUE;
    }

    $logger->warn("There was an error fetching the scan report for the task named $name, here's the output: $output");
    return;
}

=item new

Create a new Openvas scanning object with the required attributes

=cut
sub new {
    my ( $class, %data ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $logger->debug("Instantiating a new pf::scan::openvas scanning object");

    my $this = bless {
            '_id'               => undef,
            '_host'             => $Config{'scan'}{'host'},
            '_port'             => undef,
            '_user'             => $Config{'scan'}{'user'},
            '_pass'             => $Config{'scan'}{'pass'},
            '_scanIp'           => undef,
            '_scanMac'          => undef,
            '_report'           => undef,
            '_configId'         => undef,
            '_reportFormatId'   => undef,
            '_targetId'         => undef,
            '_escalatorId'      => undef,
            '_taskId'           => undef,
            '_reportId'         => undef,
            '_status'           => undef,
            '_type'             => undef,
    }, $class;

    foreach my $value ( keys %data ) {
        $this->{'_' . $value} = $data{$value};
    }

    # OpenVAS specific attributes
    $this->{_port} = $Config{'scan'}{'openvas_port'};
    $this->{_configId} = $Config{'scan'}{'openvas_configid'};
    $this->{_reportFormatId} = $Config{'scan'}{'openvas_reportformatid'};

    return $this;
}

=item startScan

That's where we use all of these method to run a scan

=cut
sub startScan {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $this->createTarget();
    $this->createEscalator();
    $this->createTask();
    $this->startTask();
}

=item startTask

Start a scanning task with the previously created target and escalator

=cut
sub startTask {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $name    = $this->{_id};
    my $task_id = $this->{_taskId};
    my $command = "<start_task task_id=\"$task_id\"/>";

    $logger->info("Starting scan task named $name");

    my $cmd = "omp -h $this->{_host} -p $this->{_port} -u $this->{_user} -w $this->{_pass} -X '$command'";
    $logger->trace("Scan task starting command: $cmd");
    my $output = pf_run($cmd);
    chomp($output);
    $logger->trace("Scan task starting output: $output");

    # Fetch response status and report id
    my ($response, $report_id) = ($output =~ /<start_task_response\ 
            status="([0-9]+)"[^\<]+[\<] # status code
            report_id>([a-zA-Z0-9\-]+)  # report id
            /x);

    # Scan task successfully started
    if ( defined($response) && $response eq $RESPONSE_REQUEST_SUBMITTED ) {
        $logger->info("Scan task named $name successfully started");
        $this->{_reportId} = $report_id;
        $this->{'_status'} = $pf::scan::STATUS_STARTED;
        $this->statusReportSyncToDb();
        return $TRUE;
    }

    $logger->warn("There was an error starting the scan task named $name, here's the output: $output");
    return;
}

=item _generateCallback

Escalator callback needs to be different if we are running OpenVAS locally or remotely.

Local: plain HTTP on loopback (127.0.0.1)

Remote: HTTPS with fully qualified domain name on admin interface

=cut
sub _generateCallback {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $name = $this->{'_id'};
    my $callback = "<method>HTTP Get<data>";
    if ($this->{'_host'} eq '127.0.0.1') {
        $callback .= "http://127.0.0.1/scan/report/$name";
    }
    else {
        $callback .= "https://$Config{general}{hostname}.$Config{general}{domain}:$Config{ports}{admin}/scan/report/$name";
    }
    $callback .= "<name>URL</name></data></method>";

    $logger->debug("Generated OpenVAS callback is: $callback");
    return $callback;
}

=back

=head1 SUBROUTINES

=over

=item _get_escalator_string

create_escalator string creation.

=cut
sub _get_escalator_string {
    my ($name, $callback) = @_;

    return <<"EOF";
<create_escalator>
  <name>$name</name>
  <condition>Always<data>High<name>level</name></data><data>changed<name>direction</name></data></condition>
  <event>Task run status changed<data>Done<name>status</name></data></event>
  $callback
</create_escalator>
EOF
}

=item _get_task_string

create_task string creation.

=cut
sub _get_task_string {
    my ($name, $config_id, $target_id, $escalator_id) = @_;

    return <<"EOF";
<create_task>
  <name>$name</name>
  <config id=\"$config_id\"/>
  <target id=\"$target_id\"/>
  <escalator id=\"$escalator_id\"/>
</create_task>
EOF
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
