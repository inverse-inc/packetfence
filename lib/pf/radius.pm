package pf::radius;

=head1 NAME

pf::radius - Module that deals with everything RADIUS related

=head1 SYNOPSIS

The pf::radius module contains the functions necessary for answering RADIUS queries.
RADIUS is the network access component known as AAA used in 802.1x, MAC authentication, etc.
This module acts as a proxy between our FreeRADIUS perl module's SOAP requests
(packetfence.pm) and PacketFence core modules.

All the behavior contained here can be overridden in lib/pf/radius/custom.pm.

=cut

use strict;
use warnings;

use pf::log;
use Readonly;

use pf::authentication;
use pf::Connection;
use pf::constants;
use pf::constants::trigger qw($TRIGGER_TYPE_ACCOUNTING);
use pf::constants::role qw($VOICE_ROLE);
use pf::constants::realm;
use pf::constants::domain qw($NTLM_REDIS_CACHE_HOST $NTLM_REDIS_CACHE_PORT);
use pf::error qw(is_error);
use pf::config qw(
    $ROLE_API_LEVEL
    $WIRELESS
    $VOIP
    $NO_VOIP
    %Config
    %ConfigDomain
    $ACCOUNTING_POLICY_TIME
    $ACCOUNTING_POLICY_BANDWIDTH
    $WIRED
    $WIRED_MAC_AUTH
    $WIRED_802_1X
    %ConfigFloatingDevices
    $WIRELESS_MAC_AUTH
    $WIRELESS_802_1X
    $VIRTUAL_VPN
    $WEBAUTH_WIRED
    $WEBAUTH_WIRELESS
);
use pf::client;
use pf::locationlog;
use pf::node;
use pf::Switch;
use pf::SwitchFactory;
use pf::util;
use pf::config::util;
use pf::security_event;
use pf::role::custom $ROLE_API_LEVEL;
use pf::floatingdevice::custom;
# constants used by this module are provided by
use pf::radius::constants;
use List::Util qw(first);
use pf::util::statsd qw(called);
use pf::StatsD::Timer;
use pf::accounting;
use pf::cluster;
use pf::api::queue;
use pf::access_filter::radius;
use pf::registration;
use pf::access_filter::switch;
use pf::role::pool;
use pf::dal;
use pf::security_event;
use pf::constants::security_event qw($LOST_OR_STOLEN);
use pf::Redis;
use pf::constants::eap_type qw($EAP_TLS $MS_EAP_AUTHENTICATION $EAP_PSK);
use pf::person;
use pf::factory::mfa;
use MIME::Base64;

our $VERSION = 1.03;

=head1 SUBROUTINES

=over

=cut

=item * new - get a new instance of the pf::radius object

=cut

sub new {
    my $logger = get_logger();
    $logger->debug("instantiating new pf::radius object");
    my ( $class, %argv ) = @_;
    my $self = bless { }, $class;
    return $self;
}

=item * authorize - handling the RADIUS authorize call

Returns an arrayref (tuple) with element 0 being a response code for Radius and second element an hash meant
to fill the Radius reply (RAD_REPLY). The arrayref is to workaround a quirk in SOAP::Lite and have everything in result()

See http://search.cpan.org/~byrne/SOAP-Lite/lib/SOAP/Lite.pm#IN/OUT,_OUT_PARAMETERS_AND_AUTOBINDING

=cut

# WARNING: You cannot change the return structure of this sub unless you also update its clients (like the SOAP 802.1x
# module). This is because of the way perl mangles a returned hash as a list. Clients would get confused if you add a
# scalar return without updating the clients.
sub authorize {
    my $timer = pf::StatsD::Timer->new();
    my ($self, $radius_request) = @_;
    local $pf::dal::node::TRIGGER_NODE_DISCOVERED = 1;
    my $logger = $self->logger;
    my ($do_auto_reg, %autoreg_node_defaults, $action);

    my($switch_mac, $switch_ip,$source_ip,$stripped_user_name,$realm) = $self->_parseRequest($radius_request);
    
    my $RAD_REPLY_REF;

    $self->handleNtlmCaching($radius_request);

    $logger->debug("instantiating switch");
    my $switch = pf::SwitchFactory->instantiate({ switch_mac => $switch_mac, switch_ip => $switch_ip, controllerIp => $switch_ip}, {radius_request => $radius_request});

    # is switch object correct?
    if (!$switch) {
        $logger->warn(
            "Can't instantiate switch ($switch_ip). This request will be failed. "
            ."Are you sure your switches.conf is correct?"
        );
        $RAD_REPLY_REF = [ $RADIUS::RLM_MODULE_FAIL, ('Reply-Message' => "Switch is not managed by PacketFence") ];
        goto AUDIT;
    }

    my ($nas_port_type, $eap_type, $mac, $port, $user_name, $nas_port_id, $session_id, $ifDesc) = $switch->parseRequest($radius_request);

    if (!$mac) {
        $RAD_REPLY_REF = [$RADIUS::RLM_MODULE_FAIL, ('Reply-Message' => "Mac is empty")];
        goto AUDIT;
    }

    Log::Log4perl::MDC->put( 'mac', $mac );
    my $connection = pf::Connection->new;
    $connection->identifyType($nas_port_type, $eap_type, $mac, $user_name, $switch, $radius_request);
    my $connection_type = $connection->attributesToBackwardCompatible;
    my $connection_sub_type = $connection->subType;
    # switch-specific information retrieval
    my $ssid;
    if (($connection_type & $WIRELESS) == $WIRELESS) {
        $ssid = $switch->extractSsid($radius_request);
        $logger->debug("SSID resolved to: $ssid") if (defined($ssid));
    }

    $self->handleConnectionTypeChange($mac, $connection);

    {
        my $timer = pf::StatsD::Timer->new({ 'stat' => called() . ".getIfIndex", level => 7});
        $port = $switch->getIfIndexByNasPortId($nas_port_id) || $self->_translateNasPortToIfIndex($connection_type, $switch, $port);
    }

    my $args = {
        switch => $switch,
        switch_mac => $switch_mac,
        switch_ip => $switch_ip,
        source_ip => $source_ip,
        stripped_user_name => $stripped_user_name,
        realm => $realm,
        nas_port_type => $nas_port_type,
        eap_type => $eap_type // '',
        mac => $mac,
        ifIndex => $port,
        ifDesc => $ifDesc,
        user_name => $user_name,
        username => $user_name,
        nas_port_id => $nas_port_type // '',
        session_id => $session_id,
        connection_type => $connection_type,
        connection_sub_type => $connection_sub_type,
        radius_request => $radius_request,
        scope => "packetfence.post-auth",
        connection => $connection,
    };

    $logger->trace( sub { "received a radius authorization request with parameters: ".
        "nas port type => $args->{nas_port_type}, switch_ip => ($switch_ip), EAP-Type => $args->{eap_type}, ".
        "mac => [$mac], port => $port, username => \"$user_name\"" });

    # let's check if an old port sec entry needs to be removed in another switch
    $self->_handleStaticPortSecurityMovement($args);

    $logger->info("handling radius autz request: from switch_ip => ($switch_ip), "
        . "connection_type => " . connection_type_to_str($connection_type) . ","
        . " switch_mac => ".( defined($switch_mac) ? "($switch_mac)" : "(Unknown)" ).", mac => [$mac], port => $port, username => \"$user_name\""
        . ( defined $ssid ? ", ssid => $ssid" : '' ) );

    my ($status_code, $node_obj) = pf::dal::node->find_or_create({"mac" => $mac});
    if (is_error($status_code)) {
        $node_obj = pf::dal::node->new({"mac" => $mac});
    }
    $node_obj->_load_locationlog;
    if ($status_code != $STATUS::CREATED) {
        # update last_seen of MAC address as some activity from it has been seen
        $node_obj->update_last_seen();
    }

    #define the current connection value to instantiate the correct portal
    my $options = {};

    # Handling machine auth detection
    $self->_machine_auth_detection($user_name,\$node_obj,\$options);

    if (defined($session_id)) {
        $node_obj->sessionid($session_id);
    }

    my $switch_id =  $switch->{_id};

    # verify if switch supports this connection type
    if (!$self->_isSwitchSupported($args)) {
        # if not supported, return
        $RAD_REPLY_REF = $self->_switchUnsupportedReply($args);
        goto CLEANUP;
    }
    my %info;


    my $role_obj = new pf::role::custom();

    $args->{'ssid'} = $ssid;
    $args->{'node_info'} = $node_obj;
    $args->{'fingerbank_info'} = pf::node::fingerbank_info($mac, $node_obj);
    $args->{'owner'} = person_view_simple($node_obj->{'pid'});
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('preProcess', $args);
    if ($rule) {
        my ($reply, $status) = $filter->handleAnswerInRule({%$rule, merge_answer => 'enabled' }, $args, $radius_request);
        %$radius_request = %$reply;
        $args->{'user_name'} = $switch->parseRequestUsername($radius_request);
        if ($user_name ne $args->{'user_name'}) {
            $logger->info("Username has been changed from '$user_name' to ".$args->{'user_name'});
    }
        $args->{'username'} = $args->{'user_name'};
        $self->_machine_auth_detection($args->{'user_name'},\$node_obj,\$options);
    }
    my $result = $role_obj->filterVlan('IsPhone',$args);
    # determine if we need to perform automatic registration
    # either the switch detects that this is a phone or we take the result from the vlan filters
    if (defined($result)) {
        $args->{'isPhone'} = $result;
    } elsif ($port) {
        $args->{'isPhone'} =$switch->isPhoneAtIfIndex($mac, $port);
    } else {
        $args->{'isPhone'} = $FALSE;
    }

    $options->{'last_connection_sub_type'} = $args->{'connection_sub_type'};
    $options->{'last_connection_type'}     = connection_type_to_str($args->{'connection_type'});
    $options->{'last_switch'}              = $switch_id;
    $options->{'last_port'}                = $port if defined $port && length($port);
    $options->{'last_vlan'}                = $args->{'vlan'} if (defined($args->{'vlan'}));
    $options->{'last_ssid'}                = $args->{'ssid'} if (defined($args->{'ssid'}));
    $options->{'last_dot1x_username'}      = $args->{'user_name'} if (defined($args->{'user_name'}));
    $options->{'realm'}               = $args->{'realm'} if (defined($args->{'realm'}));
    $options->{'radius_request'}      = $args->{'radius_request'};
    $options->{'fingerbank_info'}     = $args->{'fingerbank_info'};

    my $profile = pf::Connection::ProfileFactory->instantiate($args->{'mac'},$options);
    $args->{'profile'} = $profile;
    $args->{'portal'} = $profile->getName;

    (my $dpsk_accept, $connection, $connection_type, $connection_sub_type, $args) = $self->handleUnboundDPSK($radius_request, $switch, $profile, $connection, $args);
    if(!$dpsk_accept) {
        $logger->error("Unable to find a valid PSK for this request. Rejecting user.");
        $RAD_REPLY_REF = [ $RADIUS::RLM_MODULE_USERLOCK, ('Reply-Message' => "Invalid PSK") ];
        goto CLEANUP;
    }

    $args->{'autoreg'} = 0;
    # should we auto-register? let's ask the VLAN object
    my ( $status, $status_msg );
    $do_auto_reg = $role_obj->shouldAutoRegister($args);
    if ($do_auto_reg) {
        $args->{'autoreg'} = 1;
        (my $attributes, $action , %autoreg_node_defaults) = $role_obj->getNodeInfoForAutoReg($args);
        $args->{'action'} = $action;
        $args = { %$args, %$attributes } if (ref($attributes) eq 'HASH');
        $node_obj->merge(\%autoreg_node_defaults);
        $logger->debug("[$mac] auto-registering node");
        # automatic registration
        $info{autoreg} = 1;
        ($status, $status_msg) = pf::registration::setup_node_for_registration($node_obj, \%info, $action);
        if (is_error($status)) {
            $logger->error("auto-registration of node failed $status_msg");
            $do_auto_reg = 0;
            $node_obj->{status} = "unreg";
            $RAD_REPLY_REF = [ $RADIUS::RLM_MODULE_USERLOCK, ('Reply-Message' => $status_msg) ];
            goto CLEANUP;
        }
    }

    # if it's an IP Phone, let _authorizeVoip decide (extension point)
    if ($args->{'isPhone'} && isenabled($switch->{_VoIPEnabled})) {
        $RAD_REPLY_REF = $self->_authorizeVoip($args);
        $args->{'user_role'} = $VOICE_ROLE;
        goto CLEANUP;
    }

    # if switch is not in production, we don't interfere with it: we log and we return OK
    if (!$switch->isProductionMode()) {
        $logger->warn("Should perform access control on switch ($switch_id) but the switch "
            ."is not in production -> Returning ACCEPT");
        $RAD_REPLY_REF = [ $RADIUS::RLM_MODULE_OK, ('Reply-Message' => "Switch is not in production, so we allow this request") ];
        goto CLEANUP;
    }

    # Check if a floating just plugged in
    $self->_handleAccessFloatingDevices($args);

    # Fetch VLAN depending on node status
    my $role = $role_obj->fetchRoleForNode($args);

    if (defined($role->{attributes}) && exists($role->{attributes})) {
        $args = { %$args, %{$role->{'attributes'}} };
    }

    if (!exists($args->{'action'})) {
        $args->{'action'} = $role->{action};
    }
    my $vlan;
    $args->{'node_info'}{'source'} = $role->{'source'} if (defined($role->{'source'}) && $role->{'source'} ne '');
    $args->{'node_info'}{'portal'} = $role->{'portal'} if (defined($role->{'portal'}) && $role->{'portal'} ne '');
    $info{source} = $args->{node_info}{source};
    $info{portal} = $args->{node_info}{portal};
    $args->{'wasInline'} = $role->{wasInline};
    $args->{'user_role'} = $role->{role};

    my $switch_filter = pf::access_filter::switch->new;
    $switch_filter->filterSwitch('radius_authorize',\$switch, $args);

    if (isenabled($switch->{_VlanMap})) {
        $vlan = $switch->getVlanByName($role->{role}) if (isenabled($switch->{_VlanMap}));
        $args->{'vlan'} = $vlan;
        my $vlanpool = new pf::role::pool;
        $vlan = $vlanpool->getVlanFromPool($args);
    }
    $vlan = $role->{vlan} || $vlan || 0;
    $args->{'vlan'} = $vlan;

    #closes old locationlog entries and create a new one if required
    #TODO: Better deal with INLINE RADIUS
    $switch->synchronize_locationlog($port, $vlan, $mac,
        $args->{'isPhone'} ? $VOIP : $NO_VOIP, $connection_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm, $args->{'user_role'}, $ifDesc
    ) if ( (!$role->{wasInline}) && ($vlan ne "-1") );

    # does the switch support Dynamic VLAN Assignment, bypass if using Inline
    if (!$switch->supportsRadiusDynamicVlanAssignment() && !$role->{wasInline}) {
        $logger->info(
            "Switch doesn't support Dynamic VLAN assignment. " .
            "Setting VLAN with SNMP on ($switch_id) ifIndex $port to $vlan"
        );
        # WARNING: passing empty switch-lock for now
        # When the _setVlan of a switch who can't do RADIUS VLAN assignment uses the lock we will need to re-evaluate
        $switch->_setVlan( $port, $vlan, undef, {} );
    }

    $RAD_REPLY_REF = $switch->returnRadiusAccessAccept($args);

CLEANUP:
    # If the device is lost or stolen, then ensure we execute the actions of the violation so the emails can be sent on connection
    $self->check_lost_stolen($mac);
    if ($do_auto_reg) {
        pf::registration::finalize_node_registration($node_obj, {}, $options, $pf::constants::realm::RADIUS_CONTEXT);
    }
    $status = $node_obj->save;
    if (is_error($status)) {
        $logger->error("Cannot save $mac error ($status)");
    }

    # cleanup
    $switch->disconnectRead();
    $switch->disconnectWrite();

AUDIT:
    $args->{'time'} = time;
    push @$RAD_REPLY_REF, $self->_addRadiusAudit($args);
    return $RAD_REPLY_REF;
}

=item accounting

=cut

sub accounting {
    my $timer = pf::StatsD::Timer->new();
    my ($self, $radius_request, $headers) = @_;
    my $logger = $self->logger;

    my ( $switch_mac, $switch_ip, $source_ip, $stripped_user_name, $realm ) = $self->_parseRequest($radius_request);

    $logger->debug("instantiating switch");
    my $switch = pf::SwitchFactory->instantiate( { switch_mac => $switch_mac, switch_ip => $switch_ip, controllerIp => $switch_ip }, {radius_request => $radius_request} );

    # is switch object correct?
    if ( !$switch ) {
        $logger->warn( "Can't instantiate switch ($switch_ip). This request will be failed. "
                . "Are you sure your switches.conf is correct?" );
        $pf::StatsD::statsd->increment(called() . ".error" );
        return [ $RADIUS::RLM_MODULE_FAIL, ( 'Reply-Message' => "Switch is not managed by PacketFence" ) ];
    }

    my ($nas_port_type, $eap_type, $mac, $port, $user_name, $nas_port_id, $session_id, $ifDesc) = $switch->parseRequest($radius_request);

    # update last_seen of MAC address as some activity from it has been seen
    node_update_last_seen($mac);
    my $acct_status_type = $radius_request->{'Acct-Status-Type'};

    my $isStart  = $acct_status_type  == $ACCOUNTING::START;
    my $isStop   = $acct_status_type  == $ACCOUNTING::STOP;
    my $isUpdate = $acct_status_type  == $ACCOUNTING::INTERIM_UPDATE;

    my $connection = pf::Connection->new;
    $connection->identifyType($nas_port_type, $eap_type, $mac, $user_name, $switch, $radius_request);
    my $connection_type = $connection->attributesToBackwardCompatible;
    my $connection_sub_type = $connection->subType;

    if($isStart || $isUpdate){
        pf::accounting->cache->set($mac, $radius_request);
        pf::fingerbank::process($mac);
    }

    if ($isStop || $isUpdate) {

        $port = $switch->getIfIndexByNasPortId($nas_port_id) || $self->_translateNasPortToIfIndex($connection_type, $switch, $port);

        if($isStop){
            #handle radius floating devices
            $self->_handleAccountingFloatingDevices($switch, $mac, $port);
        }

    }

    if(isenabled($Config{radius_configuration}{filter_in_packetfence_accounting})){
        my %RAD_REPLY_REF;
        my $node_obj = node_attributes($mac);
        my $ssid;
        if (($connection_type & $WIRELESS) == $WIRELESS) {
            $ssid = $switch->extractSsid($radius_request);
        }
        my $args = {
            switch => $switch,
            switch_mac => $switch_mac,
            switch_ip => $switch_ip,
            source_ip => $source_ip,
            stripped_user_name => $stripped_user_name,
            realm => $realm,
            nas_port_type => $nas_port_type,
            eap_type => $eap_type // '',
            mac => $mac,
            ifIndex => $port,
            ifDesc => $ifDesc,
            user_name => $user_name,
            nas_port_id => $nas_port_type // '',
            session_id => $session_id,
            connection_type => $connection_type,
            connection_sub_type => $connection_sub_type,
            radius_request => $radius_request,
            ssid => $ssid,
            node_info => $node_obj,
            owner => person_view_simple($node_obj->{'pid'}),
            scope => "packetfence.accounting",
            connection => $connection,
        };
        my $filter = pf::access_filter::radius->new;
        my $rule = $filter->test($headers->{'X-FreeRADIUS-Server'}.".".$headers->{'X-FreeRADIUS-Section'}, $args);
        my ($reply, $status) = $filter->handleAnswerInRule($rule,$args,\%RAD_REPLY_REF);
        return [$status, %$reply];
    }
    return [ $RADIUS::RLM_MODULE_OK, ('Reply-Message' => "Accounting ok") ];
}

=item update_locationlog_accounting

Update the location log based on the accounting information

=cut

sub update_locationlog_accounting {
    my $timer = pf::StatsD::Timer->new({ sample_rate => 0.05, level => 6 });
    my ($self, $radius_request) = @_;
    my $logger = $self->logger;

    my ( $switch_mac, $switch_ip, $source_ip, $stripped_user_name, $realm ) = $self->_parseRequest($radius_request);

    $logger->debug("instantiating switch");
    my $switch = pf::SwitchFactory->instantiate( { switch_mac => $switch_mac, switch_ip => $switch_ip, controllerIp => $switch_ip }, {radius_request => $radius_request} );

    # is switch object correct?
    if ( !$switch ) {
        $logger->warn( "Can't instantiate switch ($switch_ip). This request will be failed. "
                . "Are you sure your switches.conf is correct?" );
        $pf::StatsD::statsd->increment(called() . ".error" );
        return [ $RADIUS::RLM_MODULE_FAIL, ( 'Reply-Message' => "Switch is not managed by PacketFence" ) ];
    }

    if ($switch->supportsRoamingAccounting()) {
        my ($nas_port_type, $eap_type, $mac, $port, $user_name, $nas_port_id, $session_id, $ifDesc) = $switch->parseRequest($radius_request);
        my $locationlog_mac = locationlog_last_entry_mac($mac);
        if (defined($locationlog_mac) && ref($locationlog_mac) eq 'HASH') {
            my $connection_type = str_to_connection_type($locationlog_mac->{connection_type});
            my $connection_sub_type = $locationlog_mac->{connection_sub_type};
            my $ssid;
            if (($connection_type & $WIRELESS) == $WIRELESS) {
                $ssid = $switch->extractSsid($radius_request);
                $logger->debug("SSID resolved to: $ssid") if (defined($ssid));
            }
            my $vlan;
            $vlan = $radius_request->{'Tunnel-Private-Group-ID'} if ( (defined( $radius_request->{'Tunnel-Type'}) && $radius_request->{'Tunnel-Type'} eq '13') && (defined($radius_request->{'Tunnel-Medium-Type'}) && $radius_request->{'Tunnel-Medium-Type'} eq '6') );
            $port = $switch->getIfIndexByNasPortId($nas_port_id) || $self->_translateNasPortToIfIndex($connection_type, $switch, $port);
            $switch->synchronize_locationlog($port, $vlan, $mac, undef, $connection_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm, $locationlog_mac->{role}, $ifDesc);
            return [ $RADIUS::RLM_MODULE_OK, ('Reply-Message' => "Update locationlog from accounting ok") ];
        }
    }
    return [ $RADIUS::RLM_MODULE_OK, ('Reply-Message' => "Did not update locationlog from the accounting") ];
}

=item * _parseRequest

Takes FreeRADIUS' RAD_REQUEST hash and process it to return
  AP-MAC
  Network Device IP
  Source-IP

=cut

sub _parseRequest {
    my ($self, $radius_request) = @_;
    my $logger = get_logger();
    my $ap_mac = $self->extractApMacFromRadiusRequest($radius_request);
    # freeradius 2 provides the client IP in NAS-IP-Address not Client-IP-Address (non-standard freeradius1 attribute)
    my $networkdevice_ip = $radius_request->{'NAS-IP-Address'} || $radius_request->{'Client-IP-Address'};
    my $source_ip = $radius_request->{'FreeRADIUS-Client-IP-Address'};
    my $stripped_user_name;
    if (defined($radius_request->{'Stripped-User-Name'})) {
        $stripped_user_name = $radius_request->{'Stripped-User-Name'};
    }
    my $realm;
    if (defined($radius_request->{'Realm'})) {
        # Handling possible FreeRADIUS multiple realms
        if ( ref($radius_request->{'Realm'}) eq 'ARRAY' ) {
            $realm = $radius_request->{'Realm'}->[0];
            $logger->info("RADIUS request contains more than one realm. Keeping the first one '$realm'");
        } else {
            $realm = $radius_request->{'Realm'};
        }
    }
    return ($ap_mac, $networkdevice_ip, $source_ip, $stripped_user_name, $realm);
}

sub extractApMacFromRadiusRequest {
    my ($self, $radius_request) = @_;
    my $logger = get_logger();
    # it's put in Called-Station-Id
    # ie: Called-Station-Id = "aa-bb-cc-dd-ee-ff:Secure SSID" or "aa:bb:cc:dd:ee:ff:Secure SSID"
    if (defined($radius_request->{'Called-Station-Id'})) {
        if ($radius_request->{'Called-Station-Id'} =~ /^
            # below is MAC Address with supported separators: :, - or nothing
            ([a-f0-9]{2}([-:]?[a-f0-9]{2}){5})
        /ix) {
            return clean_mac($1);
        } else {
            $logger->info("Unable to extract MAC from Called-Station-Id: ".$radius_request->{'Called-Station-Id'});
        }
    }

    return;
}


=item * _authorizeVoip - RADIUS authorization of VoIP

All of the parameters from the authorize method call are passed just in case someone who override this sub
need it. However, connection_type is passed instead of nas_port_type and eap_type and the switch object
instead of switch_ip.

Returns the same structure as authorize(), see it's POD doc for details.

=cut

sub _authorizeVoip {
    my $timer = pf::StatsD::Timer->new({ sample_rate => 0.05, level => 7 });
    my ($self, $args) = @_;
    my $logger = $self->logger;

    if (!$args->{'switch'}->supportsRadiusVoip()) {
        $logger->warn("Returning failure to RADIUS.");
        $args->{'switch'}->disconnectRead();
        $args->{'switch'}->disconnectWrite();
        return [
            $RADIUS::RLM_MODULE_FAIL,
            ('Reply-Message' => "Server reported: VoIP authorization over RADIUS not supported for this network device")
        ];
    }
    $args->{'switch'}->synchronize_locationlog($args->{'ifIndex'}, $args->{'switch'}->getVlanByName($VOICE_ROLE), $args->{'mac'}, $VOIP, $args->{'connection_type'}, $args->{'connection_sub_type'}, $args->{'user_name'}, $args->{'ssid'}, undef, undef, $VOICE_ROLE, $args->{ifDesc});

    my %RAD_REPLY = $args->{'switch'}->getVoipVsa();
    $args->{'switch'}->disconnectRead();
    $args->{'switch'}->disconnectWrite();
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnAuthorizeVoip', $args);
    my ($reply, $status) = $filter->handleAnswerInRule($rule,$args,\%RAD_REPLY);
    return [$status, %$reply];
}

=item * _translateNasPortToIfIndex - convert the number in NAS-Port into an ifIndex only when relevant

=cut

sub _translateNasPortToIfIndex {
    my ($self, $conn_type, $switch, $port) = @_;
    my $logger = $self->logger;

    if (($conn_type & $WIRED) == $WIRED) {
        $logger->trace("(" . $switch->{_id} . ") translating NAS-Port to ifIndex for proper accounting");
        return $switch->NasPortToIfIndex($port);
    } elsif (($conn_type & $WIRELESS) == $WIRELESS && !defined($port)) {
        $logger->debug("(" . $switch->{_id} . ") got empty NAS-Port parameter, setting 0 to avoid breakage");
        $port = 0;
    }
    return $port;
}

=item * _isSwitchSupported

Determines if switch is supported by current connection type.

=cut

sub _isSwitchSupported {
    my ($self, $args) = @_;
    my $logger = $self->logger;

    if ($args->{'connection_type'} == $WIRED_MAC_AUTH) {
        return $args->{'switch'}->supportsWiredMacAuth();
    } elsif ($args->{'connection_type'} == $WIRED_802_1X) {
        return $args->{'switch'}->supportsWiredDot1x();
    } elsif ($args->{'connection_type'} == $WEBAUTH_WIRED) {
        return $args->{'switch'}->supportsWiredWebAuth();
    } elsif ($args->{'connection_type'} == $WEBAUTH_WIRELESS) {
        return $args->{'switch'}->supportsWirelessWebAuth();
    } elsif ($args->{'connection_type'} == $WIRELESS_MAC_AUTH) {
        # TODO implement supportsWirelessMacAuth (or supportsWireless)
        $logger->trace("Wireless doesn't have a supports...() call for now, always say it's supported");
        return $TRUE;
    } elsif ($args->{'connection_type'} == $WIRELESS_802_1X) {
        # TODO implement supportsWirelessMacAuth (or supportsWireless)
        $logger->trace("Wireless doesn't have a supports...() call for now, always say it's supported");
        return $TRUE;
    }
}

=item * _switchUnsupportedReply - what is sent to RADIUS when a switch is unsupported

=cut

sub _switchUnsupportedReply {
    my ($self, $args) = @_;
    my $logger = $self->logger;

    $logger->warn("(" . $args->{'switch'}->{_id} . ") Sending REJECT since switch is unsupported");
    $args->{'switch'}->disconnectRead();
    $args->{'switch'}->disconnectWrite();
    return [$RADIUS::RLM_MODULE_FAIL, ('Reply-Message' => "Network device does not support this mode of operation")];
}

sub _handleStaticPortSecurityMovement {
    my $timer = pf::StatsD::Timer->new({level => 7});
    my ($self,$args) = @_;
    my $logger = $self->logger;
    #determine if $mac is authorized elsewhere
    my $locationlog_mac = locationlog_view_open_mac($args->{'mac'});
    #Nothing to do if there is no location log
    if ( !defined($locationlog_mac) || $locationlog_mac eq "0" ) {
        return undef;
    }

    my $old_switch_id = $locationlog_mac->{'switch'};
    #Nothing to do if it is the same switch
    if ( $old_switch_id eq $args->{'switch'}->{_id} ) {
        return undef;
    }

    my $oldSwitch = pf::SwitchFactory->instantiate($old_switch_id, {radius_request => $args->{radius_request}});
    if (!$oldSwitch) {
        $logger->error("Can not instantiate switch $old_switch_id !");
        return;
    }
    my $old_port   = $locationlog_mac->{'port'};
    if (!$oldSwitch->isStaticPortSecurityEnabled($old_port)){
        $logger->debug("Stopping port-security handling in radius since old location is not port sec enabled");
        return;
    }
    my $old_vlan   = $locationlog_mac->{'vlan'};
    my $is_old_voip = is_node_voip($args->{'mac'});

    # We check if the mac moved in a different switch. If it's a different port we don't care.
    # Let's say MAB + port sec on the same switch is a bit too extreme

    $logger->debug("has still open locationlog entry at $old_switch_id ifIndex $old_port");

    $logger->info("Will try to check on this node's previous switch if secured entry needs to be removed. ".
        "Old Switch IP: $old_switch_id");
    my $secureMacAddrHashRef = $oldSwitch->getSecureMacAddresses($old_port);
    if ( exists( $secureMacAddrHashRef->{$args->{'mac'}} ) ) {
        my $fakeMac = $oldSwitch->generateFakeMac( $is_old_voip, $old_port );
        $logger->info("de-authorizing $args->{'mac'} (new entry $fakeMac) at old location $old_switch_id ifIndex $old_port");
        $oldSwitch->authorizeMAC( $old_port, $args->{'mac'}, $fakeMac,
            ( $is_old_voip ? $oldSwitch->getVoiceVlan($old_port) : $oldSwitch->getVlan($old_port) ),
            ( $is_old_voip ? $oldSwitch->getVoiceVlan($old_port) : $oldSwitch->getVlan($old_port) ) );
    } else {
        $logger->info("MAC not found on node's previous switch secure table or switch inaccessible.");
    }
    locationlog_update_end_mac($args->{'mac'});
}

=item * _handleFloatingDevices

Takes care of handling the flow for the RADIUS floating devices when receiving an Accept-Request

=cut

sub _handleAccessFloatingDevices{
    my ($self, $args) = @_;
    my $logger = $self->logger;
    if( exists( $ConfigFloatingDevices{$args->{'mac'}} ) ){
        my $floatingDeviceManager = new pf::floatingdevice::custom();
        $floatingDeviceManager->enableMABFloating($args->{'mac'}, $args->{'switch'}, $args->{'ifIndex'});
    }
}

=item * _handleAccountingFloatingDevices

Takes care of handling the flow for the RADIUS floating devices when receiving an accounting stop

=cut

sub _handleAccountingFloatingDevices{
    my ($self, $switch, $mac, $port) = @_;
    my $logger = $self->logger;
    $logger->debug("Verifying if $mac has to be handled as a floating");
    if (exists( $ConfigFloatingDevices{$mac} ) ){
        my $floatingDeviceManager = new pf::floatingdevice::custom();

        my $floating_location = locationlog_view_open_mac($mac);
        $port = $floating_location->{port};
        if(!defined($port)){
            $logger->info("Cannot find locationlog entry for floating device $mac. Assuming floating device mode is off.");
            return;
        }

        $logger->info("Floating device $mac has just been detected as unplugged. Disabling floating device mode on $switch->{_ip} port $port");
        # close location log entry to remove the port from the floating mode.
        locationlog_update_end_mac($mac);
        # disable floating device mode on the port
        $floatingDeviceManager->disableMABFloating($switch, $port);
    }
}

=item logger

Return the current logger for the object

=cut

sub logger {
    my ($proto) = @_;
    return get_logger( ref($proto) || $proto );
}

=item switch_access

return RADIUS attributes or reject for switch login or VPN

=cut

sub switch_access {
    my ($self, $radius_request) = @_;
    my $logger = $self->logger;
    my $timer = pf::StatsD::Timer->new();
    my($switch_mac, $switch_ip,$source_ip,$stripped_user_name,$realm) = $self->_parseRequest($radius_request);
    $logger->debug("instantiating switch");
    my $switch = pf::SwitchFactory->instantiate({ switch_mac => $switch_mac, switch_ip => $switch_ip, controllerIp => $switch_ip}, {radius_request => $radius_request});
    # is switch object correct?
    if ( !$switch ) {
        $logger->warn( "Can't instantiate switch ($switch_ip). This request will be failed. "
                . "Are you sure your switches.conf is correct?" );
        $pf::StatsD::statsd->increment(called() . ".error" );
        return [ $RADIUS::RLM_MODULE_FAIL, ( 'Reply-Message' => "Switch is not managed by PacketFence" ) ];
    }
    my ($nas_port_type, $eap_type, $mac, $port, $user_name, $nas_port_id, $session_id, $ifDesc) = $switch->parseRequest($radius_request);

    my $connection = pf::Connection->new;
    $connection->identifyType($nas_port_type, $eap_type, $mac, $user_name, $switch, $radius_request);
    my $connection_type = $connection->attributesToBackwardCompatible;
    my $connection_sub_type = $connection->subType;
    my $password = $radius_request->{'User-Password'};
    if (exists($radius_request->{'PacketFence-UserPassword'})) {
        $password = decode_base64($radius_request->{'PacketFence-UserPassword'});
    }
    my $otp;

    # is switch object correct?
    if (!$switch) {
        $logger->warn(
            "Unknown switch ($switch_ip). This request will be failed."
        );
        return [ $RADIUS::RLM_MODULE_FAIL, ('Reply-Message' => "Switch is not managed by PacketFence") ];
    }

    $logger->info("handling radius autz request: from switch_ip => ($switch_ip), "
        . "connection_type => " . connection_type_to_str($connection_type) . ","
        . "switch_mac => ".( defined($switch_mac) ? "($switch_mac)" : "(Unknown)" ).", mac => [$mac], port => ".( defined($port) ? "($port)" : "(Unknown)" ).", username => \"$user_name\"" );

    if ( !$switch->canDoCliAccess && !$switch->supportsVPN() && !$connection->isServiceTemplate && !$connection->isACLDownload)  {
        $logger->warn("CLI Access is not permit on this switch $switch->{_id}");
        return [ $RADIUS::RLM_MODULE_FAIL, ('Reply-Message' => "CLI or VPN Access is not allowed by PacketFence on this switch") ];
    }

    my $args = {
        switch => $switch,
        switch_mac => $switch_mac,
        switch_ip => $switch_ip,
        source_ip => $source_ip,
        stripped_user_name => $stripped_user_name,
        realm => $realm,
        username => $user_name,
        user_name => $user_name,
        radius_request => $radius_request,
        switch_group => $switch->{_group},
        switch_id => $switch->{_id},
        connection => $connection,
        scope => "packetfence.post-auth",
    };

    my $options = {};

    $options->{'last_connection_sub_type'} = $connection_sub_type;
    $options->{'last_connection_type'}     = connection_type_to_str($connection_type);
    $options->{'last_switch'}              = $switch->{_id};
    $options->{'last_port'}                = $port if defined $port && length($port);
    $options->{'last_vlan'}                = $args->{'vlan'} if (defined($args->{'vlan'}));
    $options->{'last_ssid'}                = $args->{'ssid'} if (defined($args->{'ssid'}));
    $options->{'last_dot1x_username'}      = $args->{'user_name'} if (defined($args->{'username'}));
    $options->{'realm'}                    = $args->{'realm'} if (defined($args->{'realm'}));
    $options->{'radius_request'}           = $args->{'radius_request'};

    my @sources = @{pf::authentication::getInternalAuthenticationSources()};
    my ( $return, $message, $extra );

    if ($connection->isVPN()) {
        $return = $self->vpn($args, $options, \@sources, \$extra, \$otp, \$password);
        return $return if (ref($return) eq 'ARRAY');
    } elsif ($connection->isServiceTemplate || $connection->isACLDownload) {
        return  $self->advancedAccess($args, $options);
    } else {
        $return = $self->cli($args, $options, \@sources, \$extra, \$otp, \$password);
        return $return if (ref($return) eq 'ARRAY');
    }
}

sub advancedAccess {
    my ($self, $args, $options) = @_;
    return $args->{'switch'}->returnRadiusAdvanced($args, $options);
}


sub authenticate {
    my ($self, $args, $sources, $source_id, $extra, $otp, $password) = @_;
    my $logger = $self->logger;
    my ($return, $message);
    ( $return, $message, $$source_id, $$extra ) = pf::authentication::authenticate( {
            'username' =>  $args->{'radius_request'}->{'User-Name'},
            'password' =>  $$password,
            'rule_class' => $Rules::ADMIN,
            'context' => $pf::constants::realm::RADIUS_CONTEXT,
        }, @$sources );

    if ( !( defined($return) && $return == $TRUE ) ) {
        $logger->info("User $args->{'username'} tried to login in $args->{'switch'}{'_id'} but authentication failed");
        return [ $RADIUS::RLM_MODULE_USERLOCK, ( 'Reply-Message' => "Authentication failed on PacketFence" ) ];
    }
}

sub vpn {
    my ($self, $args, $options, $sources, $extra, $otp, $password) = @_;
    my $logger = $self->logger;

    my ($message);

    my ($nas_port_type, $eap_type, $mac, $port, $user_name, $nas_port_id, $session_id, $ifDesc) = $args->{'switch'}->parseVPNRequest($args->{'radius_request'});

    $args->{'nas_port_type'} = $nas_port_type // '';
    $args->{'eap_type'} = $eap_type // '';
    $args->{'mac'} = $mac // '';
    $args->{'ifIndex'} = $port // '';
    $args->{'ifDesc'} = $ifDesc // '';
    $args->{'nas_port_id'} = $nas_port_type // '';
    $args->{'session_id'} = $session_id // '';

    my $return = $self->mfa_pre_auth($args, $options, $sources, $extra, $otp, $password);
    return $return if (ref($return) eq 'ARRAY');

    if (defined($mac)) {
        Log::Log4perl::MDC->put( 'mac', $mac );
        my $role_obj = new pf::role::custom();

        my ($status_code, $node_obj) = pf::dal::node->find_or_create({"mac" => $mac});
        if (is_error($status_code)) {
            $node_obj = pf::dal::node->new({"mac" => $mac});
        }
        $node_obj->_load_locationlog;
        if ($status_code != $STATUS::CREATED) {
            # update last_seen of MAC address as some activity from it has been seen
            $node_obj->update_last_seen();
        }

        if (defined($session_id)) {
            $node_obj->sessionid($session_id);
        }
        $args->{'node_info'} = $node_obj;
        $args->{'node_info'}->{'last_seen'} = pf::util::mysql_date();
        $args->{'fingerbank_info'} = pf::node::fingerbank_info($mac, $node_obj);
        $options->{'fingerbank_info'} = $args->{'fingerbank_info'};

        my $profile = pf::Connection::ProfileFactory->instantiate($args->{'mac'},$options);
        $args->{'profile'} = $profile;
        @$sources = $profile->getFilteredAuthenticationSources($args->{'stripped_user_name'}, $args->{'realm'});

        $args->{'autoreg'} = 0;
        # should we auto-register? let's ask the role object
        my ( %info, $status, $status_msg, $do_auto_reg);
        $do_auto_reg = $role_obj->shouldAutoRegister($args);
        if ($do_auto_reg) {
            $args->{'autoreg'} = 1;
            my ($attributes, $action , %autoreg_node_defaults) = $role_obj->getNodeInfoForAutoReg($args);
            $args->{'action'} = $action;
            $args = { %$args, %$attributes } if (ref($attributes) eq 'HASH');
            $node_obj->merge(\%autoreg_node_defaults);
            $logger->debug("[$mac] auto-registering node");
            # automatic registration
            $info{autoreg} = 1;
            ($status, $status_msg) = pf::registration::setup_node_for_registration($node_obj, \%info, $action);
            if (is_error($status)) {
                $logger->error("auto-registration of node failed $status_msg");
                $do_auto_reg = 0;
                $node_obj->{status} = "unreg";
                return [ $RADIUS::RLM_MODULE_USERLOCK, ('Reply-Message' => $status_msg) ];
            }
        }

        my $role = $role_obj->fetchRoleForNode($args);
        $args->{'user_role'} = $role->{role};
        $status = $node_obj->save;
        if (is_error($status)) {
            $logger->error("Cannot save $mac error ($status)");
        }
        $args->{'switch'}->synchronize_locationlog($port, undef, $mac,
            $args->{'isPhone'} ? $VOIP : $NO_VOIP, $VIRTUAL_VPN, undef, $user_name, undef, $args->{'stripped_user_name'}, $args->{'realm'}, $args->{'user_role'}, $ifDesc
        );
    }
    my $source_id = \@$sources;
    if (!defined($args->{'radius_request'}->{'MS-CHAP-Challenge'}) && ( !exists($args->{'radius_request'}->{"EAP-Type"}) || ( exists($args->{'radius_request'}->{"EAP-Type"}) && $args->{'radius_request'}->{"EAP-Type"} != $EAP_TLS && $args->{'radius_request'}->{"EAP-Type"} != $MS_EAP_AUTHENTICATION ) ) ) {
        my $return = $self->authenticate($args, $sources, \$source_id, $extra, $otp, $password);
        return $return if (ref($return) eq 'ARRAY');
    }
    $return = $self->mfa_post_auth($args, $options, $sources, $source_id, $extra ,$otp, $password);
    return $return if (ref($return) eq 'ARRAY');

    return $self->returnRadiusVpn($args, $options, $sources, $source_id, $extra);
}

sub cli {
    my ($self, $args, $options, $sources, $extra, $otp, $password) = @_;
    my $logger = $self->logger;

    my $profile = pf::Connection::ProfileFactory->instantiate($FAKE_MAC,$options);
    $args->{'profile'} = $profile;
    @$sources = $profile->getFilteredAuthenticationSources($args->{'stripped_user_name'}, $args->{'realm'});

    my $source_id = \@$sources;
    my $return = $self->mfa_pre_auth($args, $options, $sources, $extra, $otp, $password);
    return $return if (ref($return) eq 'ARRAY');

    return $self->returnRadiusCli($args, $options, $sources, $source_id, $extra) if $return eq $TRUE;

    if (!defined($args->{'radius_request'}->{'MS-CHAP-Challenge'}) && ( !exists($args->{'radius_request'}->{"EAP-Type"}) || ( exists($args->{'radius_request'}->{"EAP-Type"}) && $args->{'radius_request'}->{"EAP-Type"} != $EAP_TLS && $args->{'radius_request'}->{"EAP-Type"} != $MS_EAP_AUTHENTICATION ) ) ) {
        my $return = $self->authenticate($args, $sources, \$source_id, $extra, $otp, $password);
        return $return if (ref($return) eq 'ARRAY');
    }

    $return = $self->mfa_post_auth($args, $options, $sources, $source_id, $extra ,$otp, $password);
    return $return if (ref($return) eq 'ARRAY');

    return $self->returnRadiusCli($args, $options, $sources, $source_id, $extra);
}

sub returnRadiusVpn{
    my ($self, $args, $options, $sources, $source_id, $extra) = @_;
    my $logger = $self->logger;
    if (!( defined($args->{'user_role'}) && $args->{'user_role'} ne "" )) {
        my $merged = { %$options, %$args };
        $merged->{'rule_class'} = $Rules::AUTH;
        $merged->{'context'} = $pf::constants::realm::RADIUS_CONTEXT;
        my $attributes;
        my $matched = pf::authentication::match2([@$sources], $merged, undef, \$attributes);

        my $values = $matched->{values};
        $args->{'user_role'} = $values->{$Actions::SET_ROLE};
    }
    return $args->{'switch'}->returnAuthorizeVPN($args);
}

sub returnRadiusCli{
    my ($self, $args, $options, $sources, $source_id, $extra) = @_;
    my $logger = $self->logger;
    my $merged = { %$options, %$args };
    $merged->{'rule_class'} = $Rules::AUTH;
    $merged->{'context'} = $pf::constants::realm::RADIUS_CONTEXT;
    my $attributes;
    my $matched = pf::authentication::match2([@$sources], $merged, undef, \$attributes);

    my $values = $matched->{values};
    $args->{'user_role'} = $values->{$Actions::SET_ROLE};

    $merged->{'rule_class'} = $Rules::ADMIN;
    $merged->{'context'} = $pf::constants::realm::RADIUS_CONTEXT;
    $merged->{'action'} = $Actions::SET_ACCESS_LEVEL;
    $matched = pf::authentication::match2($source_id, $merged, $extra, \$attributes);
    my $value = $matched->{values}{$Actions::SET_ACCESS_LEVEL} if $matched;
    if ($value) {
        my @values = split(',', $value);
        foreach $value (@values) {
            if (exists $pf::config::ConfigAdminRoles{$value}->{'ACTIONS'}->{'SWITCH_LOGIN_WRITE'}) {
                return $args->{'switch'}->returnAuthorizeWrite($args);
            }
            if (exists $pf::config::ConfigAdminRoles{$value}->{'ACTIONS'}->{'SWITCH_LOGIN_READ'}) {
                return $args->{'switch'}->returnAuthorizeRead($args);
            }
            if (exists $pf::config::ConfigAdminRoles{$value}->{'ACTIONS'}->{'SWITCH_PROBE'}) {
                return $args->{'switch'}->returnAuthorizeProbe($args);
            }
        }
        $logger->error("User $args->{'user_name'} has no role (Switches CLI - Read or Switches CLI - Write or Switches Probe) to permit to login in $args->{'switch'}{'_id'} ");
        return [ $RADIUS::RLM_MODULE_FAIL, ('Reply-Message' => "User has no role defined in PacketFence to allow switch login (SWITCH_LOGIN_READ or SWITCH_LOGIN_WRITE or SWITCH_PROBE)") ];
    } else {
        $logger->info("User $args->{'user_name'} has no role (Switches CLI - Read or Switches CLI - Write or Switches Probe) to permit to login in $args->{'switch'}{'_id'}");
        return [ $RADIUS::RLM_MODULE_FAIL, ('Reply-Message' => "User has no role defined in PacketFence to allow switch login (SWITCH_LOGIN_READ or SWITCH_LOGIN_WRITE or SWITCH_PROBE)") ];
    }
}

sub mfa_post_auth {
    my ($self, $args, $options, $sources, $source_id, $extra ,$otp, $password) = @_;
    my $logger = $self->logger;
    $logger->info("MFA Post Authentication");
    my $merged = { %$options, %$args };
    $merged->{'rule_class'} = $Rules::AUTH;
    $merged->{'context'} = $pf::constants::realm::RADIUS_CONTEXT;
    my $attributes;

    my $matched = pf::authentication::match2($source_id, $merged, $$extra, \$attributes);

    my $value = $matched->{values}{$Actions::TRIGGER_RADIUS_MFA} if $matched;
    if ($value) {
        my $mfa = pf::factory::mfa->new($value);
        # If the mfa method is secondary password do nothing, the mfa will be triggered on a second request.
        if ($mfa->radius_mfa_method eq 'second-password') {
            my $cache = pf::mfa->cache;
            if (!$cache->get($args->{'radius_request'}->{'User-Name'}." authenticated")) {
                $cache->set($args->{'radius_request'}->{'User-Name'}." authenticated", $TRUE, normalize_time($mfa->cache_duration));
            }
        } else {
            my $result = $mfa->check_user($args->{'radius_request'}->{'User-Name'}, $$otp);
            if ($result != $TRUE) {
                return [ $RADIUS::RLM_MODULE_FAIL, ('Reply-Message' => "Multi-Factor Authentication failed or triggered") ];
            }
        }
    }
}

sub mfa_pre_auth {
    my ($self, $args, $options, $sources, $extra, $otp, $password) = @_;
    my $logger = $self->logger;
    my $caller = (caller(1))[3];

    $logger->info("MFA Pre Authentication");
    # Special case where we need to check if there is a MFA config who exist and if we need to split the password field
    $args->{'mac'} = $FAKE_MAC unless defined($args->{'mac'});
    my $profile = pf::Connection::ProfileFactory->instantiate($args->{'mac'},$options);
    $args->{'profile'} = $profile;
    @$sources = $profile->getFilteredAuthenticationSources($args->{'stripped_user_name'}, $args->{'realm'});
    my $merged = { %$options, %$args };
    $merged->{'rule_class'} = $Rules::AUTH;
    $merged->{'context'} = $pf::constants::realm::RADIUS_CONTEXT;
    my $attributes;
    my $matched = pf::authentication::match2([@$sources], $merged, $$extra, \$attributes);
    my $source_id = \@$sources;
    # Verify if the user succeed the MFA on the portal
    my $value = $matched->{values}{$Actions::TRIGGER_PORTAL_MFA} if $matched;
    if ($value) {
        my $mfa = pf::factory::mfa->new($value);
        my $cache = pf::mfa->cache;
        if (isenabled($args->{switch}->{_PostMfaValidation}) && $cache->get($args->{'username'}."mfapreauth") && $cache->get($args->{'username'}."mfapostauth")) {
            $cache->remove($args->{'username'}."mfapostauth");
            $cache->remove($args->{'username'}."mfapreauth");
            return $self->returnRadiusVpn($args, $options, $sources, $source_id, $extra);
        }
        if (isenabled($args->{switch}->{_PostMfaValidation}) && $cache->get($args->{'username'}."mfapreauth") && !$cache->get($args->{'username'}."mfapostauth")) {
            return [ $RADIUS::RLM_MODULE_FAIL, ('Reply-Message' => "MFA portal verification failed") ];
        }
    }

    $value = $matched->{values}{$Actions::TRIGGER_RADIUS_MFA} if $matched;
    if ($value) {
        my $mfa = pf::factory::mfa->new($value);
        my $cache = pf::mfa->cache;
        if ($mfa->radius_mfa_method eq 'strip-otp' || $mfa->radius_mfa_method eq 'sms' || $mfa->radius_mfa_method eq 'phone') {
            # Previously did a authentication request ?
            if (my $infos = $cache->get($args->{'radius_request'}->{'User-Name'})) {
                my $result = $mfa->check_user($args->{'radius_request'}->{'User-Name'}, $$password, $infos->{'device'});
                if ($result != $TRUE) {
                    return [ $RADIUS::RLM_MODULE_FAIL, ('Reply-Message' => "MFA verification failed") ];
                } else {
                    if ($caller eq "pf::radius::vpn") {
                        return $self->returnRadiusVpn($args, $options, $sources, $source_id, $extra);
                } else {
                        return $TRUE;
                    }
                }
            }
            my @otp = split($mfa->split_char,$$password);
            $$password = $otp[0];
            $$otp = $otp[1];
        } elsif ($mfa->radius_mfa_method eq 'second-password') {
            if (my $authenticated = $cache->get($args->{'radius_request'}->{'User-Name'}." authenticated")) {
                if ($authenticated) {
                    my $result = $mfa->check_user($args->{'radius_request'}->{'User-Name'}, $$password);
                    if ($result != $TRUE) {
                        return [ $RADIUS::RLM_MODULE_FAIL, ('Reply-Message' => "MFA verification failed")];
                    } else {
                        if ($caller eq "pf::radius::vpn") {
                            return $self->returnRadiusVpn($args, $options, $sources, $source_id, $extra);
                        } else {
                            return $TRUE;
                        }
                    }
                } else {
                    my $device = $cache->get($args->{'radius_request'}->{'User-Name'});
                    my $result = $mfa->check_user($args->{'radius_request'}->{'User-Name'}, $$password, $device);
                    if ($result != $TRUE) {
                        return [ $RADIUS::RLM_MODULE_FAIL, ('Reply-Message' => "MFA verification failed") ];
                    } else {
                        if ($caller eq "pf::radius::vpn") {
                            return $self->returnRadiusVpn($args, $options, $sources, $source_id, $extra);
                        } else {
                            return $TRUE;
                        }
                    }
                }
            }
        }
    }
    return $FALSE;
}

our %ARGS_TO_RADIUS_ATTRIBUTES = (
    mac => 'PacketFence-Mac',
    user_name => 'PacketFence-UserName',
    ifIndex => 'PacketFence-IfIndex',
    isPhone => 'PacketFence-IsPhone',
    ssid => 'PacketFence-SSID',
    autoreg => 'PacketFence-AutoReg',
    eap_type => 'PacketFence-Eap-Type',
    connection_type => 'PacketFence-Connection-Type',
    user_role => 'PacketFence-Role',
    time => 'PacketFence-Request-Time',
    portal => 'PacketFence-Profile',
);

our %NODE_ATTRIBUTES_TO_RADIUS_ATTRIBUTES = (
    status => 'PacketFence-Status',
    source => 'PacketFence-Source',
    portal => 'PacketFence-Profile',
    computername => 'PacketFence-Computer-Name',
);

our %SWITCH_ATTRIBUTES_TO_RADIUS_ATTRIBUTES = (
    _id => 'PacketFence-Switch-Id',
    _ip => 'PacketFence-Switch-Ip-Address',
    _switchMac => 'PacketFence-Switch-Mac',
);

=item _addRadiusAudit

=cut

sub _addRadiusAudit {
    my ($self, $args) = @_;
    my $stash = {};
    _update_audit_stash($stash, \%ARGS_TO_RADIUS_ATTRIBUTES, $args);
    my $switch = $args->{switch};
    if ($switch) {
        _update_audit_stash($stash, \%SWITCH_ATTRIBUTES_TO_RADIUS_ATTRIBUTES, $switch);
    }
    my $node = $args->{node_info};
    if($node) {
        _update_audit_stash($stash, \%NODE_ATTRIBUTES_TO_RADIUS_ATTRIBUTES, $node);
    }
    $stash->{'PacketFence-Connection-Type'} = connection_type_to_str($stash->{'PacketFence-Connection-Type'})
      if exists $stash->{'PacketFence-Connection-Type'} && defined $stash->{'PacketFence-Connection-Type'};
    return (RADIUS_AUDIT => $stash);
}

sub _update_audit_stash {
    my ($stash, $lookup, $args) = @_;
    foreach my $key (keys %$lookup) {
        next unless exists $args->{$key} && defined $args->{$key};
        $stash->{$lookup->{$key}} = $args->{$key};
    }
}

=item handleNtlmCaching

Handle NTLM caching if necessary

=cut

sub handleNtlmCaching {
    my ($self, $radius_request) = @_;
    my $logger = get_logger;
    my $domain = $radius_request->{"PacketFence-Domain"};
    my $usedNtHash = $radius_request->{"PacketFence-NTCacheHash"};

    if($domain && isenabled($ConfigDomain{$domain}{ntlm_cache})) {
        my $radius_username = $radius_request->{'Stripped-User-Name'} || $radius_request->{'User-Name'};
        my $cache_key = "$domain.$radius_username";
        my $username = pf::domain::ntlm_cache::get_from_cache($cache_key);
        if (defined($usedNtHash) && $usedNtHash && defined($username)) {
            my $client = pf::api::queue_cluster->new(queue => "general");
            $client->notify_all("update_user_in_redis_cache", $domain, $username);
        }
        else {
            my $client = pf::api::queue->new(queue => "general");
            $client->notify("cache_user_ntlm", $domain, $radius_username);
        }
    }
}

=head2 checkConnectionTypeChange

Detect if a device has changed its transport type (wired vs wireless) since a MAC shouldn't switch from one to another

=cut

sub handleConnectionTypeChange {
    my ($self, $mac, $current_connection) = @_;
    if (isenabled($Config{network}{connection_type_change_detection})) {
        my $client = pf::api::queue->new(queue => "general");
        $client->notify("detect_connection_type_transport_change", $mac, $current_connection);
    }
}

=head2 radius_filter

Handle radius filter request

=cut

sub radius_filter {
    my ($self, $scope, $radius_request) = @_;
    my $logger = $self->logger;
    my ($do_auto_reg, %autoreg_node_defaults);
    my($switch_mac, $switch_ip,$source_ip,$stripped_user_name,$realm) = $self->_parseRequest($radius_request);
    my %RAD_REPLY_REF;

    $logger->debug("instantiating switch");
    my $switch = pf::SwitchFactory->instantiate({ switch_mac => $switch_mac, switch_ip => $switch_ip, controllerIp => $switch_ip}, {radius_request => $radius_request});

    # is switch object correct?
    if (!$switch) {
        $logger->warn(
            "Can't instantiate switch ($switch_ip). This request will be failed. "
            ."Are you sure your switches.conf is correct?"
        );
        return [ $RADIUS::RLM_MODULE_NOOP, ('Reply-Message' => "Switch is not managed by PacketFence") ];
    }

    my ($nas_port_type, $eap_type, $mac, $port, $user_name, $nas_port_id, $session_id, $ifDesc) = $switch->parseRequest($radius_request);

    if (!$mac) {
        #define manually the mac since in radius_filter it's not something mandatory
        $mac = "00:11:22:33:44:55";
    }
    Log::Log4perl::MDC->put( 'mac', $mac );
    my ($status_code, $node_obj) = pf::dal::node->find_or_create({"mac" => $mac});
    if (is_error($status_code)) {
        $node_obj = pf::dal::node->new({"mac" => $mac});
    }
    my $connection = pf::Connection->new;
    $connection->identifyType($nas_port_type, $eap_type, $mac, $user_name, $switch, $radius_request);
    my $connection_type = $connection->attributesToBackwardCompatible;
    my $connection_sub_type = $connection->subType;
    # switch-specific information retrieval
    my $ssid;
    if (($connection_type & $WIRELESS) == $WIRELESS) {
        $ssid = $switch->extractSsid($radius_request);
        $logger->debug("SSID resolved to: $ssid") if (defined($ssid));
    }
    my $args = {
        switch => $switch,
        switch_mac => $switch_mac,
        switch_ip => $switch_ip,
        source_ip => $source_ip,
        stripped_user_name => $stripped_user_name,
        realm => $realm,
        nas_port_type => $nas_port_type,
        eap_type => $eap_type // '',
        mac => $mac,
        ifIndex => $port,
        ifDesc => $ifDesc,
        user_name => $user_name,
        nas_port_id => $nas_port_type // '',
        session_id => $session_id,
        connection_type => $connection_type,
        connection_sub_type => $connection_sub_type,
        radius_request => $radius_request,
        ssid => $ssid,
        node_info => $node_obj,
        owner => person_view_simple($node_obj->{'pid'}),
        scope => $scope,
        connection => $connection,
    };

    my $options = {};

    $options->{'last_connection_sub_type'} = $connection_sub_type;
    $options->{'last_connection_type'}     = connection_type_to_str($connection_type);
    $options->{'last_switch'}              = $switch->{_id};
    $options->{'last_port'}                = $port if defined $port && length($port);
    $options->{'last_vlan'}                = $args->{'vlan'} if (defined($args->{'vlan'}));
    $options->{'last_ssid'}                = $args->{'ssid'} if (defined($args->{'ssid'}));
    $options->{'last_dot1x_username'}      = $args->{'user_name'} if (defined($args->{'username'}));
    $options->{'realm'}                    = $args->{'realm'} if (defined($args->{'realm'}));
    $options->{'radius_request'}           = $args->{'radius_request'};

    # Exception for cisco DACL
    if ($connection->isServiceTemplate || $connection->isACLDownload) {
        return  $self->advancedAccess($args, $options);
    }

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test($scope, $args);
    my ($reply, $status) = $filter->handleAnswerInRule($rule,$args,\%RAD_REPLY_REF);
    return [$status, %$reply];
}

=head2 check_lost_stolen

Check if device is lost or stolen and execute the actions (including email)

=cut

sub check_lost_stolen {
    my ($self, $mac) = @_;
    my $is_lost_stolen = security_event_exist_open($mac, $LOST_OR_STOLEN);

    if($is_lost_stolen) {
        pf::action::action_execute( $mac, $LOST_OR_STOLEN, "Endpoint has just connected on the network" );
    }
}

sub handleUnboundDPSK {
    my ($self, $radius_request, $switch, $profile, $connection, $args) = @_;
    my $logger = get_logger;

    if($profile->unboundDpskEnabled()) {
        my $accept = $FALSE;
        if(my $pid = $switch->find_user_by_psk($radius_request,$args)) {
            $logger->info("Unbound DPSK user found $pid. Changing this request to use the 802.1x logic");
            $connection->isMacAuth($FALSE);
            $connection->is8021X($TRUE);
            $connection->isEAP($TRUE);
            $connection->subType($EAP_PSK);
            $connection->_attributesToString;
            $args->{connection_type} = $connection->attributesToBackwardCompatible;
            $args->{connection_sub_type} = $connection->subType;
            $args->{username} = $args->{stripped_user_name} = $args->{user_name} = $pid;
            $accept = $TRUE;
        }
        return ($accept, $connection, $args->{connection_type}, $args->{connection_sub_type}, $args);
    }
    else {
        return ($TRUE, $connection, $args->{connection_type}, $args->{connection_sub_type}, $args);
    }
}

sub _machine_auth_detection {
    my ($self, $user_name, $node_obj, $options) = @_;
    my $logger = get_logger;
    if ( defined($user_name) && $user_name =~ /^host\// ) {
        $logger->info("is doing machine auth with account '$user_name'.");
        $$node_obj->machine_account($user_name);
        $$options->{'machine_account'} = $user_name;
    }
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set tabstop=4:
# vim: set backspace=indent,eol,start:
