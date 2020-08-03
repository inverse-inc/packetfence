package pf::scan::tenableio;


use warnings;
use strict;
use diagnostics;

use base('pf::scan');

use pf::util;
use pf::config qw(%Config);
use pf::log;
use Log::Log4perl; 
use Readonly;
use Net::TenableIO;
use Data::Dumper qw(Dumper);
use pf::security_event;
use pf::constants;
use pf::constants::trigger;
use pf::constants::scan qw($STATUS_CLOSED $SCAN_SECURITY_EVENT_ID $PRE_SCAN_SECURITY_EVENT_ID $POST_SCAN_SECURITY_EVENT_ID $STATUS_STARTED);
use XML::LibXML::Reader;

sub new{
    my ( $class, %data ) = @_;
    my $logger = get_logger;

    $logger->debug("Instantiating a new pf::scan::tenableio scanning object");


    my $self = bless {
            '_id'                     => undef,
            '_url'                    => undef,
            '_accessKey'              => undef,
            '_secretKey'              => undef,
            '_password'               => undef,
            '_scanIp'                 => undef,
            '_scanMac'                => undef,
            '_report'                 => undef,
            '_tenableio_clientpolicy' => undef,
            '_type'                   => undef,
            '_status'                 => undef,
            '_oses'                   => undef,
            '_categories'             => undef,
            '_scannername'            => undef,
            '_folderId'               => undef,
    }, $class;

    foreach my $value ( keys %data ) {
        $self->{'_' . $value} = $data{$value};
    }

    return $self;
}

sub startScan {
    my ( $self ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $url        = $self->{_url};
    my $accessKey  = $self->{_accessKey};
    my $secretKey  = $self->{_secretKey};
    my $host       = $self->{_scanIp};
    my $mac        = $self->{_scanMac};
    my $policy     = $self->{_tenableio_clientpolicy};
    my $scanner    = $self->{_scannername};
    my $folderid   = $self->{_folderId};

    my $scan_security_event_id = $POST_SCAN_SECURITY_EVENT_ID;
    $scan_security_event_id = $SCAN_SECURITY_EVENT_ID if ($self->{'_registration'});
    $scan_security_event_id = $PRE_SCAN_SECURITY_EVENT_ID if ($self->{'_pre_registration'});

    my $io = Net::TenableIO->new($url);

    $io->auth($accessKey, $secretKey);

    # Filtering agent list to check if nessus agent is installed in the host

    my %filters = ();
    $filters{'f'} = 'name:match:'.$host;
    
    my $agent_data = $io->get_agents_list( %filters );

    if ( $agent_data->{'agents'}->[0]->{'name'} ) {

        # Getting Agent ID
        my $agent_id = $agent_data->{'agents'}->[0]->{'id'};
        $logger->info("Agent ID: $agent_id");

        # Creating agent group for initial scan. Obtaining Group UUID and ID

        my %params = ();
        my $agent_group_name  = 'Baseline_'.$host;
        $params{'f'} = 'name:match:'.$agent_group_name;
        my $group_id;
        my $group_uuid;

        my $agent_groups = $io->get_agent_group_list(%params);
    
        if ($agent_groups->{'groups'}->[0]->{'name'}) {
            $group_id = $agent_groups->{'groups'}->[0]->{'id'};
            $group_uuid = $agent_groups->{'groups'}->[0]->{'uuid'};
            $logger->debug("Group $agent_group_name exist");
            $logger->debug("group_id: $group_id");
            $logger->debug("group_uuid: $group_uuid");
        } else {
            my %temp_params=();
            $temp_params{'name'} = 'Baseline_'.$host;
            $logger->warn("Create the group ".$temp_params{'name'});
            my $response_add = $io->add_agent_group( %temp_params );
            $group_id   = $response_add->{'id'};
            $logger->debug("group_id: $group_id");
        }

        # Adding agent to the group 'Register Agent'
        my %ids = ();
        $ids{'agent_id'} = $agent_id;
        $ids{'group_id'} = $group_id;
        $io->add_agent_to_group( %ids );

        # Getting template UUID of the scan policy
        my $policy_id="";
        my $policy_list = $io->get_policies_list();
        my $tmp = $policy_list->{'policies'};
        my $length = @$tmp;
    
        my $policy_uuid;
        for (my $i=0; $i<=$length; $i++){
            if ($policy_list->{'policies'}->[$i]->{'name'} eq $policy) {
                $policy_id = $policy_list->{'policies'}->[$i]->{'id'};
                last;
            }
        }

        # Generating a new scan with the previous params

        my $scanname = "pf-".$host."-agent";
        my $scan_id = $io->add_agent_scan(
            scan_template  => $scanner,
            name           => $scanname,
            description    => 'Scan from PacketFence',
            policy_id      => $policy_id,
            agentGroup     => [ $group_uuid ],
            folderid       => $folderid,
        );

        if ( $scan_id eq "") {
            $logger->warn("Failled to create the scan");
            return $scan_security_event_id;
        }

        my $epoch   = time;
        my $date    = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime($epoch));
        my $id	= generate_id($epoch, $mac);
        $self->{'_id'} = $id;

        my $launch = $io->launch_scans($scan_id);
    
        $logger->info("executing TenableIO scan with this policy ".$policy);
        $self->{'_status'} = $pf::scan::STATUS_STARTED;
        $self->statusReportSyncToDb();
    
        my $scan_status = $io->get_scans_status($scan_id);

        my $counter = 0;
        while ($io->get_scans_status($scan_id) ne "completed"){
            if ($counter > 3600) {
                $logger->info("Nessus scan is older than 1 hour...");
                return $scan_security_event_id;
            }
            $logger->info("TenableIO is scanning the host $host");
            sleep 300;
            if ($io->get_scans_status($scan_id) eq "canceled"){
                return $scan_security_event_id;
            }
            $logger->info("Scan status is: $scan_status");
            $counter = $counter + 300;
        }

        # Get the report
	my $file_nessus = $io->export_agent_scan(
            scanid => $scan_id,
            format_ => 'nessus',
        );


        my $export_status = $io->check_scan_export_status(
            scan => $scan_id,
            file => $file_nessus->{'file'},
        );

        my $file_id = $file_nessus->{'file'};
        while ($io->check_scan_export_status(scan => $scan_id,file => $file_nessus->{'file'})->{'status'} ne 'ready') {
            sleep 2;
        }

        $self->{'_report'} = $io->download_agent_scan(scan => $scan_id, file => $file_nessus->{'file'},);

        $io->delete_scan($scan_id);

        $io->delete_agent_group($group_id);
   
        $self->parse_scan_report($scan_security_event_id);

    } else {
        $logger->info("Nessus agent is not installed on the device");
        return $TRUE;
    }
}

sub parse_scan_report {
    my ( $self , $scan_security_event_id) = @_;

    my $logger = get_logger();

    my $host       = $self->{_scanIp};
    my $mac        = $self->{_scanMac};
    my $type       = $self->{_type};

    my $plugin_result;
    my $dom = XML::LibXML->load_xml(string => $self->{'report'});
    my $reportItem = $dom->findnodes('/NessusClientData_v2/Report/ReportHost/ReportItem');

    my ($plugin, $severity, $attr3, $cchname, @control_hash, %audit_hash);

    foreach my $i (1..$reportItem->size) {
        my $node = $reportItem->get_node($i);
        if (($plugin = $node->getAttribute('pluginID')) && ($severity = $node->getAttribute('severity')) && ($cchname = $node->getChildrenByTagName('cm:compliance-check-name')) ){
             $attr3 = $cchname->to_literal;
             $plugin_result .= $plugin.".".$severity."--".$attr3."\n";
        }
    }

    my @each_vuln = split(/\n/, $plugin_result);
    my $failed_scan=0;
    foreach my $current_vuln (@each_vuln) {
        # Parse nstatvulns format
        my @plugin_controlName = split("--", $current_vuln);
        my $trigger_id =  $plugin_controlName[0];
        
        $logger->info("Calling violation_trigger for host: $host, mac: $mac, type: $type, trigger: $trigger_id");
        my $security_event_added = security_event_trigger( { 'mac' => $mac, 'tid' => $trigger_id, 'type' => $type } );

        # If a security_event has been added, consider the scan failed
        if ( $security_event_added ) {
            $failed_scan = 1;
        }

    }

    # The way we accomplish the above workflow is to differentiate by checking if special security_event exists or not
    if ( my $security_event_id = security_event_exist_open($mac, $scan_security_event_id) ) {
        $logger->trace("Scan is completed and there is an open scan security_event. We have something to do!");

        # We passed the scan so we can close the scan security_event
        if ( !$failed_scan ) {
            my $apiclient = pf::api::jsonrpcclient->new;
            my %data = (
               'security_event_id' => $scan_security_event_id,
               'mac' => $mac,
               'reason' => 'manage_vclose',
            );

            $apiclient->notify('close_security_event', %data );

        # Scan completed but a security_event has been found
        # HACK: we empty the security_event's ticket_ref field which we use to track if scan is in progress or not
        } else {
            $logger->debug("Modifying security_event id $security_event_id to empty its ticket_ref field");
            security_event_modify($security_event_id, (ticket_ref => ""));
        }
    }

    $self->setStatus($STATUS_CLOSED);
    $self->statusReportSyncToDb();
     
}
1;
