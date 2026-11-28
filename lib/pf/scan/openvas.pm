package pf::scan::openvas;

=head1 NAME

pf::scan::openvas

=cut

=head1 DESCRIPTION

pf::scan::openvas is a module to add OpenVAS scanning option.

It drives a Greenbone (OpenVAS) manager through the Greenbone Management Protocol (GMP) over SSH.
This is how Greenbone appliances expose GMP. A Community Edition gvmd only listens on a unix socket,
which must be made reachable with an SSH account that forwards to it.

=cut

use strict;
use warnings;

use pf::log;
use Readonly;
use XML::LibXML;

use base ('pf::scan');

use pf::CHI;
use pf::constants;
use pf::constants::scan qw(
    $SCAN_SECURITY_EVENT_ID $PRE_SCAN_SECURITY_EVENT_ID $POST_SCAN_SECURITY_EVENT_ID $STATUS_STARTED $STATUS_CLOSED
    $OPENVAS_DEFAULT_CONFIG_ID $OPENVAS_DEFAULT_SCANNER_ID $OPENVAS_DEFAULT_PORT_LIST_ID $OPENVAS_DEFAULT_DELETE_SCANS
);
use pf::util;
use pf::security_event;
use Time::HiRes qw(time);

sub description { 'Openvas Scanner' }

# Timeout in milliseconds of a GMP request
Readonly our $GMP_TIMEOUT           => 60_000;
# Size of the end of the buffer searched for the closing tag of a GMP response
Readonly our $GMP_RESPONSE_TAIL     => 1024;

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

=item gmpConnect

Open the SSH channel to the GMP service and authenticate the GMP user

=cut

sub gmpConnect {
    my ($self) = @_;
    my $logger = get_logger();

    my ($ssh_username, $ssh_password) = @{$self}{qw(_openvas_ssh_username _openvas_ssh_password)};
    # No default: the SSH account depends on the OpenVAS server and a built-in password must not be assumed
    if (!length($ssh_username // "") || !length($ssh_password // "")) {
        $logger->error("Cannot reach the GMP service on $self->{_ip}: the SSH username and password of the scan engine are not configured");
        return;
    }
    my ($ssh, $channel);
    eval {
        require Net::SSH2;
        $ssh = Net::SSH2->new();
        $ssh->timeout($GMP_TIMEOUT);
        $ssh->connect($self->{_ip}, $self->{_port} || 22) or die "unable to connect: " . ($ssh->error)[2] . "\n";
        $ssh->auth(username => "$ssh_username", password => "$ssh_password") or die "unable to authenticate SSH user $ssh_username: " . ($ssh->error)[2] . "\n";
        $channel = $ssh->channel() or die "unable to open a channel: " . ($ssh->error)[2] . "\n";
        # The GMP service is attached to the session itself, so there is no command to run
        $channel->exec('') or die "unable to start the GMP session: " . ($ssh->error)[2] . "\n";
    };
    if ($@) {
        chomp(my $error = $@);
        $logger->error("Cannot reach the GMP service on $self->{_ip}: $error");
        return;
    }

    @{$self}{qw(_ssh _channel)} = ($ssh, $channel);
    my $credentials = '<credentials><username>' . _xml_escape($self->{_username}) . '</username><password>' . _xml_escape($self->{_password}) . '</password></credentials>';
    if (!$self->gmpCommand("<authenticate>$credentials</authenticate>", 'authenticate')) {
        $self->gmpDisconnect();
        return;
    }

    return $TRUE;
}

=item gmpDisconnect

Close the GMP session

=cut

sub gmpDisconnect {
    my ($self) = @_;
    my ($ssh, $channel) = delete @{$self}{qw(_ssh _channel)};
    $channel->close() if $channel;
    $ssh->disconnect() if $ssh;
}

=item gmpCommand

Send a GMP command and return the root element of the response when its status is a success.
The description is used for logging instead of the command, which can hold credentials.

=cut

sub gmpCommand {
    my ($self, $command, $description) = @_;
    my $logger = get_logger();

    my $channel = $self->{_channel};
    my $sent = 0;
    while ($sent < length($command)) {
        my $written = $channel->write(substr($command, $sent));
        if (!$written) {
            $logger->error("Cannot send the GMP command $description: " . ($self->{_ssh}->error)[2]);
            return;
        }
        $sent += $written;
    }

    my $output = $self->_gmpReadResponse();
    if (!defined $output) {
        $logger->error("No complete response to the GMP command $description: " . ($self->{_ssh}->error)[2]);
        return;
    }

    my $response = eval { XML::LibXML->load_xml(string => $output)->documentElement };
    if (!$response) {
        $logger->error("Cannot parse the response to the GMP command $description: $@");
        return;
    }

    my $status = $response->getAttribute('status') // '';
    if ($status !~ /^2\d\d$/) {
        $logger->warn("GMP command $description failed with status $status: " . ($response->getAttribute('status_text') // ''));
        return;
    }

    return $response;
}

=item _gmpReadResponse

Read a GMP response from the channel.
A response is a single XML element whose name never appears nested in it, so it is complete once that element is closed.
Only the end of the buffer is searched, a report can be several megabytes.

=cut

sub _gmpReadResponse {
    my ($self) = @_;
    my $channel = $self->{_channel};
    my $buffer = '';
    my $root;
    while (1) {
        my $read = $channel->read(my $chunk, 65536);
        return if !$read;
        $buffer .= $chunk;
        if (!defined $root) {
            ($root) = $buffer =~ /\A\s*(?:<\?xml[^>]*\?>\s*)?<([\w\-]+)/;
            next if !defined $root;
        }
        # An empty element, ex: <delete_task_response status="200" status_text="OK"/>
        # Cheap on a large buffer: anchored at the start and stopped by the first >
        return $buffer if $buffer =~ m{\A\s*(?:<\?xml[^>]*\?>\s*)?<\Q$root\E\b[^>]*/>\s*\z};
        my $tail = length($buffer) > $GMP_RESPONSE_TAIL ? substr($buffer, -$GMP_RESPONSE_TAIL) : $buffer;
        return $buffer if $tail =~ m{</\Q$root\E>\s*\z};
    }
}

=item createTarget

Create a target (a target is a host to scan)

=cut

sub createTarget {
    my ( $self ) = @_;
    my $logger = get_logger();

    my $name = $self->_get_scan_id();
    my $target_host = $self->{_scanIp};
    my $port_list_id = $self->{_openvas_portlistid} || $OPENVAS_DEFAULT_PORT_LIST_ID;

    $logger->info("Creating a new scan target named $name for host $target_host");

    my $response = $self->gmpCommand(
        '<create_target><name>' . _xml_escape($name) . '</name><hosts>' . _xml_escape($target_host) . '</hosts><port_list id="' . _xml_escape($port_list_id) . '"/></create_target>',
        "create_target $name",
    );
    if (!$response) {
        $logger->warn("There was an error creating scan target named $name");
        return;
    }

    $self->{_targetId} = $response->getAttribute('id');
    $logger->info("Scan target named $name successfully created with id: $self->{_targetId}");
    return $TRUE;
}

=item createTask

Create a task (a task is a scan) with the existing config id and previously created target and alert

=cut

sub createTask {
    my ( $self )  = @_;
    my $logger = get_logger();

    my $name = $self->_get_scan_id();

    $logger->info("Creating a new scan task named $name");

    my $response = $self->gmpCommand($self->_get_task_string($name, $self->{_openvas_configid} || $OPENVAS_DEFAULT_CONFIG_ID, $self->{_targetId}), "create_task $name");
    if (!$response) {
        $logger->warn("There was an error creating scan task named $name");
        return;
    }

    $self->{_taskId} = $response->getAttribute('id');
    $logger->info("Scan task named $name successfully created with id: $self->{_taskId}");
    return $TRUE;
}

=item startTask

Start a scanning task with the previously created target and alert

=cut

sub startTask {
    my ( $self ) = @_;
    my $logger = get_logger();

    my $name    = $self->_get_scan_id();
    my $task_id = $self->{_taskId};

    $logger->info("Starting scan task named $name");

    my $response = $self->gmpCommand('<start_task task_id="' . _xml_escape($task_id) . '"/>', "start_task $name");
    if (!$response) {
        $logger->warn("There was an error starting the scan task named $name");
        return;
    }

    my $report_id = $response->findvalue('report_id');
    $logger->info("Scan task named $name successfully started");
    $self->setScanInfo($name, {
        report_id => $report_id,
        task_id   => $task_id,
        target_id => $self->{_targetId},
        mac       => $self->{_scanMac},
        ip        => $self->{_scanIp},
        id        => $self->{_id},
        scan_id   => $self->{_scanner_id},
    });
    $self->{'_reportId'} = $report_id;
    $self->{'_status'} = $STATUS_STARTED;
    $self->statusReportSyncToDb();
    return $TRUE;
}

=item deleteScan

Delete a task, with its reports, and a target from the manager

=cut

sub deleteScan {
    my ($self, $task_id, $target_id) = @_;
    # A target can only be deleted once no task uses it
    $self->gmpCommand('<delete_task task_id="' . _xml_escape($task_id) . '" ultimate="1"/>', "delete_task $task_id") if $task_id;
    $self->gmpCommand('<delete_target target_id="' . _xml_escape($target_id) . '" ultimate="1"/>', "delete_target $target_id") if $target_id;
}

=item processReport

Retrieve the report associated with a task in the XML format.

Report processing's duty is to ensure that the proper security event will be triggered.

=cut

sub processReport {
    my ( $self, $task_name ) = @_;
    my $logger = get_logger();

    my $info = $self->getScanInfo($task_name);
    if (!$info) {
        $logger->error("Cannot find the scan info of the task named $task_name, it was already processed or it expired");
        return;
    }
    my $report_id = $info->{report_id};
    my $mac       = $info->{mac};

    $logger->info("Getting the scan report for the finished scan task named $task_name");

    return if !$self->gmpConnect();
    my $response = $self->gmpCommand('<get_reports report_id="' . _xml_escape($report_id) . '" details="1" ignore_pagination="1"/>', "get_reports $report_id");
    if (!$response) {
        $logger->warn("There was an error fetching the scan report for the task named $task_name");
        $self->gmpDisconnect();
        return;
    }

    $logger->info("Report id $report_id successfully fetched for task named $task_name");
    # Process a report once, even when the hook is called again
    $self->removeScanInfo($task_name);
    my %oids = map { $_->value => 1 } $response->findnodes('report/report/results/result/nvt/@oid');
    for my $oid (sort keys %oids) {
        security_event_trigger( { 'mac' => $mac, 'tid' => $oid, 'type' => 'OpenVAS' } );
    }

    $self->deleteScan(@{$info}{qw(task_id target_id)}) if isenabled($self->{_openvas_delete_scans} // $OPENVAS_DEFAULT_DELETE_SCANS);
    $self->gmpDisconnect();

    if ($info->{id}) {
        @{$self}{qw(_id _reportId _status)} = ($info->{id}, $report_id, $STATUS_CLOSED);
        $self->statusReportSyncToDb();
    }

    return $TRUE;
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
            '_openvas_ssh_username'     => undef,
            '_openvas_ssh_password'     => undef,
            '_openvas_alertid'          => undef,
            '_openvas_configid'         => undef,
            '_openvas_scannerid'        => undef,
            '_openvas_portlistid'       => undef,
            '_openvas_delete_scans'     => undef,
            '_targetId'         => undef,
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

That's where we use all of these method to run a scan.
Returns the scan security event ID when the scan could not be started.

=cut

sub startScan {
    my ( $self ) = @_;
    my $logger = get_logger();

    my $scan_security_event_id = $pf::constants::scan::POST_SCAN_SECURITY_EVENT_ID;
    $scan_security_event_id = $pf::constants::scan::SCAN_SECURITY_EVENT_ID if ($self->{'_registration'});
    $scan_security_event_id = $pf::constants::scan::PRE_SCAN_SECURITY_EVENT_ID if ($self->{'_pre_registration'});

    @{$self}{qw(_targetId _taskId)} = ();
    my $started;
    if ($self->gmpConnect()) {
        $started = $self->createTarget() && $self->createTask() && $self->startTask();
        $self->deleteScan(@{$self}{qw(_taskId _targetId)}) if !$started;
        $self->gmpDisconnect();
    }

    # Clear the scan ID
    $self->{_scanId} = undef;

    return $scan_security_event_id if !$started;

    my $apiclient = pf::api::jsonrpcclient->new;
    my %data = (
       'security_event_id' => $scan_security_event_id,
       'mac' => $self->{'_scanMac'},
    );
    $apiclient->notify('close_security_event', %data );
    return;
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

=head2 removeScanInfo

Remove the scan info of a scan ID

=cut

sub removeScanInfo {
    my ($self, $scan_id) = @_;
    return $self->cache->remove("info-$scan_id");
}

=head2 _xml_escape

Escape a value for usage in a GMP command

=cut

sub _xml_escape {
    my ($s) = @_;
    $s = "" . ($s // '');
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    $s =~ s/'/&apos;/g;
    return $s;
}

=item _get_task_string

create_task string creation.

=cut

sub _get_task_string {
    my ($self, $name, $config_id, $target_id) = @_;
    my $scanner_id = $self->{_openvas_scannerid} || $OPENVAS_DEFAULT_SCANNER_ID;
    my $alert = $self->{_openvas_alertid} ? '<alert id="' . _xml_escape($self->{_openvas_alertid}) . '"/>' : '';
    return '<create_task>'
        . '<name>' . _xml_escape($name) . '</name>'
        . '<config id="' . _xml_escape($config_id) . '"/>'
        . '<target id="' . _xml_escape($target_id) . '"/>'
        . '<scanner id="' . _xml_escape($scanner_id) . '"/>'
        . $alert
        . '</create_task>';
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

Copyright (C) 2005-2026 Inverse inc.

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
