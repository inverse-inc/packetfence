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

use pf::config;
use pf::util;

Readonly our $LOGGER_SCOPE                  => 'pf::scan::openvas';
Readonly our $RESPONSE_OK                   => 200;
Readonly our $RESPONSE_RESOURCE_CREATED     => 201;
Readonly our $RESPONSE_REQUEST_SUBMITTED    => 202;

=head1 SUBROUTINES

=over

=item createEscalator

Create an escalator which will trigger an action on the OpenVAS server once the scan will finish

=cut
sub createEscalator {
    my $this = @_;
    my $logger = Log::Log4perl::get_logger($LOGGER_SCOPE);

    my $hostname    = $Config{'general'}{'hostname'};
    my $domain      = $Config{'general'}{'domain'};

    my $name    = $this->{_id};
    my $command = "
            <create_escalator>
                <name>$name</name>
                <condition>
                    Always
                    <data>
                        High
                        <name>level</name>
                    </data>
                    <data>
                        changed
                        <name>direction</name>
                    </data>
                </condition>
                <event>
                    Task run status changed
                    <data>
                        Done
                        <name>status</name>
                    </data>
                </event>
                <method>
                    HTTP Get
                    <data>
                        http://$hostname.$domain/scan/report/$name
                        <name>URL</name>
                    </data>
                </method>
            </create_escalator>";

    $logger->info("Creating a new scan escalator named $name");

    my $output = pf_run("omp -h $this->{_host} -p $this->{_port} -u $this->{_user} -w $this->{_pass} -X '$command'");

    # fetch response status and escalator id
    if ( $output =~
            /<create_escalator_response\ 
            status="([0-9]+)"\      # status code
            id="([a-zA-Z0-9\-]*)"   # task id
            /x ) {

        if ( $1 eq $RESPONSE_RESOURCE_CREATED ) {
            $logger->debug("Scan task named $name successfully created");
            $this->{_taskId} = $2;
            return 1;
        }
    }

    return 0;
}

=item createTarget

Create a target (a target is a host to scan)

=cut
sub createTarget {
    my $this = @_;
    my $logger = Log::Log4perl::get_logger($LOGGER_SCOPE);

    my $name    = $this->{_id};
    my $host    = $this->{_scanHost};
    my $command = "
            <create_target>
                <name>$name</name>
                <hosts>$host</hosts>
            </create_target>";

    $logger->info("Creating a new scan target named $name to scan host $host");

    my $output = pf_run("omp -h $this->{_host} -p $this->{_port} -u $this->{_user} -w $this->{_pass} -X '$command'");

    # fetch response status and target id
    if ( $output =~
            /<create_target_response\ 
            status="([0-9]+)"\      # status code
            id="([a-zA-Z0-9\-]*)"   # task id
            /x ) {

        if ( $1 eq $RESPONSE_RESOURCE_CREATED ) {
            $logger->debug("Scan target named $name successfully created");
            $this->{_targetId} = $2;
            return 1;
        }
    }

    $logger->error("SCAN ERROR CREATING TARGET: $output");

    return 0;
}

=item createTask

Create a task (a task is a scan) with the existing config id and previously created target and escalator

=cut
sub createTask {
    my $this  = @_;
    my $logger = Log::Log4perl::get_logger($LOGGER_SCOPE);

    my $name            = $this->{_id};
    my $config_id       = $Config{'scan'}{'openvas_configid'};
    my $target_id       = $this->{_targetId};
    my $escalator_id    = $this->{_escalatorId};
    my $command         = "
            <create_task>
                <name>$name</name>
                <config id=\"$config_id\"/>
                <target id=\"$target_id\"/>
                <escalator id=\"$escalator_id\"/>
            </create_task>";

    $logger->info("Creating a new scan task named $name to scan target ID $target_id");

    my $output = pf_run("omp -h $this->{_host} -p $this->{_port} -u $this->{_user} -w $this->{_pass} -X '$command'");

    # fetch response status and task id
    if ( $output =~
            /<create_task_response\ 
            status="([0-9]+)"\      # status code
            id="([a-zA-Z0-9\-]*)"   # task id
            /x ) {

        if ( $1 eq $RESPONSE_RESOURCE_CREATED ) {
            $logger->debug("Scan task named $name successfully created");
            $this->{_taskId} = $2;
            return 1;
        }
    }

    return 0;
}

=item getReport

Retrieve the report associated with a task once the associated task is done
When retrieving a report in other format than XML, we received the report in base64 encoding.

=cut
sub getReport {
    my $this = @_;
    my $logger = Log::Log4perl::get_logger($LOGGER_SCOPE);

    my $report_id           = $this->{_reportId};
    my $report_format_id    = $Config{'scan'}{'openvas_reportformatid'}; 
    my $command             = "<get_reports report_id=\"$report_id\" format_id=\"$report_format_id\"/>";

    $logger->info("Getting the report $report_id for finished scan task");

    my $output = pf_run("omp -h $this->{_host} -p $this->{_port} -u $this->{_user} -w $this->{_pass} -X '$command'");

    # fetch response status and report
    if ( $output =~
            /<get_reports_response\ 
            status="([0-9]+)"       # status code
            [^\<]+[\<][^\>]+[\>]    # get to the report
            ([a-zA-Z0-9\=]*)        # report base64 encoded
            /x ) {

        if ( $1 eq $RESPONSE_OK ) {
            $logger->info("Report id $report_id successfully fetched");
            $this->{_report} = decode_base64($2);   # we need to decode the base64 report
            return 1;
        }
    }

    return 0;
}

=item new

Create a new Openvas scanning object with the required attributes

=cut
sub new {
    my ( $class, %data ) = @_;
    my $logger = Log::Log4perl::get_logger($LOGGER_SCOPE);

    $logger->debug("Instantiating a new pf::scan::openvas scanning object");

    my $this = bless {
            '_id'               => undef,
            '_host'             => undef,
            '_port'             => undef,
            '_user'             => undef,
            '_pass'             => undef,
            '_scanHost'         => undef,
            '_scanMac'          => undef,
            '_targetId'         => undef,
            '_escalatorId'      => undef,
            '_taskId'           => undef,
            '_reportId'         => undef,
            '_report'           => undef,
            '_configId'         => undef,
            '_reportFormatId'   => undef
    }, $class;

    foreach my $value ( keys %data ) {
        $this->{$value} = $data{$value};
    }

    # OpenVAS specific attributes
    $this->{_configId}          = $Config{'scan'}{'openvas_configid'};
    $this->{_reportFormatId}    = $Config{'scan'}{'openvas_reportformatid'};

    return $this;
}

=item startScan

That's where we use all of these method to run a scan

=cut
sub startScan {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger($LOGGER_SCOPE);

    $this->createTarget();
    $this->createEscalator();
    $this->createTask();
    $this->startTask();
}

=item startTask

Start a scanning task with the previously created target and escalator

=cut
sub startTask {
    my $this = @_;
    my $logger = Log::Log4perl::get_logger($LOGGER_SCOPE);

    my $task_id = $this->{_taskId};
    my $command = "<start_task task_id=\"$task_id\"/>";

    $logger->info("Starting scan task id $task_id");

    my $output = pf_run("omp -h $this->{_host} -p $this->{_port} -u $this->{_user} -w $this->{_pass} -X '$command'");

    # fetch response status and report id
    if ( $output =~
            /<start_task_response\ 
            status="([0-9]+)"[^\<]+[\<] # status code
            report_id>([a-zA-Z0-9\-]*)  # report id
            /x ) {

        if ( $1 eq $RESPONSE_REQUEST_SUBMITTED ) {
            $logger->debug("Scan task id $task_id successfully started");
            $this->{_reportId} = $2;
            return 1;
        }
    }

    return 0;
}

=back

=head1 AUTHOR

Derek Wuelfrath <dwuelfrath@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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
