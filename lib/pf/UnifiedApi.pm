package pf::UnifiedApi;

=head1 NAME

pf::UnifiedApi - The base of the mojo app

=cut

=head1 DESCRIPTION

pf::UnifiedApi

=cut

use strict;
use warnings;
use JSON::MaybeXS qw();
{
   package JSON::PP::Boolean;
   sub clone {
       my $o = ${$_[0]};
       return bless (\$o, 'JSON::PP::Boolean');
   }
}

use Mojo::Base 'Mojolicious';
use pf::dal;
use pf::util qw(add_jitter);
use pf::file_paths qw($log_conf_dir);
use pf::SwitchFactory;
pf::SwitchFactory->preloadAllModules();
use MojoX::Log::Log4perl;
use pf::UnifiedApi::Controller;
use pf::I18N::pfappserver;
our $MAX_REQUEST_HANDLED = 2000;
our $REQUEST_HANDLED_JITTER = 500;

has commands => sub {
  my $commands = Mojolicious::Commands->new(app => shift);
  Scalar::Util::weaken $commands->{app};
  unshift @{$commands->namespaces}, 'pf::UnifiedApi::Command';
  return $commands;
};

has log => sub {
    return MojoX::Log::Log4perl->new("$log_conf_dir/pfperl-api.conf",5 * 60);
};

=head2 startup

Setting up routes

=cut

sub startup {
    my ($self) = @_;
    $self->controller_class('pf::UnifiedApi::Controller');
    $self->routes->namespaces(['pf::UnifiedApi::Controller', 'pf::UnifiedApi']);
    $self->hook(before_dispatch => \&before_dispatch_cb);
    $self->hook(after_dispatch => \&after_dispatch_cb);
    $self->hook(before_render => \&before_render_cb);
    $self->plugin('pf::UnifiedApi::Plugin::RestCrud');
#   $self->plugin('NYTProf' => {
#       nytprof => {
#           profiles_dir => "/usr/local/pf/var/nytprof",
#       },
#   });
    my $routes = $self->routes;
    $self->setup_api_v1_routes($routes->any("/api/v1")->name("api.v1"));
    $self->custom_startup_hook();
    $routes->any( '/*', sub {
        my ($c) = @_;
        return $c->unknown_action;
    });

    return;
}

=head2 before_render_cb

before_render_cb

=cut

sub before_render_cb {
    my ($self, $args) = @_;

    my $template = $args->{template} || '';
    if ($template =~ /^exception/) {
        $args->{json} = {message => $args->{exception} || 'Unknown error, check server side logs for details.'};
    }

    my $json = $args->{json};
    return unless $json;
    $json->{status} //= ($args->{status} // 200);
}

=head2 after_dispatch_cb

after_dispatch_cb

=cut

sub after_dispatch_cb {
    my ($c) = @_;
    $c->audit_request if $c->can("audit_request");
    my $app = $c->app;
    my $max = $app->{max_requests_handled} //= add_jitter( $MAX_REQUEST_HANDLED, $REQUEST_HANDLED_JITTER );
    if (++$app->{requests_handled} >= $max) {
        kill 'QUIT', $$;
    }
    return;
}

=head2 before_dispatch_cb

before_dispatch_cb

=cut

sub before_dispatch_cb {
    my ($c) = @_;
    # To allow dispatching with encoded slashes
    my $req = $c->req;
    my $headers = $req->headers;
    $req->default_charset('UTF-8');
    $c->stash(
        {
            path        => $req->url->path,
            admin_roles => [
                split(
                    /\s*,\s*/,
                    $headers->header('X-PacketFence-Admin-Roles') // ''
                )
            ],
            languages => pf::I18N::pfappserver->languages_from_http_header(
                $headers->header('Accept-Language')
            ),
            current_user => $headers->header('X-PacketFence-Username')
        }
    );
    set_tenant_id($c)
}

sub setup_api_v1_routes {
    my ($self, $api_v1_route) = @_;
    $self->setup_api_v1_crud_routes($api_v1_route);
    $self->setup_api_v1_config_routes($api_v1_route->any("/config")->name("api.v1.Config"));
    $self->setup_api_v1_fingerbank_routes($api_v1_route->any("/fingerbank")->to(controller => 'Fingerbank')->name("api.v1.Fingerbank"));
    $self->setup_api_v1_reports_routes($api_v1_route->any("/reports")->name("api.v1.Reports"));
    $self->setup_api_v1_dynamic_reports_routes($api_v1_route);
    $self->setup_api_v1_current_user_routes($api_v1_route);
    $self->setup_api_v1_services_routes($api_v1_route);
    $self->setup_api_v1_cluster_routes($api_v1_route);
    $self->setup_api_v1_authentication_routes($api_v1_route);
    $self->setup_api_v1_queues_routes($api_v1_route);
    $self->setup_api_v1_translations_routes($api_v1_route);
    $self->setup_api_v1_preferences_routes($api_v1_route);
    $self->setup_api_v1_system_summary_route($api_v1_route);
    $self->setup_api_v1_emails_route($api_v1_route);
    $api_v1_route->post(
        "/radius_attributes" => sub {
            $_[0]->render(
                json => {

                    items => [
                        map { { name => $_ } } (
                            "Client-Id",
                            "Client-Port-Id",
                            "User-Service-Type",
                            "Framed-Address",
                            "Framed-Netmask",
                            "Framed-Filter-Id",
                            "Login-Host",
                            "Login-Port",
                            "Old-Password",
                            "Port-Message",
                            "Dialback-No",
                            "Dialback-Name",
                            "Challenge-State",
                            "Login-Callback-Number",
                            "Framed-Callback-Id",
                            "Client-Port-DNIS",
                            "Caller-ID",
                            "Multi-Link-Flag",
                            "Char-Noecho",
                            "X-Ascend-FCP-Parameter",
                            "X-Ascend-Modem-PortNo",
                            "X-Ascend-Modem-SlotNo",
                            "X-Ascend-Modem-ShelfNo",
                            "X-Ascend-Call-Attempt-Limit",
                            "X-Ascend-Call-Block-Duration",
                            "X-Ascend-Maximum-Call-Duration",
                            "X-Ascend-Temporary-Rtes",
                            "X-Ascend-Tunneling-Protocol",
                            "X-Ascend-Shared-Profile-Enable",
                            "X-Ascend-Primary-Home-Agent",
                            "X-Ascend-Secondary-Home-Agent",
                            "X-Ascend-Dialout-Allowed",
                            "X-Ascend-Client-Gateway",
                            "X-Ascend-BACP-Enable",
                            "X-Ascend-DHCP-Maximum-Leases",
                            "X-Ascend-Client-Primary-DNS",
                            "X-Ascend-Client-Secondary-DNS",
                            "X-Ascend-Client-Assign-DNS",
                            "X-Ascend-User-Acct-Type",
                            "X-Ascend-User-Acct-Host",
                            "X-Ascend-User-Acct-Port",
                            "X-Ascend-User-Acct-Key",
                            "X-Ascend-User-Acct-Base",
                            "X-Ascend-User-Acct-Time",
                            "X-Ascend-Assign-IP-Client",
                            "X-Ascend-Assign-IP-Server",
                            "X-Ascend-Assign-IP-Global-Pool",
                            "X-Ascend-DHCP-Reply",
                            "X-Ascend-DHCP-Pool-Number",
                            "X-Ascend-Expect-Callback",
                            "X-Ascend-Event-Type",
                            "X-Ascend-Session-Svr-Key",
                            "X-Ascend-Multicast-Rate-Limit",
                            "X-Ascend-IF-Netmask",
                            "X-Ascend-Remote-Addr",
                            "X-Ascend-Multicast-Client",
                            "X-Ascend-FR-Circuit-Name",
                            "X-Ascend-FR-LinkUp",
                            "X-Ascend-FR-Nailed-Grp",
                            "X-Ascend-FR-Type",
                            "X-Ascend-FR-Link-Mgt",
                            "X-Ascend-FR-N391",
                            "X-Ascend-FR-DCE-N392",
                            "X-Ascend-FR-DTE-N392",
                            "X-Ascend-FR-DCE-N393",
                            "X-Ascend-FR-DTE-N393",
                            "X-Ascend-FR-T391",
                            "X-Ascend-FR-T392",
                            "X-Ascend-Bridge-Address",
                            "X-Ascend-TS-Idle-Limit",
                            "X-Ascend-TS-Idle-Mode",
                            "X-Ascend-DBA-Monitor",
                            "X-Ascend-Base-Channel-Count",
                            "X-Ascend-Minimum-Channels",
                            "X-Ascend-IPX-Route",
                            "X-Ascend-FT1-Caller",
                            "X-Ascend-Backup",
                            "X-Ascend-Call-Type",
                            "X-Ascend-Group",
                            "X-Ascend-FR-DLCI",
                            "X-Ascend-FR-Profile-Name",
                            "X-Ascend-Ara-PW",
                            "X-Ascend-IPX-Node-Addr",
                            "X-Ascend-Home-Agent-IP-Addr",
                            "X-Ascend-Home-Agent-Password",
                            "X-Ascend-Home-Network-Name",
                            "X-Ascend-Home-Agent-UDP-Port",
                            "X-Ascend-Multilink-ID",
                            "X-Ascend-Num-In-Multilink",
                            "X-Ascend-First-Dest",
                            "X-Ascend-Pre-Input-Octets",
                            "X-Ascend-Pre-Output-Octets",
                            "X-Ascend-Pre-Input-Packets",
                            "X-Ascend-Pre-Output-Packets",
                            "X-Ascend-Maximum-Time",
                            "X-Ascend-Disconnect-Cause",
                            "X-Ascend-Connect-Progress",
                            "X-Ascend-Data-Rate",
                            "X-Ascend-PreSession-Time",
                            "X-Ascend-Token-Idle",
                            "X-Ascend-Token-Immediate",
                            "X-Ascend-Require-Auth",
                            "X-Ascend-Number-Sessions",
                            "X-Ascend-Authen-Alias",
                            "X-Ascend-Token-Expiry",
                            "X-Ascend-Menu-Selector",
                            "X-Ascend-Menu-Item",
                            "X-Ascend-PW-Warntime",
                            "X-Ascend-PW-Lifetime",
                            "X-Ascend-IP-Direct",
                            "X-Ascend-PPP-VJ-Slot-Comp",
                            "X-Ascend-PPP-VJ-1172",
                            "X-Ascend-PPP-Async-Map",
                            "X-Ascend-Third-Prompt",
                            "X-Ascend-Send-Secret",
                            "X-Ascend-Receive-Secret",
                            "X-Ascend-IPX-Peer-Mode",
                            "X-Ascend-IP-Pool-Definition",
                            "X-Ascend-Assign-IP-Pool",
                            "X-Ascend-FR-Direct",
                            "X-Ascend-FR-Direct-Profile",
                            "X-Ascend-FR-Direct-DLCI",
                            "X-Ascend-Handle-IPX",
                            "X-Ascend-Netware-timeout",
                            "X-Ascend-IPX-Alias",
                            "X-Ascend-Metric",
                            "X-Ascend-PRI-Number-Type",
                            "X-Ascend-Dial-Number",
                            "X-Ascend-Route-IP",
                            "X-Ascend-Route-IPX",
                            "X-Ascend-Bridge",
                            "X-Ascend-Send-Auth",
                            "X-Ascend-Send-Passwd",
                            "X-Ascend-Link-Compression",
                            "X-Ascend-Target-Util",
                            "X-Ascend-Maximum-Channels",
                            "X-Ascend-Inc-Channel-Count",
                            "X-Ascend-Dec-Channel-Count",
                            "X-Ascend-Seconds-Of-History",
                            "X-Ascend-History-Weigh-Type",
                            "X-Ascend-Add-Seconds",
                            "X-Ascend-Remove-Seconds",
                            "X-Ascend-Data-Filter",
                            "X-Ascend-Call-Filter",
                            "X-Ascend-Idle-Limit",
                            "X-Ascend-Preempt-Limit",
                            "X-Ascend-Callback",
                            "X-Ascend-Data-Svc",
                            "X-Ascend-Force-56",
                            "X-Ascend-Billing-Number",
                            "X-Ascend-Call-By-Call",
                            "X-Ascend-Transit-Number",
                            "X-Ascend-Host-Info",
                            "X-Ascend-PPP-Address",
                            "X-Ascend-MPP-Idle-Percent",
                            "X-Ascend-Xmit-Rate",
                            "User-Name",
                            "User-Password",
                            "CHAP-Password",
                            "NAS-IP-Address",
                            "NAS-Port",
                            "Service-Type",
                            "Framed-Protocol",
                            "Framed-IP-Address",
                            "Framed-IP-Netmask",
                            "Framed-Routing",
                            "Filter-Id",
                            "Framed-MTU",
                            "Framed-Compression",
                            "Login-IP-Host",
                            "Login-Service",
                            "Login-TCP-Port",
                            "Reply-Message",
                            "Callback-Number",
                            "Callback-Id",
                            "Framed-Route",
                            "Framed-IPX-Network",
                            "State",
                            "Class",
                            "Vendor-Specific",
                            "Session-Timeout",
                            "Idle-Timeout",
                            "Termination-Action",
                            "Called-Station-Id",
                            "Calling-Station-Id",
                            "NAS-Identifier",
                            "Proxy-State",
                            "Login-LAT-Service",
                            "Login-LAT-Node",
                            "Login-LAT-Group",
                            "Framed-AppleTalk-Link",
                            "Framed-AppleTalk-Network",
                            "Framed-AppleTalk-Zone",
                            "CHAP-Challenge",
                            "NAS-Port-Type",
                            "Port-Limit",
                            "Login-LAT-Port",
                            "Acct-Status-Type",
                            "Acct-Delay-Time",
                            "Acct-Input-Octets",
                            "Acct-Output-Octets",
                            "Acct-Session-Id",
                            "Acct-Authentic",
                            "Acct-Session-Time",
                            "Acct-Input-Packets",
                            "Acct-Output-Packets",
                            "Acct-Terminate-Cause",
                            "Acct-Multi-Session-Id",
                            "Acct-Link-Count",
                            "Acct-Tunnel-Connection",
                            "Acct-Tunnel-Packets-Lost",
                            "Tunnel-Type",
                            "Tunnel-Medium-Type",
                            "Tunnel-Client-Endpoint",
                            "Tunnel-Server-Endpoint",
                            "Tunnel-Password",
                            "Tunnel-Private-Group-Id",
                            "Tunnel-Assignment-Id",
                            "Tunnel-Preference",
                            "Tunnel-Client-Auth-Id",
                            "Tunnel-Server-Auth-Id",
                            "Acct-Input-Gigawords",
                            "Acct-Output-Gigawords",
                            "Event-Timestamp",
                            "ARAP-Password",
                            "ARAP-Features",
                            "ARAP-Zone-Access",
                            "ARAP-Security",
                            "ARAP-Security-Data",
                            "Password-Retry",
                            "Prompt",
                            "Connect-Info",
                            "Configuration-Token",
                            "EAP-Message",
                            "Message-Authenticator",
                            "ARAP-Challenge-Response",
                            "Acct-Interim-Interval",
                            "NAS-Port-Id",
                            "Framed-Pool",
                            "NAS-IPv6-Address",
                            "Framed-Interface-Id",
                            "Framed-IPv6-Prefix",
                            "Login-IPv6-Host",
                            "Framed-IPv6-Route",
                            "Framed-IPv6-Pool",
                            "Error-Cause",
                            "EAP-Key-Name",
                            "Chargeable-User-Identity",
                            "Egress-VLANID",
                            "Ingress-Filters",
                            "Egress-VLAN-Name",
                            "User-Priority-Table",
                            "Delegated-IPv6-Prefix",
                            "NAS-Filter-Rule",
                            "MIP6-Feature-Vector",
                            "MIP6-Home-Link-Prefix",
                            "Operator-Name",
                            "Location-Information",
                            "Location-Data",
                            "Basic-Location-Policy-Rules",
                            "Extended-Location-Policy-Rules",
                            "Location-Capable",
                            "Requested-Location-Info",
                            "Framed-Management",
                            "Management-Transport-Protection",
                            "Management-Policy-Id",
                            "Management-Privilege-Level",
                            "PKM-SS-Cert",
                            "PKM-CA-Cert",
                            "PKM-Config-Settings",
                            "PKM-Cryptosuite-List",
                            "PKM-SAID",
                            "PKM-SA-Descriptor",
                            "PKM-Auth-Key",
                            "DS-Lite-Tunnel-Name",
                            "Mobile-Node-Identifier",
                            "Service-Selection",
                            "PMIP6-Home-LMA-IPv6-Address",
                            "PMIP6-Visited-LMA-IPv6-Address",
                            "PMIP6-Home-LMA-IPv4-Address",
                            "PMIP6-Visited-LMA-IPv4-Address",
                            "PMIP6-Home-HN-Prefix",
                            "PMIP6-Visited-HN-Prefix",
                            "PMIP6-Home-Interface-ID",
                            "PMIP6-Visited-Interface-ID",
                            "PMIP6-Home-IPv4-HoA",
                            "PMIP6-Visited-IPv4-HoA",
                            "PMIP6-Home-DHCP4-Server-Address",
                            "PMIP6-Visited-DHCP4-Server-Address",
                            "PMIP6-Home-DHCP6-Server-Address",
                            "PMIP6-Visited-DHCP6-Server-Address",
                            "PMIP6-Home-IPv4-Gateway",
                            "PMIP6-Visited-IPv4-Gateway",
                            "EAP-Lower-Layer",
                            "Framed-IPv6-Address",
                            "DNS-Server-IPv6-Address",
                            "Route-IPv6-Information",
                            "Delegated-IPv6-Prefix-Pool",
                            "Stateful-IPv6-Address-Pool",
                            "IPv6-6rd-Configuration",
                            "IPv6-6rd-IPv4MaskLen",
                            "IPv6-6rd-Prefix",
                            "IPv6-6rd-BR-IPv4-Address",
                            "GSS-Acceptor-Service-Name",
                            "GSS-Acceptor-Host-Name",
                            "GSS-Acceptor-Service-Specifics",
                            "GSS-Acceptor-Realm-Name",
                            "Originating-Line-Info",
                            "Allowed-Called-Station-Id",
                            "EAP-Peer-Id",
                            "EAP-Server-Id",
                            "Mobility-Domain-Id",
                            "Preauth-Timeout",
                            "Network-Id-Name",
                            "EAPoL-Announcement",
                            "WLAN-HESSID",
                            "WLAN-Venue-Info",
                            "WLAN-Venue-Language",
                            "WLAN-Venue-Name",
                            "WLAN-Reason-Code",
                            "WLAN-Pairwise-Cipher",
                            "WLAN-Group-Cipher",
                            "WLAN-AKM-Suite",
                            "WLAN-Group-Mgmt-Cipher",
                            "WLAN-RF-Band",
                            "Frag-Status",
                            "Proxy-State-Length",
                            "Response-Length",
                            "Original-Packet-Code",
                            "Digest-Response",
                            "Digest-Attributes",
                            "Fall-Through",
                            "Relax-Filter",
                            "Exec-Program",
                            "Exec-Program-Wait",
                            "Auth-Type",
                            "Menu",
                            "Termination-Menu",
                            "Prefix",
                            "Suffix",
                            "Group",
                            "Crypt-Password",
                            "Add-Prefix",
                            "Add-Suffix",
                            "Expiration",
                            "Autz-Type",
                            "Acct-Type",
                            "Session-Type",
                            "Post-Auth-Type",
                            "Pre-Proxy-Type",
                            "Post-Proxy-Type",
                            "Pre-Acct-Type",
                            "EAP-Type",
                            "EAP-TLS-Require-Client-Cert",
                            "EAP-Id",
                            "EAP-Code",
                            "EAP-MD5-Password",
                            "PEAP-Version",
                            "Load-Balance-Key",
                            "Raw-Attribute",
                            "TNC-VLAN-Access",
                            "TNC-VLAN-Isolate",
                            "User-Category",
                            "Group-Name",
                            "Huntgroup-Name",
                            "Simultaneous-Use",
                            "Strip-User-Name",
                            "Hint",
                            "Pam-Auth",
                            "Login-Time",
                            "Stripped-User-Name",
                            "Current-Time",
                            "Realm",
                            "No-Such-Attribute",
                            "Proxy-To-Realm",
                            "Replicate-To-Realm",
                            "Acct-Session-Start-Time",
                            "Acct-Unique-Session-Id",
                            "LDAP-UserDN",
                            "NS-MTA-MD5-Password",
                            "SQL-User-Name",
                            "LM-Password",
                            "NT-Password",
                            "SMB-Account-CTRL",
                            "SMB-Account-CTRL-TEXT",
                            "User-Profile",
                            "Digest-Realm",
                            "Digest-Nonce",
                            "Digest-Method",
                            "Digest-URI",
                            "Digest-QOP",
                            "Digest-Algorithm",
                            "Digest-Body-Digest",
                            "Digest-CNonce",
                            "Digest-Nonce-Count",
                            "Digest-User-Name",
                            "Pool-Name",
                            "Module-Success-Message",
                            "Module-Failure-Message",
                            "Rewrite-Rule",
                            "Digest-HA1",
                            "MS-CHAP-Use-NTLM-Auth",
                            "NTLM-User-Name",
                            "MS-CHAP-User-Name",
                            "Time-Of-Day",
                            "SHA2-Password",
                            "SHA-Password",
                            "SSHA-Password",
                            "SHA1-Password",
                            "SSHA1-Password",
                            "MD5-Password",
                            "SMD5-Password",
                            "Cleartext-Password",
                            "Password-With-Header",
                            "Inner-Tunnel-User-Name",
                            "EAP-IKEv2-IDType",
                            "EAP-IKEv2-ID",
                            "EAP-IKEv2-Secret",
                            "EAP-IKEv2-AuthType",
                            "Send-Disconnect-Request",
                            "Send-CoA-Request",
                            "Packet-Original-Timestamp",
                            "SQL-Table-Name",
                            "Home-Server-Pool",
                            "Attribute-Map",
                            "FreeRADIUS-Client-IP-Address",
                            "FreeRADIUS-Client-IPv6-Address",
                            "FreeRADIUS-Client-Require-MA",
                            "FreeRADIUS-Client-Secret",
                            "FreeRADIUS-Client-Shortname",
                            "FreeRADIUS-Client-NAS-Type",
                            "FreeRADIUS-Client-Virtual-Server",
                            "Allow-Session-Resumption",
                            "EAP-Session-Resumed",
                            "EAP-MSK",
                            "EAP-EMSK",
                            "Recv-CoA-Type",
                            "Send-CoA-Type",
                            "MS-CHAP-Password",
                            "Packet-Transmit-Counter",
                            "Cached-Session-Policy",
                            "MS-CHAP-New-Cleartext-Password",
                            "MS-CHAP-New-NT-Password",
                            "Stripped-User-Domain",
                            "Called-Station-SSID",
                            "OTP-Challenge",
                            "EAP-Session-Id",
                            "Chbind-Response-Code",
                            "Acct-Input-Octets64",
                            "Acct-Output-Octets64",
                            "FreeRADIUS-Client-IP-Prefix",
                            "FreeRADIUS-Client-IPv6-Prefix",
                            "FreeRADIUS-Response-Delay",
                            "FreeRADIUS-Client-Src-IP-Address",
                            "FreeRADIUS-Client-Src-IPv6-Address",
                            "FreeRADIUS-Response-Delay-USec",
                            "REST-HTTP-Header",
                            "REST-HTTP-Body",
                            "Cache-Expires",
                            "Cache-Created",
                            "Cache-TTL",
                            "Cache-Status-Only",
                            "Cache-Merge",
                            "Cache-Entry-Hits",
                            "Cache-Read-Only",
                            "SSHA2-224-Password",
                            "SSHA2-256-Password",
                            "SSHA2-384-Password",
                            "SSHA2-512-Password",
                            "MS-CHAP-Peer-Challenge",
                            "EAP-Sim-Subtype",
                            "EAP-Sim-Rand1",
                            "EAP-Sim-Rand2",
                            "EAP-Sim-Rand3",
                            "EAP-Sim-SRES1",
                            "EAP-Sim-SRES2",
                            "EAP-Sim-SRES3",
                            "EAP-Sim-State",
                            "EAP-Sim-IMSI",
                            "EAP-Sim-HMAC",
                            "EAP-Sim-KEY",
                            "EAP-Sim-EXTRA",
                            "EAP-Sim-KC1",
                            "EAP-Sim-KC2",
                            "EAP-Sim-KC3",
                            "EAP-Sim-Ki",
                            "EAP-Sim-Algo-Version",
                            "Outer-Realm-Name",
                            "Inner-Realm-Name",
                            "EAP-Type-Base",
                            "EAP-Type-VALUE",
                            "EAP-Type-None",
                            "EAP-Type-Identity",
                            "EAP-Type-Notification",
                            "EAP-Type-NAK",
                            "EAP-Type-MD5-Challenge",
                            "EAP-Type-One-Time-Password",
                            "EAP-Type-Generic-Token-Card",
                            "EAP-Type-RSA-Public-Key",
                            "EAP-Type-DSS-Unilateral",
                            "EAP-Type-KEA",
                            "EAP-Type-KEA-Validate",
                            "EAP-Type-EAP-TLS",
                            "EAP-Type-Defender-Token",
                            "EAP-Type-RSA-SecurID-EAP",
                            "EAP-Type-Arcot-Systems-EAP",
                            "EAP-Type-Cisco-LEAP",
                            "EAP-Type-Nokia-IP-Smart-Card",
                            "EAP-Type-SIM",
                            "EAP-Type-SRP-SHA1",
                            "EAP-Type-EAP-TTLS",
                            "EAP-Type-Remote-Access-Service",
                            "EAP-Type-AKA",
                            "EAP-Type-EAP-3Com-Wireless",
                            "EAP-Type-PEAP",
                            "EAP-Type-MS-EAP-Authentication",
                            "EAP-Type-MAKE",
                            "EAP-Type-CRYPTOCard",
                            "EAP-Type-EAP-MSCHAP-V2",
                            "EAP-Type-DynamID",
                            "EAP-Type-Rob-EAP",
                            "EAP-Type-SecurID-EAP",
                            "EAP-Type-MS-Authentication-TLV",
                            "EAP-Type-SentriNET",
                            "EAP-Type-EAP-Actiontec-Wireless",
                            "EAP-Type-Cogent-Biomentric-EAP",
                            "EAP-Type-AirFortress-EAP",
                            "EAP-Type-EAP-HTTP-Digest",
                            "EAP-Type-SecuriSuite-EAP",
                            "EAP-Type-DeviceConnect-EAP",
                            "EAP-Type-EAP-SPEKE",
                            "EAP-Type-EAP-MOBAC",
                            "EAP-Type-EAP-FAST",
                            "EAP-Type-Zonelabs",
                            "EAP-Type-EAP-Link",
                            "EAP-Type-EAP-PAX",
                            "EAP-Type-EAP-PSK",
                            "EAP-Type-EAP-SAKE",
                            "EAP-Type-EAP-IKEv2",
                            "EAP-Type-EAP-AKA2",
                            "EAP-Type-EAP-GPSK",
                            "EAP-Type-EAP-PWD",
                            "EAP-Type-EAP-EVEv1",
                            "EAP-Type-Microsoft-MS-CHAPv2",
                            "EAP-Type-Cisco-MS-CHAPv2",
                            "EAP-Type-MS-CHAP-V2",
                            "EAP_Sim-Base",
                            "EAP-Sim-RAND",
                            "EAP-Sim-PADDING",
                            "EAP-Sim-NONCE_MT",
                            "EAP-Sim-PERMANENT_ID_REQ",
                            "EAP-Sim-MAC",
                            "EAP-Sim-NOTIFICATION",
                            "EAP-Sim-ANY_ID_REQ",
                            "EAP-Sim-IDENTITY",
                            "EAP-Sim-VERSION_LIST",
                            "EAP-Sim-SELECTED_VERSION",
                            "EAP-Sim-FULLAUTH_ID_REQ",
                            "EAP-Sim-COUNTER",
                            "EAP-Sim-COUNTER_TOO_SMALL",
                            "EAP-Sim-NONCE_S",
                            "EAP-Sim-IV",
                            "EAP-Sim-ENCR_DATA",
                            "EAP-Sim-NEXT_PSEUDONUM",
                            "EAP-Sim-NEXT_REAUTH_ID",
                            "EAP-Sim-CHECKCODE",
                            "Tmp-String-0",
                            "Tmp-String-1",
                            "Tmp-String-2",
                            "Tmp-String-3",
                            "Tmp-String-4",
                            "Tmp-String-5",
                            "Tmp-String-6",
                            "Tmp-String-7",
                            "Tmp-String-8",
                            "Tmp-String-9",
                            "Tmp-Integer-0",
                            "Tmp-Integer-1",
                            "Tmp-Integer-2",
                            "Tmp-Integer-3",
                            "Tmp-Integer-4",
                            "Tmp-Integer-5",
                            "Tmp-Integer-6",
                            "Tmp-Integer-7",
                            "Tmp-Integer-8",
                            "Tmp-Integer-9",
                            "Tmp-IP-Address-0",
                            "Tmp-IP-Address-1",
                            "Tmp-IP-Address-2",
                            "Tmp-IP-Address-3",
                            "Tmp-IP-Address-4",
                            "Tmp-IP-Address-5",
                            "Tmp-IP-Address-6",
                            "Tmp-IP-Address-7",
                            "Tmp-IP-Address-8",
                            "Tmp-IP-Address-9",
                            "Tmp-Octets-0",
                            "Tmp-Octets-1",
                            "Tmp-Octets-2",
                            "Tmp-Octets-3",
                            "Tmp-Octets-4",
                            "Tmp-Octets-5",
                            "Tmp-Octets-6",
                            "Tmp-Octets-7",
                            "Tmp-Octets-8",
                            "Tmp-Octets-9",
                            "Tmp-Date-0",
                            "Tmp-Date-1",
                            "Tmp-Date-2",
                            "Tmp-Date-3",
                            "Tmp-Date-4",
                            "Tmp-Date-5",
                            "Tmp-Date-6",
                            "Tmp-Date-7",
                            "Tmp-Date-8",
                            "Tmp-Date-9",
                            "Tmp-Integer64-0",
                            "Tmp-Integer64-1",
                            "Tmp-Integer64-2",
                            "Tmp-Integer64-3",
                            "Tmp-Integer64-4",
                            "Tmp-Integer64-5",
                            "Tmp-Integer64-6",
                            "Tmp-Integer64-7",
                            "Tmp-Integer64-8",
                            "Tmp-Integer64-9",
                            "Tmp-Cast-String",
                            "Tmp-Cast-Integer",
                            "Tmp-Cast-Ipaddr",
                            "Tmp-Cast-Date",
                            "Tmp-Cast-Abinary",
                            "Tmp-Cast-Octets",
                            "Tmp-Cast-Ifid",
                            "Tmp-Cast-IPv6Addr",
                            "Tmp-Cast-IPv6Prefix",
                            "Tmp-Cast-Byte",
                            "Tmp-Cast-Short",
                            "Tmp-Cast-Ethernet",
                            "Tmp-Cast-Signed",
                            "Tmp-Cast-Integer64",
                            "Tmp-Cast-IPv4Prefix",
                            "WiMAX-MN-NAI",
                            "TLS-Cert-Serial",
                            "TLS-Cert-Expiration",
                            "TLS-Cert-Issuer",
                            "TLS-Cert-Subject",
                            "TLS-Cert-Common-Name",
                            "TLS-Cert-Subject-Alt-Name-Email",
                            "TLS-Cert-Subject-Alt-Name-Dns",
                            "TLS-Cert-Subject-Alt-Name-Upn",
                            "TLS-Client-Cert-Serial",
                            "TLS-Client-Cert-Expiration",
                            "TLS-Client-Cert-Issuer",
                            "TLS-Client-Cert-Subject",
                            "TLS-Client-Cert-Common-Name",
                            "TLS-Client-Cert-Filename",
                            "TLS-Client-Cert-Subject-Alt-Name-Email",
                            "TLS-Client-Cert-X509v3-Extended-Key-Usage",
                            "TLS-Client-Cert-X509v3-Subject-Key-Identifier",
                            "TLS-Client-Cert-X509v3-Authority-Key-Identifier",
                            "TLS-Client-Cert-X509v3-Basic-Constraints",
                            "TLS-Client-Cert-Subject-Alt-Name-Dns",
                            "TLS-Client-Cert-Subject-Alt-Name-Upn",
                            "TLS-PSK-Identity",
                            "TLS-Client-Cert-X509v3-Extended-Key-Usage-OID",
                            "TLS-OCSP-Cert-Valid",
                            "TLS-Cache-Filename",
                            "TLS-Session-Version",
                            "TLS-Session-Cipher-Suite",
                            "SoH-MS-Machine-OS-vendor",
                            "SoH-MS-Machine-OS-version",
                            "SoH-MS-Machine-OS-release",
                            "SoH-MS-Machine-OS-build",
                            "SoH-MS-Machine-SP-version",
                            "SoH-MS-Machine-SP-release",
                            "SoH-MS-Machine-Processor",
                            "SoH-MS-Machine-Name",
                            "SoH-MS-Correlation-Id",
                            "SoH-MS-Machine-Role",
                            "SoH-Supported",
                            "SoH-MS-Windows-Health-Status",
                            "SoH-MS-Health-Other",
                            "Radclient-Test-Name",
                            "ADSL-Forum-DHCP-Vendor-Specific",
                            "ADSL-Forum-Device-Manufacturer-OUI",
                            "ADSL-Forum-Device-Serial-Number",
                            "ADSL-Forum-Device-Product-Class",
                            "ADSL-Forum-Gateway-Manufacturer-OUI",
                            "ADSL-Agent-Circuit-Id",
                            "ADSL-Agent-Remote-Id",
                            "Actual-Data-Rate-Upstream",
                            "Actual-Data-Rate-Downstream",
                            "Minimum-Data-Rate-Upstream",
                            "Minimum-Data-Rate-Downstream",
                            "Attainable-Data-Rate-Upstream",
                            "Attainable-Data-Rate-Downstream",
                            "Maximum-Data-Rate-Upstream",
                            "Maximum-Data-Rate-Downstream",
                            "Minimum-Data-Rate-Upstream-Low-Power",
                            "Minimum-Data-Rate-Downstream-Low-Power",
                            "Maximum-Interleaving-Delay-Upstream",
                            "Actual-Interleaving-Delay-Upstream",
                            "Maximum-Interleaving-Delay-Downstream",
                            "Actual-Interleaving-Delay-Downstream",
                            "Access-Loop-Encapsulation",
                            "IWF-Session",
                            "3Com-User-Access-Level",
                            "3Com-VLAN-Name",
                            "3Com-Mobility-Profile",
                            "3Com-Encryption-Type",
                            "3Com-Time-Of-Day",
                            "3Com-SSID",
                            "3Com-End-Date",
                            "3Com-URL",
                            "3Com-Connect_Id",
                            "3Com-NAS-Startup-Timestamp",
                            "3Com-Ip-Host-Addr",
                            "3Com-Product-ID",
                            "3GPP-IMSI",
                            "3GPP-Charging-ID",
                            "3GPP-PDP-Type",
                            "3GPP-Charging-Gateway-Address",
                            "3GPP-GPRS-Negotiated-QoS-profile",
                            "3GPP-SGSN-Address",
                            "3GPP-GGSN-Address",
                            "3GPP-IMSI-MCC-MNC",
                            "3GPP-GGSN-MCC-MNC",
                            "3GPP-NSAPI",
                            "3GPP-Session-Stop-Indicator",
                            "3GPP-Selection-Mode",
                            "3GPP-Charging-Characteristics",
                            "3GPP-Charging-Gateway-IPv6-Address",
                            "3GPP-SGSN-IPv6-Address",
                            "3GPP-GGSN-IPv6-Address",
                            "3GPP-IPv6-DNS-Servers",
                            "3GPP-SGSN-MCC-MNC",
                            "3GPP-Teardown-Indicator",
                            "3GPP-IMEISV",
                            "3GPP-RAT-Type",
                            "3GPP-Location-Info",
                            "3GPP-MS-Time-Zone",
                            "3GPP-Camel-Charging-Info",
                            "3GPP-Packet-Filter",
                            "3GPP-Negotiated-DSCP",
                            "3GPP-Allocate-IP-Type",
                            "3GPP2-Ike-Preshared-Secret-Request",
                            "3GPP2-Security-Level",
                            "3GPP2-Pre-Shared-Secret",
                            "3GPP2-Reverse-Tunnel-Spec",
                            "3GPP2-Diffserv-Class-Option",
                            "3GPP2-Accounting-Container",
                            "3GPP2-Home-Agent-IP-Address",
                            "3GPP2-KeyID",
                            "3GPP2-PCF-IP-Address",
                            "3GPP2-BSID",
                            "3GPP2-User-Id",
                            "3GPP2-Forward-FCH-Mux-Option",
                            "3GPP2-Reverse-FCH-Mux-Option",
                            "3GPP2-Service-Option",
                            "3GPP2-Forward-Traffic-Type",
                            "3GPP2-Reverse-Traffic-Type",
                            "3GPP2-FCH-Frame-Size",
                            "3GPP2-Forward-FCH-RC",
                            "3GPP2-Reverse-FCH-RC",
                            "3GPP2-IP-Technology",
                            "3GPP2-Compulsory-Tunnel-Indicator",
                            "3GPP2-Release-Indicator",
                            "3GPP2-Bad-PPP-Frame-Count",
                            "3GPP2-Number-Active-Transitions",
                            "3GPP2-Terminating-SDB-Octet-Count",
                            "3GPP2-Originating-SDB-OCtet-Count",
                            "3GPP2-Terminating-Number-SDBs",
                            "3GPP2-Originating-Number-SDBs",
                            "3GPP2-IP-QoS",
                            "3GPP2-Airlink-Priority",
                            "3GPP2-Airlink-Record-Type",
                            "3GPP2-Airlink-Sequence-Number",
                            "3GPP2-Received-HDLC-Octets",
                            "3GPP2-Correlation-Id",
                            "3GPP2-Module-Orig-Term-Indicator",
                            "3GPP2-Inbound-Mobile-IP-Sig-Octets",
                            "3GPP2-Outbound-Mobile-IP-Sig-Octets",
                            "3GPP2-Session-Continue",
                            "3GPP2-Active-Time",
                            "3GPP2-DCCH-Frame-Size",
                            "3GPP2-Begin-Session",
                            "3GPP2-ESN",
                            "3GPP2-S-Key",
                            "3GPP2-S-Request",
                            "3GPP2-S-Lifetime",
                            "3GPP2-MN-HA-SPI",
                            "3GPP2-MN-HA-Shared-Key",
                            "3GPP2-Remote-IP-Address",
                            "3GPP2-Remote-IPv6-Address",
                            "3GPP2-Remote-Address-Table-Index",
                            "3GPP2-Remote-IPv4-Addr-Octet-Count",
                            "3GPP2-Allowed-Diffserv-Marking",
                            "3GPP2-Service-Option-Profile",
                            "3GPP2-DNS-Update-Required",
                            "3GPP2-Foreign-Agent-Address",
                            "3GPP2-Last-User-Activity-Time",
                            "3GPP2-MN-AAA-Removal-Indication",
                            "3GPP2-RN-Packet-Data-Inactivity-Timer",
                            "3GPP2-Forward-PDCH-RC",
                            "3GPP2-Forward-DCCH-Mux-Option",
                            "3GPP2-Reverse-DCCH-Mux-Option",
                            "3GPP2-Forward-DCCH-RC",
                            "3GPP2-Reverse-DHHC-RC",
                            "3GPP2-Session-Termination-Capability",
                            "3GPP2-Allowed-Persistent-TFTs",
                            "3GPP2-Prepaid-Acct-Quota",
                            "3GPP2-Prepaid-Acct-Quota-QuotaIDentifier",
                            "3GPP2-Prepaid-Acct-Quota-VolumeQuota",
                            "3GPP2-Prepaid-Acct-Quota-VolumeQuotaOverflow",
                            "3GPP2-Prepaid-Acct-Quota-VolumeThreshold",
                            "3GPP2-Prepaid-Acct-Quota-VolumeThresholdOverflow",
                            "3GPP2-Prepaid-Acct-Quota-UpdateReason",
                            "3GPP2-Prepaid-acct-Capability",
                            "3GPP2-MIP-Lifetime",
                            "3GPP2-Acct-Stop-Trigger",
                            "3GPP2-Service-Reference-Id",
                            "3GPP2-DNS-Update-Capability",
                            "3GPP2-Disconnect-Reason",
                            "3GPP2-Remote-IPv6-Octet-Count",
                            "3GPP2-PrePaid-Tariff-Switching",
                            "3GPP2-MEID",
                            "3GPP2-DNS-Server-IP-Address",
                            "3GPP2-Carrier-ID",
                            "3GPP2-GMT-Time-Zone-Offset",
                            "3GPP2-HA-Request",
                            "3GPP2-HA-Authorised",
                            "3GPP2-IP-Ver-Authorised",
                            "3GPP2-MIPv4-Mesg-Id",
                            "Acc-Reason-Code",
                            "Acc-Ccp-Option",
                            "Acc-Input-Errors",
                            "Acc-Output-Errors",
                            "Acc-Access-Partition",
                            "Acc-Customer-Id",
                            "Acc-Ip-Gateway-Pri",
                            "Acc-Ip-Gateway-Sec",
                            "Acc-Route-Policy",
                            "Acc-ML-MLX-Admin-State",
                            "Acc-ML-Call-Threshold",
                            "Acc-ML-Clear-Threshold",
                            "Acc-ML-Damping-Factor",
                            "Acc-Tunnel-Secret",
                            "Acc-Clearing-Cause",
                            "Acc-Clearing-Location",
                            "Acc-Service-Profile",
                            "Acc-Request-Type",
                            "Acc-Bridging-Support",
                            "Acc-Apsm-Oversubscribed",
                            "Acc-Acct-On-Off-Reason",
                            "Acc-Tunnel-Port",
                            "Acc-Dns-Server-Pri",
                            "Acc-Dns-Server-Sec",
                            "Acc-Nbns-Server-Pri",
                            "Acc-Nbns-Server-Sec",
                            "Acc-Dial-Port-Index",
                            "Acc-Ip-Compression",
                            "Acc-Ipx-Compression",
                            "Acc-Connect-Tx-Speed",
                            "Acc-Connect-Rx-Speed",
                            "Acc-Modem-Modulation-Type",
                            "Acc-Modem-Error-Protocol",
                            "Acc-Callback-Delay",
                            "Acc-Callback-Num-Valid",
                            "Acc-Callback-Mode",
                            "Acc-Callback-CBCP-Type",
                            "Acc-Dialout-Auth-Mode",
                            "Acc-Dialout-Auth-Password",
                            "Acc-Dialout-Auth-Username",
                            "Acc-Access-Community",
                            "Acc-Vpsm-Reject-Cause",
                            "Acc-Ace-Token",
                            "Acc-Ace-Token-Ttl",
                            "Acc-Ip-Pool-Name",
                            "Acc-Igmp-Admin-State",
                            "Acc-Igmp-Version",
                            "Acc-MN-HA-Secret",
                            "Acc-Location-Id",
                            "Acc-Calling-Station-Category",
                            "Acme-FlowID_FS1_F",
                            "Acme-FlowType_FS1_F",
                            "Acme-Session-Ingress-CallId",
                            "Acme-Session-Egress-CallId",
                            "Acme-Flow-In-Realm_FS1_F",
                            "Acme-Flow-In-Src-Addr_FS1_F",
                            "Acme-Flow-In-Src-Port_FS1_F",
                            "Acme-Flow-In-Dst-Addr_FS1_F",
                            "Acme-Flow-In-Dst-Port_FS1_F",
                            "Acme-Flow-Out-Realm_FS1_F",
                            "Acme-Flow-Out-Src-Addr_FS1_F",
                            "Acme-Flow-Out-Src-Port_FS1_F",
                            "Acme-Flow-Out-Dst-Addr_FS1_F",
                            "Acme-Flow-Out-Dst-Port_FS1_F",
                            "Acme-Calling-Octets_FS1",
                            "Acme-Calling-Packets_FS1",
                            "Acme-Calling-RTCP-Packets-Lost_FS1",
                            "Acme-Calling-RTCP-Avg-Jitter_FS1",
                            "Acme-Calling-RTCP-Avg-Latency_FS1",
                            "Acme-Calling-RTCP-MaxJitter_FS1",
                            "Acme-Calling-RTCP-MaxLatency_FS1",
                            "Acme-Calling-RTP-Packets-Lost_FS1",
                            "Acme-Calling-RTP-Avg-Jitter_FS1",
                            "Acme-Calling-RTP-MaxJitter_FS1",
                            "Acme-Session-Generic-Id",
                            "Acme-Session-Ingress-Realm",
                            "Acme-Session-Egress-Realm",
                            "Acme-Session-Protocol-Type",
                            "Acme-Called-Octets_FS1",
                            "Acme-Called-Packets_FS1",
                            "Acme-Called-RTCP-Packets-Lost_FS1",
                            "Acme-Called-RTCP-Avg-Jitter_FS1",
                            "Acme-Called-RTCP-Avg-Latency_FS1",
                            "Acme-Called-RTCP-MaxJitter_FS1",
                            "Acme-Called-RTCP-MaxLatency_FS1",
                            "Acme-Called-RTP-Packets-Lost_FS1",
                            "Acme-Called-RTP-Avg-Jitter_FS1",
                            "Acme-Called-RTP-MaxJitter_FS1",
                            "Acme-Session-Charging-Vector",
                            "Acme-Session-Charging-Function_Address",
                            "Acme-Firmware-Version",
                            "Acme-Local-Time-Zone",
                            "Acme-Post-Dial-Delay",
                            "Acme-CDR-Sequence-Number",
                            "Acme-Session-Disposition",
                            "Acme-Disconnect-Initiator",
                            "Acme-Disconnect-Cause",
                            "Acme-Intermediate_Time",
                            "Acme-Primary-Routing-Number",
                            "Acme-Originating-Trunk-Group",
                            "Acme-Terminating-Trunk-Group",
                            "Acme-Originating-Trunk-Context",
                            "Acme-Terminating-Trunk-Context",
                            "Acme-P-Asserted-ID",
                            "Acme-SIP-Diversion",
                            "Acme-SIP-Status",
                            "Acme-Ingress-Local-Addr",
                            "Acme-Ingress-Remote-Addr",
                            "Acme-Egress-Local-Addr",
                            "Acme-Egress-Remote-Addr",
                            "Acme-FlowID_FS1_R",
                            "Acme-FlowType_FS1_R",
                            "Acme-Flow-In-Realm_FS1_R",
                            "Acme-Flow-In-Src-Addr_FS1_R",
                            "Acme-Flow-In-Src-Port_FS1_R",
                            "Acme-Flow-In-Dst-Addr_FS1_R",
                            "Acme-Flow-In-Dst-Port_FS1_R",
                            "Acme-Flow-Out-Realm_FS1_R",
                            "Acme-Flow-Out-Src-Addr_FS1_R",
                            "Acme-Flow-Out-Src-Port_FS1_R",
                            "Acme-Flow-Out-Dst-Addr_FS1_R",
                            "Acme-Flow-Out-Dst-Port_FS1_R",
                            "Acme-FlowID_FS2_F",
                            "Acme-FlowType_FS2_F",
                            "Acme-Flow-In-Realm_FS2_F",
                            "Acme-Flow-In-Src-Addr_FS2_F",
                            "Acme-Flow-In-Src-Port_FS2_F",
                            "Acme-Flow-In-Dst-Addr_FS2_F",
                            "Acme-Flow-In-Dst-Port_FS2_F",
                            "Acme-Flow-Out-Realm_FS2_F",
                            "Acme-Flow-Out-Src-Addr_FS2_F",
                            "Acme-Flow-Out-Src-Port_FS2_F",
                            "Acme-Flow-Out-Dst-Addr_FS2_F",
                            "Acme-Flow-Out-Dst-Port_FS2_F",
                            "Acme-Calling-Octets_FS2",
                            "Acme-Calling-Packets_FS2",
                            "Acme-Calling-RTCP-Packets-Lost_FS2",
                            "Acme-Calling-RTCP-Avg-Jitter_FS2",
                            "Acme-Calling-RTCP-Avg-Latency_FS2",
                            "Acme-Calling-RTCP-MaxJitter_FS2",
                            "Acme-Calling-RTCP-MaxLatency_FS2",
                            "Acme-Calling-RTP-Packets-Lost_FS2",
                            "Acme-Calling-RTP-Avg-Jitter_FS2",
                            "Acme-Calling-RTP-MaxJitter_FS2",
                            "Acme-FlowID_FS2_R",
                            "Acme-FlowType_FS2_R",
                            "Acme-Flow-In-Realm_FS2_R",
                            "Acme-Flow-In-Src-Addr_FS2_R",
                            "Acme-Flow-In-Src-Port_FS2_R",
                            "Acme-Flow-In-Dst-Addr_FS2_R",
                            "Acme-Flow-In-Dst-Port_FS2_R",
                            "Acme-Flow-Out-Realm_FS2_R",
                            "Acme-Flow-Out-Src-Addr_FS2_R",
                            "Acme-Flow-Out-Src-Port_FS2_R",
                            "Acme-Flow-Out-Dst-Addr_FS2_R",
                            "Acme-Flow-Out-Dst-Port_FS2_R",
                            "Acme-Called-Octets_FS2",
                            "Acme-Called-Packets_FS2",
                            "Acme-Called-RTCP-Packets-Lost_FS2",
                            "Acme-Called-RTCP-Avg-Jitter_FS2",
                            "Acme-Called-RTCP-Avg-Latency_FS2",
                            "Acme-Called-RTCP-MaxJitter_FS2",
                            "Acme-Called-RTCP-MaxLatency_FS2",
                            "Acme-Called-RTP-Packets-Lost_FS2",
                            "Acme-Called-RTP-Avg-Jitter_FS2",
                            "Acme-Called-RTP-MaxJitter_FS2",
                            "Acme-Egress-Final-Routing-Number",
                            "Acme-Session-Ingress-RPH",
                            "Acme-Session-Egress-RPH",
                            "Acme-Ingress-Network-Interface-Id",
                            "Acme-Ingress-Vlan-Tag-Value",
                            "Acme-Egress-Network-Interface-Id",
                            "Acme-Egress-Vlan-Tag-Value",
                            "Acme-Refer-Call-Transfer-Id",
                            "Acme-FlowMediaType_FS1_F",
                            "Acme-FlowMediaType_FS1_R",
                            "Acme-FlowMediaType_FS2_F",
                            "Acme-FlowMediaType_FS2_R",
                            "Acme-Flow-PTime_FS1_F",
                            "Acme-Flow-PTime_FS1_R",
                            "Acme-Flow-PTime_FS2_F",
                            "Acme-Flow-PTime_FS2_R",
                            "Acme-Session-Media-Process",
                            "Acme-Calling-R-Factor",
                            "Acme-Calling-MOS",
                            "Acme-Called-R-Factor",
                            "Acme-Called-MOS",
                            "Acme-Flow-In-Src-IPv6_Addr_FS1_F",
                            "Acme-Flow-In-Dst-IPv6_Addr_FS1_F",
                            "Acme-Flow-Out-Src-IPv6_Addr_FS1_F",
                            "Acme-Flow-Out-Dst-IPv6_Addr_FS1_F",
                            "Acme-Flow-In-Src-IPv6_Addr_FS1_R",
                            "Acme-Flow-In-Dst-IPv6_Addr_FS1_R",
                            "Acme-Flow-Out-Src-IPv6_Addr_FS1_R",
                            "Acme-Flow-Out-Dst-IPv6_Addr_FS1_R",
                            "Acme-Flow-In-Src-IPv6_Addr_FS2_F",
                            "Acme-Flow-In-Dst-IPv6_Addr_FS2_F",
                            "Acme-Flow-Out-Src-IPv6_Addr_FS2_F",
                            "Acme-Flow-Out-Dst-IPv6_Addr_FS2_F",
                            "Acme-Flow-In-Src-IPv6_Addr_FS2_R",
                            "Acme-Flow-In-Dst-IPv6_Addr_FS2_R",
                            "Acme-Flow-Out-Src-IPv6_Addr_FS2_R",
                            "Acme-Flow-Out-Dst-IPv6_Addr_FS2_R",
                            "Acme-Session-Forked-Call-Id",
                            "Acme-Custom-VSA-200",
                            "Acme-Custom-VSA-201",
                            "Acme-Custom-VSA-202",
                            "Acme-Custom-VSA-203",
                            "Acme-Custom-VSA-204",
                            "Acme-Custom-VSA-205",
                            "Acme-Custom-VSA-206",
                            "Acme-Custom-VSA-207",
                            "Acme-Custom-VSA-208",
                            "Acme-Custom-VSA-209",
                            "Acme-Custom-VSA-210",
                            "Acme-Custom-VSA-211",
                            "Acme-Custom-VSA-212",
                            "Acme-Custom-VSA-213",
                            "Acme-Custom-VSA-214",
                            "Acme-Custom-VSA-215",
                            "Acme-Custom-VSA-216",
                            "Acme-Custom-VSA-217",
                            "Acme-Custom-VSA-218",
                            "Acme-Custom-VSA-219",
                            "Acme-Custom-VSA-220",
                            "Acme-Custom-VSA-221",
                            "Acme-Custom-VSA-222",
                            "Acme-Custom-VSA-223",
                            "Acme-Custom-VSA-224",
                            "Acme-Custom-VSA-225",
                            "Acme-Custom-VSA-226",
                            "Acme-Custom-VSA-227",
                            "Acme-Custom-VSA-228",
                            "Acme-Custom-VSA-229",
                            "Acme-Custom-VSA-230",
                            "Acme-Flow-Calling-Media-Stop-Time-FS1",
                            "Acme-Flow-Called-Media-Stop-Time-FS1",
                            "Acme-Flow-Calling-Media-Stop-Time-FS2",
                            "Acme-Flow-Called-Media-Stop-Time-FS2",
                            "Acme-SIP-Method-Type",
                            "Acme-Domain-Name",
                            "Acme-SIP-Contact",
                            "Acme-SIP-Expires",
                            "Acme-Reason-Phrase",
                            "Acme-User-Privilege",
                            "Acme-User-Class",
                            "Actelis-Privilege",
                            "Adtran-AP-Name",
                            "Adtran-AP-IP",
                            "Adtran-AP-Template",
                            "Adtran-SSID",
                            "Adtran-Role",
                            "Airespace-Wlan-Id",
                            "Airespace-QOS-Level",
                            "Airespace-DSCP",
                            "Airespace-8021p-Tag",
                            "Airespace-Interface-Name",
                            "Airespace-ACL-Name",
                            "AAT-Client-Primary-DNS",
                            "AAT-Client-Primary-WINS-NBNS",
                            "AAT-Client-Secondary-WINS-NBNS",
                            "AAT-Client-Secondary-DNS",
                            "AAT-PPP-Address",
                            "AAT-PPP-Netmask",
                            "AAT-Primary-Home-Agent",
                            "AAT-Secondary-Home-Agent",
                            "AAT-Home-Agent-Password",
                            "AAT-Home-Network-Name",
                            "AAT-Home-Agent-UDP-Port",
                            "AAT-IP-Direct",
                            "AAT-FR-Direct",
                            "AAT-FR-Direct-Profile",
                            "AAT-FR-Direct-DLCI",
                            "AAT-ATM-Direct",
                            "AAT-IP-TOS",
                            "AAT-IP-TOS-Precedence",
                            "AAT-IP-TOS-Apply-To",
                            "AAT-MCast-Client",
                            "AAT-Modem-Port-No",
                            "AAT-Modem-Slot-No",
                            "AAT-Modem-Shelf-No",
                            "AAT-Filter",
                            "AAT-Vrouter-Name",
                            "AAT-Require-Auth",
                            "AAT-IP-Pool-Definition",
                            "AAT-Assign-IP-Pool",
                            "AAT-Data-Filter",
                            "AAT-Source-IP-Check",
                            "AAT-Modem-Answer-String",
                            "AAT-Auth-Type",
                            "AAT-Qos",
                            "AAT-Qoa",
                            "AAT-Client-Assign-DNS",
                            "AAT-ATM-VPI",
                            "AAT-ATM-VCI",
                            "AAT-Input-Octets-Diff",
                            "AAT-Output-Octets-Diff",
                            "AAT-User-MAC-Address",
                            "AAT-ATM-Traffic-Profile",
                            "Timetra-Access",
                            "Timetra-Home-Directory",
                            "Timetra-Restrict-To-Home",
                            "Timetra-Profile",
                            "Timetra-Default-Action",
                            "Timetra-Cmd",
                            "Timetra-Action",
                            "Timetra-Exec-File",
                            "Alc-Primary-Dns",
                            "Alc-Secondary-Dns",
                            "Alc-Subsc-ID-Str",
                            "Alc-Subsc-Prof-Str",
                            "Alc-SLA-Prof-Str",
                            "Alc-Force-Renew",
                            "Alc-Create-Host",
                            "Alc-ANCP-Str",
                            "Alc-Retail-Serv-Id",
                            "Alc-Default-Router",
                            "Alc-Client-Hardware-Addr",
                            "Alc-Acct-I-Inprof-Octets-64",
                            "Alc-Acct-I-Outprof-Octets-64",
                            "Alc-Acct-O-Inprof-Octets-64",
                            "Alc-Acct-O-Outprof-Octets-64",
                            "Alc-Acct-I-Inprof-Pkts-64",
                            "Alc-Acct-I-Outprof-Pkts-64",
                            "Alc-Acct-O-Inprof-Pkts-64",
                            "Alc-Acct-O-Outprof-Pkts-64",
                            "Alc-Int-Dest-Id-Str",
                            "Alc-Primary-Nbns",
                            "Alc-Secondary-Nbns",
                            "Alc-MSAP-Serv-Id",
                            "Alc-MSAP-Policy",
                            "Alc-MSAP-Interface",
                            "Alc-PPPoE-PADO-Delay",
                            "Alc-PPPoE-Service-Name",
                            "Alc-DHCP-Vendor-Class-Id",
                            "Alc-Acct-OC-I-Inprof-Octets-64",
                            "Alc-Acct-OC-I-Outprof-Octets-64",
                            "Alc-Acct-OC-O-Inprof-Octets-64",
                            "Alc-Acct-OC-O-Outprof-Octets-64",
                            "Alc-Acct-OC-I-Inprof-Pkts-64",
                            "Alc-Acct-OC-I-Outprof-Pkts-64",
                            "Alc-Acct-OC-O-Inprof-Pkts-64",
                            "Alc-Acct-OC-O-Outprof-Pkts-64",
                            "Alc-App-Prof-Str",
                            "Alc-Tunnel-Group",
                            "Alc-Tunnel-Algorithm",
                            "Alc-Tunnel-Max-Sessions",
                            "Alc-Tunnel-Idle-Timeout",
                            "Alc-Tunnel-Hello-Interval",
                            "Alc-Tunnel-Destruct-Timeout",
                            "Alc-Tunnel-Max-Retries-Estab",
                            "Alc-Tunnel-Max-Retries-Not-Estab",
                            "Alc-Tunnel-AVP-Hiding",
                            "Alc-BGP-Policy",
                            "Alc-BGP-Auth-Keychain",
                            "Alc-BGP-Auth-Key",
                            "Alc-BGP-Export-Policy",
                            "Alc-BGP-Import-Policy",
                            "Alc-BGP-PeerAS",
                            "Alc-IPsec-Serv-Id",
                            "Alc-IPsec-Interface",
                            "Alc-IPsec-Tunnel-Template-Id",
                            "Alc-IPsec-SA-Lifetime",
                            "Alc-IPsec-SA-PFS-Group",
                            "Alc-IPsec-SA-Encr-Algorithm",
                            "Alc-IPsec-SA-Auth-Algorithm",
                            "Alc-IPsec-SA-Replay-Window",
                            "Alc-Acct-I-High-Octets-Drop_64",
                            "Alc-Acct-I-Low-Octets-Drop_64",
                            "Alc-Acct-I-High-Pack-Drop_64",
                            "Alc-Acct-I-Low-Pack-Drop_64",
                            "Alc-Acct-I-High-Octets-Offer_64",
                            "Alc-Acct-I-Low-Octets-Offer_64",
                            "Alc-Acct-I-High-Pack-Offer_64",
                            "Alc-Acct-I-Low-Pack-Offer_64",
                            "Alc-Acct-I-Unc-Octets-Offer_64",
                            "Alc-Acct-I-Unc-Pack-Offer_64",
                            "Alc-Acct-I-All-Octets-Offer_64",
                            "Alc-Acct-I-All-Pack-Offer_64",
                            "Alc-Acct-O-Inprof-Pack-Drop_64",
                            "Alc-Acct-O-Outprof-Pack-Drop_64",
                            "Alc-Acct-O-Inprof-Octs-Drop_64",
                            "Alc-Acct-O-Outprof-Octs-Drop_64",
                            "Alc-Acct-OC-I-All-Octs-Offer_64",
                            "Alc-Acct-OC-I-All-Pack-Offer_64",
                            "Alc-Acct-OC-I-Inpr-Octs-Drop_64",
                            "Alc-Acct-OC-I-Outpr-Octs-Drop_64",
                            "Alc-Acct-OC-I-Inpr-Pack-Drop_64",
                            "Alc-Acct-OC-I-Outpr-Pack-Drop_64",
                            "Alc-Acct-OC-O-Inpr-Pack-Drop_64",
                            "Alc-Acct-OC-O-Outpr-Pack-Drop_64",
                            "Alc-Acct-OC-O-Inpr-Octs-Drop_64",
                            "Alc-Acct-OC-O-Outpr-Octs-Drop_64",
                            "Alc-Credit-Control-CategoryMap",
                            "Alc-Credit-Control-Quota",
                            "Alc-Tunnel-Challenge",
                            "Alc-Force-Nak",
                            "Alc-Ipv6-Address",
                            "Alc-Serv-Id",
                            "Alc-Interface",
                            "Alc-ToServer-Dhcp-Options",
                            "Alc-ToClient-Dhcp-Options",
                            "Alc-Tunnel-Serv-Id",
                            "Alc-Ipv6-Primary-Dns",
                            "Alc-Ipv6-Secondary-Dns",
                            "Alc-Acct-I-statmode",
                            "Alc-Acct-I-Hiprio-Octets_64",
                            "Alc-Acct-I-Lowprio-Octets_64",
                            "Alc-Acct-O-Hiprio-Octets_64",
                            "Alc-Acct-O-Lowprio-Octets_64",
                            "Alc-Acct-I-Hiprio-Packets_64",
                            "Alc-Acct-I-Lowprio-Packets_64",
                            "Alc-Acct-O-Hiprio-Packets_64",
                            "Alc-Acct-O-Lowprio-Packets_64",
                            "Alc-Acct-I-All-Octets_64",
                            "Alc-Acct-O-All-Octets_64",
                            "Alc-Acct-I-All-Packets_64",
                            "Alc-Acct-O-All-Packets_64",
                            "Alc-Tunnel-Rx-Window-Size",
                            "Alc-Nat-Port-Range",
                            "Alc-LI-Action",
                            "Alc-LI-Destination",
                            "Alc-LI-FC",
                            "Alc-LI-Direction",
                            "Alc-Subscriber-QoS-Override",
                            "Alc-Acct-O-statmode",
                            "Alc-ATM-Ingress-TD-Profile",
                            "Alc-ATM-Egress-TD-Profile",
                            "Alc-AA-Transit-IP",
                            "Alc-Delegated-IPv6-Pool",
                            "Alc-Access-Loop-Rate-Down",
                            "Alc-Access-Loop-Encap-Offset",
                            "Alc-Subscriber-Filter",
                            "Alc-PPP-Force-IPv6CP",
                            "Alc-Onetime-Http-Redirection-Filter-Id",
                            "Alc-Authentication-Policy-Name",
                            "Alc-LI-Intercept-Id",
                            "Alc-LI-Session-Id",
                            "Alc-Nat-Outside-Serv-Id",
                            "Alc-Nat-Outside-Ip-Addr",
                            "Alc-APN-Password",
                            "Alc-APN-Name",
                            "Alc-Tunnel-Acct-Policy",
                            "Alc-Mgw-Interface-Type",
                            "Alc-Wlan-APN-Name",
                            "Alc-MsIsdn",
                            "Alc-RSSI",
                            "Alc-Num-Attached-UEs",
                            "Alc-Charging-Prof-ID",
                            "Alc-AA-Group-Partition-Isa-Id",
                            "Alc-AA-Peer-Identifier",
                            "Alc-Nas-Filter-Rule-Shared",
                            "Alc-Ascend-Data-Filter-Host-Spec",
                            "Alc-Relative-Session-Timeout",
                            "Alc-Acct-Triggered-Reason",
                            "Alc-Wlan-Portal-Redirect",
                            "Alc-Wlan-Portal-Url",
                            "Alc-Lease-Time",
                            "Alc-Portal-Url",
                            "Alc-SLAAC-IPv6-Pool",
                            "Alc-Wlan-SSID-VLAN",
                            "ALU-AAA-Access-Rule",
                            "ALU-AAA-AV-Pair",
                            "ALU-AAA-GSM-Triplets-Needed",
                            "ALU-AAA-GSM-Triplet",
                            "ALU-AAA-AKA-Quintets-Needed",
                            "ALU-AAA-AKA-Quintet",
                            "ALU-AAA-AKA-RAND",
                            "ALU-AAA-AKA-AUTS",
                            "ALU-AAA-Service-Profile",
                            "ALU-AAA-Lawful-Intercept-Status",
                            "ALU-AAA-DF-CC-Address",
                            "ALU-AAA-DF-CC-Port",
                            "ALU-AAA-Client-Program",
                            "ALU-AAA-Client-Error-Action",
                            "ALU-AAA-Client-OS",
                            "ALU-AAA-Client-Version",
                            "ALU-AAA-Nonce",
                            "ALU-AAA-Femto-Public-Key-Hash",
                            "ALU-AAA-Femto-Associated-User-Name",
                            "ALU-AAA-String-0",
                            "ALU-AAA-String-1",
                            "ALU-AAA-String-2",
                            "ALU-AAA-String-3",
                            "ALU-AAA-Integer-0",
                            "ALU-AAA-Integer-1",
                            "ALU-AAA-Integer-2",
                            "ALU-AAA-Integer-3",
                            "ALU-AAA-Value-0",
                            "ALU-AAA-Value-1",
                            "ALU-AAA-Value-2",
                            "ALU-AAA-Value-3",
                            "ALU-AAA-Key-0",
                            "ALU-AAA-Key-1",
                            "ALU-AAA-Key-2",
                            "ALU-AAA-Key-3",
                            "ALU-AAA-Opaque-0",
                            "ALU-AAA-Opaque-1",
                            "ALU-AAA-Opaque-2",
                            "ALU-AAA-Opaque-3",
                            "ALU-AAA-Eval-0",
                            "ALU-AAA-Eval-1",
                            "ALU-AAA-Eval-2",
                            "ALU-AAA-Eval-3",
                            "ALU-AAA-Exec-0",
                            "ALU-AAA-Exec-1",
                            "ALU-AAA-Exec-2",
                            "ALU-AAA-Exec-3",
                            "ALU-AAA-Original-Receipt-Time",
                            "ALU-AAA-Reply-Message",
                            "ALU-AAA-Called-Station-Id",
                            "ALU-AAA-NAS-IP-Address",
                            "ALU-AAA-NAS-Port",
                            "ALU-AAA-Old-State",
                            "ALU-AAA-New-State",
                            "ALU-AAA-Event",
                            "ALU-AAA-Old-Timestamp",
                            "ALU-AAA-New-Timestamp",
                            "ALU-AAA-Delta-Session",
                            "ALU-AAA-Civic-Location",
                            "ALU-AAA-Geospatial-Location",
                            "Alteon-Group-Mapping",
                            "Alteon-VPN-Id",
                            "Alteon-Client-IP-Address",
                            "Alteon-Client-Netmask",
                            "Alteon-Primary-NBNS-Server",
                            "Alteon-Secondary-NBNS-Server",
                            "Alteon-Primary-DNS-Server",
                            "Alteon-Secondary-DNS-Server",
                            "Alteon-Domain-Name",
                            "Alteon-Service-Type",
                            "Alvarion-VSA-1",
                            "Alvarion-VSA-2",
                            "Alvarion-VSA-3",
                            "Alvarion-VSA-4",
                            "Alvarion-VSA-5",
                            "Alvarion-VSA-6",
                            "Alvarion-VSA-7",
                            "Alvarion-VSA-8",
                            "Alvarion-VSA-9",
                            "Alvarion-VSA-10",
                            "Alvarion-VSA-11",
                            "Alvarion-VSA-12",
                            "Alvarion-VSA-13",
                            "Alvarion-VSA-14",
                            "Alvarion-VSA-15",
                            "Alvarion-VSA-16",
                            "Alvarion-VSA-17",
                            "Alvarion-VSA-18",
                            "Alvarion-VSA-19",
                            "Alvarion-VSA-20",
                            "Alvarion-VSA-21",
                            "Alvarion-VSA-22",
                            "Alvarion-VSA-23",
                            "Alvarion-VSA-24",
                            "Alvarion-VSA-25",
                            "Alvarion-VSA-26",
                            "Alvarion-VSA-27",
                            "Alvarion-VSA-28",
                            "Alvarion-VSA-29",
                            "Alvarion-VSA-30",
                            "Alvarion-VSA-31",
                            "Alvarion-VSA-32",
                            "Alvarion-VSA-33",
                            "Alvarion-VSA-34",
                            "Alvarion-VSA-35",
                            "Alvarion-VSA-36",
                            "Alvarion-VSA-37",
                            "Alvarion-VSA-38",
                            "Alvarion-VSA-39",
                            "Alvarion-VSA-40",
                            "Alvarion-VSA-41",
                            "Alvarion-VSA-42",
                            "Alvarion-VSA-43",
                            "Alvarion-VSA-44",
                            "Alvarion-VSA-45",
                            "Alvarion-VSA-46",
                            "Alvarion-VSA-47",
                            "Alvarion-VSA-48",
                            "Alvarion-VSA-49",
                            "Alvarion-VSA-50",
                            "Alvarion-VSA-51",
                            "Alvarion-VSA-52",
                            "Alvarion-VSA-53",
                            "Alvarion-VSA-54",
                            "Alvarion-VSA-55",
                            "Alvarion-VSA-56",
                            "Alvarion-VSA-57",
                            "Alvarion-VSA-58",
                            "Alvarion-VSA-59",
                            "Alvarion-VSA-60",
                            "Alvarion-VSA-61",
                            "Alvarion-VSA-62",
                            "Alvarion-VSA-63",
                            "Alvarion-VSA-64",
                            "Alvarion-VSA-65",
                            "Alvarion-VSA-66",
                            "Alvarion-VSA-67",
                            "Alvarion-VSA-68",
                            "Alvarion-VSA-69",
                            "Alvarion-VSA-70",
                            "Alvarion-VSA-71",
                            "Alvarion-VSA-72",
                            "Alvarion-VSA-73",
                            "Alvarion-VSA-74",
                            "Alvarion-VSA-75",
                            "Alvarion-VSA-76",
                            "Alvarion-VSA-77",
                            "Alvarion-VSA-78",
                            "Alvarion-VSA-79",
                            "Alvarion-VSA-80",
                            "Alvarion-VSA-81",
                            "Alvarion-VSA-82",
                            "Alvarion-VSA-83",
                            "Alvarion-VSA-84",
                            "Alvarion-VSA-85",
                            "Alvarion-VSA-86",
                            "Alvarion-VSA-87",
                            "Alvarion-VSA-88",
                            "Alvarion-VSA-89",
                            "Alvarion-VSA-90",
                            "Alvarion-VSA-91",
                            "Alvarion-VSA-92",
                            "Alvarion-VSA-93",
                            "Alvarion-VSA-94",
                            "Alvarion-VSA-95",
                            "Alvarion-VSA-96",
                            "Alvarion-VSA-97",
                            "Alvarion-VSA-98",
                            "Alvarion-VSA-99",
                            "Alvarion-VSA-100",
                            "Alvarion-VSA-101",
                            "Alvarion-VSA-102",
                            "Alvarion-VSA-103",
                            "Alvarion-VSA-104",
                            "Alvarion-VSA-105",
                            "Alvarion-VSA-106",
                            "Alvarion-VSA-107",
                            "Alvarion-VSA-108",
                            "Alvarion-VSA-109",
                            "Alvarion-VSA-110",
                            "Alvarion-VSA-111",
                            "Alvarion-VSA-112",
                            "Alvarion-VSA-113",
                            "Alvarion-VSA-114",
                            "Alvarion-VSA-115",
                            "Alvarion-VSA-116",
                            "Alvarion-VSA-117",
                            "Alvarion-VSA-118",
                            "Alvarion-VSA-119",
                            "Alvarion-VSA-120",
                            "Alvarion-VSA-121",
                            "Alvarion-VSA-122",
                            "Alvarion-VSA-123",
                            "Alvarion-VSA-124",
                            "Alvarion-VSA-125",
                            "Alvarion-VSA-126",
                            "Alvarion-VSA-127",
                            "Alvarion-VSA-128",
                            "Alvarion-VSA-129",
                            "Alvarion-VSA-130",
                            "Alvarion-VSA-131",
                            "Alvarion-VSA-132",
                            "Alvarion-VSA-133",
                            "Alvarion-VSA-134",
                            "Alvarion-VSA-135",
                            "Alvarion-VSA-136",
                            "Alvarion-VSA-137",
                            "Alvarion-VSA-138",
                            "Alvarion-VSA-139",
                            "Alvarion-VSA-140",
                            "Alvarion-VSA-141",
                            "Alvarion-VSA-142",
                            "Alvarion-VSA-143",
                            "Alvarion-VSA-144",
                            "Alvarion-VSA-145",
                            "Alvarion-VSA-146",
                            "Alvarion-VSA-147",
                            "Alvarion-VSA-148",
                            "Alvarion-VSA-149",
                            "Alvarion-VSA-150",
                            "Alvarion-VSA-151",
                            "Alvarion-VSA-152",
                            "Alvarion-VSA-153",
                            "Alvarion-VSA-154",
                            "Alvarion-VSA-155",
                            "Alvarion-VSA-156",
                            "Alvarion-VSA-157",
                            "Alvarion-VSA-158",
                            "Alvarion-VSA-159",
                            "Alvarion-VSA-160",
                            "Alvarion-VSA-161",
                            "Alvarion-VSA-162",
                            "Alvarion-VSA-163",
                            "Alvarion-VSA-164",
                            "Alvarion-VSA-165",
                            "Alvarion-VSA-166",
                            "Alvarion-VSA-167",
                            "Alvarion-VSA-168",
                            "Alvarion-VSA-169",
                            "Alvarion-VSA-170",
                            "Alvarion-VSA-171",
                            "Alvarion-VSA-172",
                            "Alvarion-VSA-173",
                            "Alvarion-VSA-174",
                            "Alvarion-VSA-175",
                            "Alvarion-VSA-176",
                            "Alvarion-VSA-177",
                            "Alvarion-VSA-178",
                            "Alvarion-VSA-179",
                            "Alvarion-VSA-180",
                            "Alvarion-VSA-181",
                            "Alvarion-VSA-182",
                            "Alvarion-VSA-183",
                            "Alvarion-VSA-184",
                            "Alvarion-VSA-185",
                            "Alvarion-VSA-186",
                            "Alvarion-VSA-187",
                            "Alvarion-VSA-188",
                            "Alvarion-VSA-189",
                            "Alvarion-VSA-190",
                            "Alvarion-VSA-191",
                            "Alvarion-VSA-192",
                            "Alvarion-VSA-193",
                            "Alvarion-VSA-194",
                            "Alvarion-VSA-195",
                            "Alvarion-VSA-196",
                            "Alvarion-VSA-197",
                            "Alvarion-VSA-198",
                            "Alvarion-VSA-199",
                            "Alvarion-VSA-200",
                            "Alvarion-VSA-201",
                            "Alvarion-VSA-202",
                            "Alvarion-VSA-203",
                            "Alvarion-VSA-204",
                            "Alvarion-VSA-205",
                            "Alvarion-VSA-206",
                            "Alvarion-VSA-207",
                            "Alvarion-VSA-208",
                            "Alvarion-VSA-209",
                            "Alvarion-VSA-210",
                            "Alvarion-VSA-211",
                            "Alvarion-VSA-212",
                            "Alvarion-VSA-213",
                            "Alvarion-VSA-214",
                            "Alvarion-VSA-215",
                            "Alvarion-VSA-216",
                            "Alvarion-VSA-217",
                            "Alvarion-VSA-218",
                            "Alvarion-VSA-219",
                            "Alvarion-VSA-220",
                            "Alvarion-VSA-221",
                            "Alvarion-VSA-222",
                            "Alvarion-VSA-223",
                            "Alvarion-VSA-224",
                            "Alvarion-VSA-225",
                            "Alvarion-VSA-226",
                            "Alvarion-VSA-227",
                            "Alvarion-VSA-228",
                            "Alvarion-VSA-229",
                            "Alvarion-VSA-230",
                            "Alvarion-VSA-231",
                            "Alvarion-VSA-232",
                            "Alvarion-VSA-233",
                            "Alvarion-VSA-234",
                            "Alvarion-VSA-235",
                            "Alvarion-VSA-236",
                            "Alvarion-VSA-237",
                            "Alvarion-VSA-238",
                            "Alvarion-VSA-239",
                            "Alvarion-VSA-240",
                            "Alvarion-VSA-241",
                            "Alvarion-VSA-242",
                            "Alvarion-VSA-243",
                            "Alvarion-VSA-244",
                            "Alvarion-VSA-245",
                            "Alvarion-VSA-246",
                            "Alvarion-VSA-247",
                            "Alvarion-VSA-248",
                            "Alvarion-VSA-249",
                            "Alvarion-VSA-250",
                            "Alvarion-VSA-251",
                            "Alvarion-VSA-252",
                            "Alvarion-VSA-253",
                            "Alvarion-VSA-254",
                            "Alvarion-VSA-255",
                            "Breezecom-Attr1",
                            "Breezecom-Attr2",
                            "Breezecom-Attr3",
                            "Breezecom-Attr4",
                            "Breezecom-Attr5",
                            "Breezecom-Attr6",
                            "Breezecom-Attr7",
                            "Breezecom-Attr8",
                            "Breezecom-Attr9",
                            "Breezecom-Attr10",
                            "Breezecom-Attr11",
                            "APC-Service-Type",
                            "APC-Outlets",
                            "APC-Perms",
                            "APC-Username",
                            "APC-Contact",
                            "APC-ACCPX-Doors",
                            "APC-ACCPX-Status",
                            "APC-ACCPX-Access1",
                            "APC-ACCPX-Access2",
                            "APC-ACCPX-Access3",
                            "APC-ACCPX-Access4",
                            "APC-ACCPX-Access5",
                            "APC-ACCPX-Access6",
                            "APC-ACCPX-Access7",
                            "Aptilo-Subnet-Name",
                            "Aptilo-Octets-Limit",
                            "Aptilo-Gigawords-Limit",
                            "Aptilo-Input-Octets-Limit",
                            "Aptilo-Input-Gigawords-Limit",
                            "Aptilo-Output-Octets-Limit",
                            "Aptilo-Output-Gigawords-Limit",
                            "Aptilo-Limit-Mode",
                            "Aptilo-Apc-ID",
                            "Aptilo-Opaque-Key",
                            "Aptilo-Denied-Cause",
                            "Aptilo-Realm-ID",
                            "Aptilo-Ap-ID",
                            "Aptilo-User-ID",
                            "Aptilo-Zone",
                            "Aptilo-First-Name",
                            "Aptilo-Last-Name",
                            "Aptilo-Phone",
                            "Aptilo-Email",
                            "Aptilo-Organization",
                            "Aptilo-Access-Profile",
                            "Aptilo-Realm-Concurrent-Login",
                            "Aptilo-Auth-Result",
                            "Aptilo-Hotline-Indicator",
                            "Aptilo-User-Type",
                            "Aptilo-Exclusive-Count",
                            "Aptilo-Duration-Quota",
                            "Aptilo-Volume-Quota",
                            "Aptilo-RX-Volume-Quota",
                            "Aptilo-TX-Volume-Quota",
                            "Aptilo-Resource-Quota",
                            "Aptilo-Quota-ID",
                            "Aptilo-RX-Limit",
                            "Aptilo-TX-Limit",
                            "Aptilo-TRX-Limit",
                            "Aptilo-Bw-Min-Up",
                            "Aptilo-Bw-Max-Up",
                            "Aptilo-Bw-Min-Down",
                            "Aptilo-Bw-Max-Down",
                            "Aptilo-Service-Profile",
                            "Aptilo-Automatic-Service",
                            "Aptilo-Auth-Type",
                            "Aptilo-NAS-Capabilities",
                            "Aptilo-Service",
                            "Aptilo-Service-Profile-ID",
                            "Aptilo-Auth-Param",
                            "Aptilo-Access-Profile-ID",
                            "Aptilo-NAS-Model",
                            "Aptilo-Debug-Option",
                            "Aptilo-Session-Id",
                            "Aptilo-Prepaid-Capabilities",
                            "Aptilo-Octets-Quota",
                            "Aptilo-Octets-Threshold",
                            "Aptilo-Resource-Threshold",
                            "Aptilo-Duration-Threshold",
                            "Aptilo-Octets-Balance",
                            "Aptilo-Resource-Balance",
                            "Aptilo-Duration-Balance",
                            "Aptilo-Octets-Used",
                            "Aptilo-Resource-Used",
                            "Aptilo-Duration-Used",
                            "Aptilo-Octets-Request",
                            "Aptilo-Resource-Request",
                            "Aptilo-Duration-Request",
                            "Aptilo-QoS-Indicator",
                            "Aptilo-Key-String-1",
                            "Aptilo-Key-String-2",
                            "Aptilo-Key-String-3",
                            "Aptilo-Key-String-4",
                            "Aptilo-Key-String-5",
                            "Aptilo-Key-IP-1",
                            "Aptilo-Key-IP-2",
                            "Aptilo-Key-IP-3",
                            "Aptilo-Key-IP-4",
                            "Aptilo-Key-IP-5",
                            "Aptilo-Key-Integer-1",
                            "Aptilo-Key-Integer-2",
                            "Aptilo-Key-Integer-3",
                            "Aptilo-Key-Integer-4",
                            "Aptilo-Key-Integer-5",
                            "Arbor-Privilege-Level",
                            "Arista-AVPair",
                            "Arista-User-Priv-Level",
                            "Arista-User-Role",
                            "Arista-CVP-Role",
                            "Aruba-User-Role",
                            "Aruba-User-Vlan",
                            "Aruba-Priv-Admin-User",
                            "Aruba-Admin-Role",
                            "Aruba-Essid-Name",
                            "Aruba-Location-Id",
                            "Aruba-Port-Identifier",
                            "Aruba-MMS-User-Template",
                            "Aruba-Named-User-Vlan",
                            "Aruba-AP-Group",
                            "Aruba-Framed-IPv6-Address",
                            "Aruba-Device-Type",
                            "Aruba-No-DHCP-Fingerprint",
                            "Aruba-Mdps-Device-Udid",
                            "Aruba-Mdps-Device-Imei",
                            "Aruba-Mdps-Device-Iccid",
                            "Aruba-Mdps-Max-Devices",
                            "Aruba-Mdps-Device-Name",
                            "Aruba-Mdps-Device-Product",
                            "Aruba-Mdps-Device-Version",
                            "Aruba-Mdps-Device-Serial",
                            "Aruba-CPPM-Role",
                            "Aruba-AirGroup-User-Name",
                            "Aruba-AirGroup-Shared-User",
                            "Aruba-AirGroup-Shared-Role",
                            "Aruba-AirGroup-Device-Type",
                            "Aruba-Auth-Survivability",
                            "Aruba-AS-User-Name",
                            "Aruba-AS-Credential-Hash",
                            "Aruba-WorkSpace-App-Name",
                            "Aruba-Mdps-Provisioning-Settings",
                            "Aruba-Mdps-Device-Profile",
                            "Aruba-AP-IP-Address",
                            "Aruba-AirGroup-Shared-Group",
                            "Aruba-User-Group",
                            "Aruba-Network-SSO-Token",
                            "Aruba-AirGroup-Version",
                            "Aruba-Port-Bounce-Host",
                            "Aruba-Calea-Server-Ip",
                            "Aruba-Admin-Path",
                            "Azaire-Triplets",
                            "Azaire-IMSI",
                            "Azaire-MSISDN",
                            "Azaire-APN",
                            "Azaire-QoS",
                            "Azaire-Selection-Mode",
                            "Azaire-APN-Resolution-Req",
                            "Azaire-Start-Time",
                            "Azaire-NAS-Type",
                            "Azaire-Status",
                            "Azaire-APN-OI",
                            "Azaire-Auth-Type",
                            "Azaire-Gn-User-Name",
                            "Azaire-Brand-Code",
                            "Azaire-Policy-Name",
                            "Azaire-Client-Local-IP",
                            "Ascend-Max-Shared-Users",
                            "Ascend-UU-Info",
                            "Ascend-CIR-Timer",
                            "Ascend-FR-08-Mode",
                            "Ascend-Destination-Nas-Port",
                            "Ascend-FR-SVC-Addr",
                            "Ascend-NAS-Port-Format",
                            "Ascend-ATM-Fault-Management",
                            "Ascend-ATM-Loopback-Cell-Loss",
                            "Ascend-Ckt-Type",
                            "Ascend-SVC-Enabled",
                            "Ascend-Session-Type",
                            "Ascend-H323-Gatekeeper",
                            "Ascend-Global-Call-Id",
                            "Ascend-H323-Conference-Id",
                            "Ascend-H323-Fegw-Address",
                            "Ascend-H323-Dialed-Time",
                            "Ascend-Dialed-Number",
                            "Ascend-Inter-Arrival-Jitter",
                            "Ascend-Dropped-Octets",
                            "Ascend-Dropped-Packets",
                            "Ascend-Auth-Delay",
                            "Ascend-X25-Pad-X3-Profile",
                            "Ascend-X25-Pad-X3-Parameters",
                            "Ascend-Tunnel-VRouter-Name",
                            "Ascend-X25-Reverse-Charging",
                            "Ascend-X25-Nui-Prompt",
                            "Ascend-X25-Nui-Password-Prompt",
                            "Ascend-X25-Cug",
                            "Ascend-X25-Pad-Alias-1",
                            "Ascend-X25-Pad-Alias-2",
                            "Ascend-X25-Pad-Alias-3",
                            "Ascend-X25-X121-Address",
                            "Ascend-X25-Nui",
                            "Ascend-X25-Rpoa",
                            "Ascend-X25-Pad-Prompt",
                            "Ascend-X25-Pad-Banner",
                            "Ascend-X25-Profile-Name",
                            "Ascend-Recv-Name",
                            "Ascend-Bi-Directional-Auth",
                            "Ascend-MTU",
                            "Ascend-Call-Direction",
                            "Ascend-Service-Type",
                            "Ascend-Filter-Required",
                            "Ascend-Traffic-Shaper",
                            "Ascend-Access-Intercept-LEA",
                            "Ascend-Access-Intercept-Log",
                            "Ascend-Private-Route-Table-ID",
                            "Ascend-Private-Route-Required",
                            "Ascend-Cache-Refresh",
                            "Ascend-Cache-Time",
                            "Ascend-Egress-Enabled",
                            "Ascend-QOS-Upstream",
                            "Ascend-QOS-Downstream",
                            "Ascend-ATM-Connect-Vpi",
                            "Ascend-ATM-Connect-Vci",
                            "Ascend-ATM-Connect-Group",
                            "Ascend-ATM-Group",
                            "Ascend-IPX-Header-Compression",
                            "Ascend-Calling-Id-Type-Of-Num",
                            "Ascend-Calling-Id-Number-Plan",
                            "Ascend-Calling-Id-Presentatn",
                            "Ascend-Calling-Id-Screening",
                            "Ascend-BIR-Enable",
                            "Ascend-BIR-Proxy",
                            "Ascend-BIR-Bridge-Group",
                            "Ascend-IPSEC-Profile",
                            "Ascend-PPPoE-Enable",
                            "Ascend-Bridge-Non-PPPoE",
                            "Ascend-ATM-Direct",
                            "Ascend-ATM-Direct-Profile",
                            "Ascend-Client-Primary-WINS",
                            "Ascend-Client-Secondary-WINS",
                            "Ascend-Client-Assign-WINS",
                            "Ascend-Auth-Type",
                            "Ascend-Port-Redir-Protocol",
                            "Ascend-Port-Redir-Portnum",
                            "Ascend-Port-Redir-Server",
                            "Ascend-IP-Pool-Chaining",
                            "Ascend-Owner-IP-Addr",
                            "Ascend-IP-TOS",
                            "Ascend-IP-TOS-Precedence",
                            "Ascend-IP-TOS-Apply-To",
                            "Ascend-Filter",
                            "Ascend-Telnet-Profile",
                            "Ascend-Dsl-Rate-Type",
                            "Ascend-Redirect-Number",
                            "Ascend-ATM-Vpi",
                            "Ascend-ATM-Vci",
                            "Ascend-Source-IP-Check",
                            "Ascend-Dsl-Rate-Mode",
                            "Ascend-Dsl-Upstream-Limit",
                            "Ascend-Dsl-Downstream-Limit",
                            "Ascend-Dsl-CIR-Recv-Limit",
                            "Ascend-Dsl-CIR-Xmit-Limit",
                            "Ascend-VRouter-Name",
                            "Ascend-Source-Auth",
                            "Ascend-Private-Route",
                            "Ascend-Numbering-Plan-ID",
                            "Ascend-FR-Link-Status-DLCI",
                            "Ascend-Calling-Subaddress",
                            "Ascend-Callback-Delay",
                            "Ascend-Endpoint-Disc",
                            "Ascend-Remote-FW",
                            "Ascend-Multicast-GLeave-Delay",
                            "Ascend-CBCP-Enable",
                            "Ascend-CBCP-Mode",
                            "Ascend-CBCP-Delay",
                            "Ascend-CBCP-Trunk-Group",
                            "Ascend-Appletalk-Route",
                            "Ascend-Appletalk-Peer-Mode",
                            "Ascend-Route-Appletalk",
                            "Ascend-FCP-Parameter",
                            "Ascend-Modem-PortNo",
                            "Ascend-Modem-SlotNo",
                            "Ascend-Modem-ShelfNo",
                            "Ascend-Call-Attempt-Limit",
                            "Ascend-Call-Block-Duration",
                            "Ascend-Maximum-Call-Duration",
                            "Ascend-Temporary-Rtes",
                            "Ascend-Tunneling-Protocol",
                            "Ascend-Shared-Profile-Enable",
                            "Ascend-Primary-Home-Agent",
                            "Ascend-Secondary-Home-Agent",
                            "Ascend-Dialout-Allowed",
                            "Ascend-Client-Gateway",
                            "Ascend-BACP-Enable",
                            "Ascend-DHCP-Maximum-Leases",
                            "Ascend-Client-Primary-DNS",
                            "Ascend-Client-Secondary-DNS",
                            "Ascend-Client-Assign-DNS",
                            "Ascend-User-Acct-Type",
                            "Ascend-User-Acct-Host",
                            "Ascend-User-Acct-Port",
                            "Ascend-User-Acct-Key",
                            "Ascend-User-Acct-Base",
                            "Ascend-User-Acct-Time",
                            "Ascend-Assign-IP-Client",
                            "Ascend-Assign-IP-Server",
                            "Ascend-Assign-IP-Global-Pool",
                            "Ascend-DHCP-Reply",
                            "Ascend-DHCP-Pool-Number",
                            "Ascend-Expect-Callback",
                            "Ascend-Event-Type",
                            "Ascend-Session-Svr-Key",
                            "Ascend-Multicast-Rate-Limit",
                            "Ascend-IF-Netmask",
                            "Ascend-Remote-Addr",
                            "Ascend-Multicast-Client",
                            "Ascend-FR-Circuit-Name",
                            "Ascend-FR-LinkUp",
                            "Ascend-FR-Nailed-Grp",
                            "Ascend-FR-Type",
                            "Ascend-FR-Link-Mgt",
                            "Ascend-FR-N391",
                            "Ascend-FR-DCE-N392",
                            "Ascend-FR-DTE-N392",
                            "Ascend-FR-DCE-N393",
                            "Ascend-FR-DTE-N393",
                            "Ascend-FR-T391",
                            "Ascend-FR-T392",
                            "Ascend-Bridge-Address",
                            "Ascend-TS-Idle-Limit",
                            "Ascend-TS-Idle-Mode",
                            "Ascend-DBA-Monitor",
                            "Ascend-Base-Channel-Count",
                            "Ascend-Minimum-Channels",
                            "Ascend-IPX-Route",
                            "Ascend-FT1-Caller",
                            "Ascend-Backup",
                            "Ascend-Call-Type",
                            "Ascend-Group",
                            "Ascend-FR-DLCI",
                            "Ascend-FR-Profile-Name",
                            "Ascend-Ara-PW",
                            "Ascend-IPX-Node-Addr",
                            "Ascend-Home-Agent-IP-Addr",
                            "Ascend-Home-Agent-Password",
                            "Ascend-Home-Network-Name",
                            "Ascend-Home-Agent-UDP-Port",
                            "Ascend-Multilink-ID",
                            "Ascend-Num-In-Multilink",
                            "Ascend-First-Dest",
                            "Ascend-Pre-Input-Octets",
                            "Ascend-Pre-Output-Octets",
                            "Ascend-Pre-Input-Packets",
                            "Ascend-Pre-Output-Packets",
                            "Ascend-Maximum-Time",
                            "Ascend-Disconnect-Cause",
                            "Ascend-Connect-Progress",
                            "Ascend-Data-Rate",
                            "Ascend-PreSession-Time",
                            "Ascend-Token-Idle",
                            "Ascend-Token-Immediate",
                            "Ascend-Require-Auth",
                            "Ascend-Number-Sessions",
                            "Ascend-Authen-Alias",
                            "Ascend-Token-Expiry",
                            "Ascend-Menu-Selector",
                            "Ascend-Menu-Item",
                            "Ascend-PW-Warntime",
                            "Ascend-PW-Lifetime",
                            "Ascend-IP-Direct",
                            "Ascend-PPP-VJ-Slot-Comp",
                            "Ascend-PPP-VJ-1172",
                            "Ascend-PPP-Async-Map",
                            "Ascend-Third-Prompt",
                            "Ascend-Send-Secret",
                            "Ascend-Receive-Secret",
                            "Ascend-IPX-Peer-Mode",
                            "Ascend-IP-Pool-Definition",
                            "Ascend-Assign-IP-Pool",
                            "Ascend-FR-Direct",
                            "Ascend-FR-Direct-Profile",
                            "Ascend-FR-Direct-DLCI",
                            "Ascend-Handle-IPX",
                            "Ascend-Netware-timeout",
                            "Ascend-IPX-Alias",
                            "Ascend-Metric",
                            "Ascend-PRI-Number-Type",
                            "Ascend-Dial-Number",
                            "Ascend-Route-IP",
                            "Ascend-Route-IPX",
                            "Ascend-Bridge",
                            "Ascend-Send-Auth",
                            "Ascend-Send-Passwd",
                            "Ascend-Link-Compression",
                            "Ascend-Target-Util",
                            "Ascend-Maximum-Channels",
                            "Ascend-Inc-Channel-Count",
                            "Ascend-Dec-Channel-Count",
                            "Ascend-Seconds-Of-History",
                            "Ascend-History-Weigh-Type",
                            "Ascend-Add-Seconds",
                            "Ascend-Remove-Seconds",
                            "Ascend-Data-Filter",
                            "Ascend-Call-Filter",
                            "Ascend-Idle-Limit",
                            "Ascend-Preempt-Limit",
                            "Ascend-Callback",
                            "Ascend-Data-Svc",
                            "Ascend-Force-56",
                            "Ascend-Billing-Number",
                            "Ascend-Call-By-Call",
                            "Ascend-Transit-Number",
                            "Ascend-Host-Info",
                            "Ascend-PPP-Address",
                            "Ascend-MPP-Idle-Percent",
                            "Ascend-Xmit-Rate",
                            "Annex-Filter",
                            "Annex-CLI-Command",
                            "Annex-CLI-Filter",
                            "Annex-Host-Restrict",
                            "Annex-Host-Allow",
                            "Annex-Product-Name",
                            "Annex-SW-Version",
                            "Annex-Local-IP-Address",
                            "Annex-Callback-Portlist",
                            "Annex-Sec-Profile-Index",
                            "Annex-Tunnel-Authen-Type",
                            "Annex-Tunnel-Authen-Mode",
                            "Annex-Authen-Servers",
                            "Annex-Acct-Servers",
                            "Annex-User-Server-Location",
                            "Annex-Local-Username",
                            "Annex-System-Disc-Reason",
                            "Annex-Modem-Disc-Reason",
                            "Annex-Disconnect-Reason",
                            "Annex-Addr-Resolution-Protocol",
                            "Annex-Addr-Resolution-Servers",
                            "Annex-Domain-Name",
                            "Annex-Transmit-Speed",
                            "Annex-Receive-Speed",
                            "Annex-Input-Filter",
                            "Annex-Output-Filter",
                            "Annex-Primary-DNS-Server",
                            "Annex-Secondary-DNS-Server",
                            "Annex-Primary-NBNS-Server",
                            "Annex-Secondary-NBNS-Server",
                            "Annex-Syslog-Tap",
                            "Annex-Keypress-Timeout",
                            "Annex-Unauthenticated-Time",
                            "Annex-Re-CHAP-Timeout",
                            "Annex-MRRU",
                            "Annex-EDO",
                            "Annex-PPP-Trace-Level",
                            "Annex-Pre-Input-Octets",
                            "Annex-Pre-Output-Octets",
                            "Annex-Pre-Input-Packets",
                            "Annex-Pre-Output-Packets",
                            "Annex-Connect-Progress",
                            "Annex-Multicast-Rate-Limit",
                            "Annex-Maximum-Call-Duration",
                            "Annex-Multilink-Id",
                            "Annex-Num-In-Multilink",
                            "Annex-Secondary-Srv-Endpoint",
                            "Annex-Gwy-Selection-Mode",
                            "Annex-Logical-Channel-Number",
                            "Annex-Wan-Number",
                            "Annex-Port",
                            "Annex-Pool-Id",
                            "Annex-Compression-Protocol",
                            "Annex-Transmitted-Packets",
                            "Annex-Retransmitted-Packets",
                            "Annex-Signal-to-Noise-Ratio",
                            "Annex-Retrain-Requests-Sent",
                            "Annex-Retrain-Requests-Rcvd",
                            "Annex-Rate-Reneg-Req-Sent",
                            "Annex-Rate-Reneg-Req-Rcvd",
                            "Annex-Begin-Receive-Line-Level",
                            "Annex-End-Receive-Line-Level",
                            "Annex-Begin-Modulation",
                            "Annex-Error-Correction-Prot",
                            "Annex-End-Modulation",
                            "Annex-User-Level",
                            "Annex-Audit-Level",
                            "CES-Group",
                            "Passport-Access-Priority",
                            "Annex-Cli-Commands",
                            "Annex-Command-Access",
                            "Commands",
                            "BSN-User-Role",
                            "BSN-AVPair",
                            "BinTec-biboPPPTable",
                            "BinTec-biboDialTable",
                            "BinTec-ipExtIfTable",
                            "BinTec-ipRouteTable",
                            "BinTec-ipExtRtTable",
                            "BinTec-ipNatPresetTable",
                            "BinTec-ipxCircTable",
                            "BinTec-ripCircTable",
                            "BinTec-sapCircTable",
                            "BinTec-ipxStaticRouteTable",
                            "BinTec-ipxStaticServTable",
                            "BinTec-ospfIfTable",
                            "BinTec-pppExtIfTable",
                            "BinTec-ipFilterTable",
                            "BinTec-ipQoSTable",
                            "BinTec-qosIfTable",
                            "BinTec-qosPolicyTable",
                            "Blue-Coat-Group",
                            "Blue-Coat-Authorization",
                            "BW-Venue-Id",
                            "BW-Venue-TZ",
                            "BW-Service-Type",
                            "BW-Class",
                            "BW-Venue-Description",
                            "BW-Venue-Price-Type",
                            "BW-Venue-Port-Type",
                            "BW-ISO-Country-Code",
                            "BW-e164-Country-Code",
                            "BW-State-Name",
                            "BW-City-Name",
                            "BW-Area-Code",
                            "CL-Brand",
                            "CL-Software-Version",
                            "CL-Reg-Number",
                            "CL-Method-Version",
                            "CL-Token-Version",
                            "CL-APDB-Version",
                            "CL-User-Agent",
                            "CL-SSC",
                            "BW-User-Group",
                            "BW-Venue-Name",
                            "BW-Category",
                            "BW-User-Role",
                            "BW-User-Name",
                            "BW-User-Password",
                            "BW-User-Prefix",
                            "BW-User-Realm",
                            "BW-Operator-Name",
                            "BWAS-Record-id",
                            "BWAS-Service-provider",
                            "BWAS-Type",
                            "BWAS-User-Number",
                            "BWAS-Group-Number",
                            "BWAS-Direction",
                            "BWAS-Calling-Number",
                            "BWAS-Calling-Presentation-Indic",
                            "BWAS-Called-Number",
                            "BWAS-Start-Time",
                            "BWAS-User-Timezone",
                            "BWAS-Answer-Indic",
                            "BWAS-Answer-Time",
                            "BWAS-Release-Time",
                            "BWAS-Termination-Cause",
                            "BWAS-Network-Type",
                            "BWAS-Carrier-Identification-Code",
                            "BWAS-Dialed-Digits",
                            "BWAS-Call-Category",
                            "BWAS-Network-Call-Type",
                            "BWAS-Network-Translated-Number",
                            "BWAS-Network-Translated-Group",
                            "BWAS-Releasing-Party",
                            "BWAS-Route",
                            "BWAS-Network-Callid",
                            "BWAS-Codec",
                            "BWAS-Access-Device-Address",
                            "BWAS-Access-Callid",
                            "BWAS-Spare-29",
                            "BWAS-Failover-Correlation-Id",
                            "BWAS-Spare-31",
                            "BWAS-Group",
                            "BWAS-Department",
                            "BWAS-Account-Code",
                            "BWAS-Authorization-Code",
                            "BWAS-Original-Called-Number",
                            "BWAS-Original-Called-Presentation-Indic",
                            "BWAS-Original-Called-Reason",
                            "BWAS-Redirecting-Number",
                            "BWAS-Redirecting-Presentation-Indic",
                            "BWAS-Redirecting-Reason",
                            "BWAS-Charge-Indic",
                            "BWAS-Type-Of-Network",
                            "BWAS-VP-Calling-Invoke-Time",
                            "BWAS-Local-Callid",
                            "BWAS-Remote-Callid",
                            "BWAS-Calling-Party-Category",
                            "BWAS-Conference-Invoke-Time",
                            "BWAS-Conference-Callid",
                            "BWAS-Conference-To",
                            "BWAS-Conference-From",
                            "BWAS-Conference-Id",
                            "BWAS-Conference-Role",
                            "BWAS-Conference-Bridge",
                            "BWAS-Conference-Owner",
                            "BWAS-Conference-Owner-Dn",
                            "BWAS-Conference-Title",
                            "BWAS-Conference-Project-Code",
                            "BWAS-Charging-Vector-Key",
                            "BWAS-Charging-Vection-Creator",
                            "BWAS-Charging-Vection-Orig",
                            "BWAS-Charging-Vection-Term",
                            "BWAS-Acc-Per-Call-Invoke-Time",
                            "BWAS-Acc-Per-Call-Fac-Result",
                            "BWAS-Acb-Act-Invoke-Time",
                            "BWAS-Acb-Act-Fac-Result",
                            "BWAS-Acb-Deact-Invoke-Time",
                            "BWAS-Acb-Deact-Fac-Result",
                            "BWAS-Call-Park-Invoke-Time",
                            "BWAS-Call-Park-Fac-Result",
                            "BWAS-Call-Park-Retr-Invoke-Time",
                            "BWAS-Call-Park-Retr-Fac-Result",
                            "BWAS-Call-Pickup-Invoke-Time",
                            "BWAS-Call-Pickup-Fac-Result",
                            "BWAS-Directed-Call-Pickup-Invoke-Time",
                            "BWAS-Directed-Call-Pickup-Fac-Result",
                            "BWAS-Dpubi-Invoke-Time",
                            "BWAS-Dpubi-Fac-Result",
                            "BWAS-Cancel-Cwt-Per-Call-Invoke-Time",
                            "BWAS-Cancel-Cwt-Per-Call-Fac-Result",
                            "BWAS-Cfa-Act-Invoke-Time",
                            "BWAS-Cfa-Act-Fac-Result",
                            "BWAS-Cfa-Deact-Invoke-Time",
                            "BWAS-Cfa-Deact-Fac-Result",
                            "BWAS-Cfb-Act-Invoke-Time",
                            "BWAS-Cfb-Act-Fac-Result",
                            "BWAS-Cfb-Deact-Invoke-Time",
                            "BWAS-Cfb-Deact-Fac-Result",
                            "BWAS-Cfna-Act-Invoke-Time",
                            "BWAS-Cfna-Act-Fac-Result",
                            "BWAS-Cfna-Deact-Invoke-Time",
                            "BWAS-Cfna-Deact-Fac-Result",
                            "BWAS-Clid-Delivery-Per-Call-Invoke-Time",
                            "BWAS-Clid-Delivery-Per-Call-Fac-Result",
                            "BWAS-Clid-Blocking-Per-Call-Invoke-Time",
                            "BWAS-Clid-Blocking-Per-Call-Fac-Result",
                            "BWAS-Cot-Invoke-Time",
                            "BWAS-Cot-Fac-Result",
                            "BWAS-Direct-Vm-Xfer-Invoke-Time",
                            "BWAS-Direct-Vm-Xfer-Fac-Result",
                            "BWAS-Dnd-Act-Invoke-Time",
                            "BWAS-Dnd-Act-Fac-Result",
                            "BWAS-Dnd-Deact-Invoke-Time",
                            "BWAS-Dnd-Deact-Fac-Result",
                            "BWAS-Sac-Lock-Invoke-Time",
                            "BWAS-Sac-Lock-Fac-Result",
                            "BWAS-Sac-Unlock-Invoke-Time",
                            "BWAS-Sac-Unlock-Fac-Result",
                            "BWAS-Flash-Call-Hold-Invoke-Time",
                            "BWAS-Flash-Call-Hold-Fac-Result",
                            "BWAS-Last-Number-Redial-Invoke-Time",
                            "BWAS-Last-Number-Redial-Fac-Result",
                            "BWAS-Return-Call-Invoke-Time",
                            "BWAS-Return-Call-Fac-Result",
                            "BWAS-Sd100-Programming-Invoke-Time",
                            "BWAS-Sd100-Programming-Fac-Result",
                            "BWAS-Sd8-Programming-Invoke-Time",
                            "BWAS-Sd8-Programming-Fac-Result",
                            "BWAS-Clear-Mwi-Invoke-Time",
                            "BWAS-Clear-Mwi-Fac-Result",
                            "BWAS-UserId",
                            "BWAS-Other-Party-Name",
                            "BWAS-Other-Party-Name-Pres-Indic",
                            "BWAS-Moh-Deact-Fac-Result",
                            "BWAS-Push-to-Talk-Invoke-Time",
                            "BWAS-Push-to-Talk-Fac-Result",
                            "BWAS-Hoteling-Invoke-Time",
                            "BWAS-Hoteling-Group",
                            "BWAS-Hoteling-UserId",
                            "BWAS-Hoteling-User-Number",
                            "BWAS-Hoteling-Group-Number",
                            "BWAS-Diversion-Inhibitor-Invoke-time",
                            "BWAS-Diversion-Inhibitor-Fac-Result",
                            "BWAS-Trunk-Group-Name",
                            "BWAS-Spare-136",
                            "BWAS-InstantGroupCall-Invoke-Time",
                            "BWAS-InstantGroupCall-PushToTalk",
                            "BWAS-InstantGroupCall-Related-Callid",
                            "BWAS-CustomRingback-Invoke-Time",
                            "BWAS-CLID-Permitted",
                            "BWAS-AHR-Invoke-Time",
                            "BWAS-AHR-Action",
                            "BWAS-Access-Network-Info",
                            "BWAS-Charging-Function-Addresses",
                            "BWAS-Charge-Number",
                            "BWAS-Related-CallId",
                            "BWAS-Related-CallId-Reason",
                            "BWAS-Transfer-Invoke-Time",
                            "BWAS-Transfer-Result",
                            "BWAS-Transfer-Related-CallId",
                            "BWAS-Transfer-Type",
                            "BWAS-Conf-Start-Time",
                            "BWAS-Conf-Stop-Time",
                            "BWAS-Conf-Id",
                            "BWAS-Conf-Type",
                            "BWAS-Codec-Usage",
                            "BWAS-Vmb-Act-Invoke-Time",
                            "BWAS-Vmb-Act-Fac-Result",
                            "BWAS-Vmb-Deact-Invoke-Time",
                            "BWAS-Vmb-Deact-Fac-Result",
                            "BWAS-Vmna-Act-Invoke-Time",
                            "BWAS-Vmna-Act-Fac-Result",
                            "BWAS-Vmna-Deact-Invoke-Time",
                            "BWAS-Vmna-Deact-Fac-Result",
                            "BWAS-Vma-Act-Invoke-Time",
                            "BWAS-Vma-Act-Fac-Result",
                            "BWAS-Vma-Deact-Invoke-Time",
                            "BWAS-Vma-Deact-Fac-Result",
                            "BWAS-No-Answer-Set-Invoke-Time",
                            "BWAS-No-Answer-Set-Fac-Result",
                            "BWAS-Clid-Blocking-Act-Invoke-Time",
                            "BWAS-Clid-Blocking-Act-Fac-Result",
                            "BWAS-Clid-Blocking-Deact-Invoke-Time",
                            "BWAS-Clid-Blocking-Deact-Fac-Result",
                            "BWAS-Call-Waiting-Act-Invoke-Time",
                            "BWAS-Call-Waiting-Act-Fac-Result",
                            "BWAS-Call-Waiting-Deact-Invoke-Time",
                            "BWAS-Call-Waiting-Deact-Fac-Result",
                            "BWAS-Fax-Messaging",
                            "BWAS-TSD-Digits",
                            "BWAS-Trunk-Group-Info",
                            "BWAS-Recall-Type",
                            "BWAS-Cfnrc-Act-Invoke-Time",
                            "BWAS-Cfnrc-Act-Fac-Result",
                            "BWAS-Cfnrc-Deact-Invoke-Time",
                            "BWAS-Cfnrc-Deact-Fac-Result",
                            "BWAS-Q850-Cause",
                            "BWAS-Dialed-Digits-Context",
                            "BWAS-Called-Number-Context",
                            "BWAS-Network-Translated-Number-Context",
                            "BWAS-Calling-Number-Context",
                            "BWAS-Original-Called-Number-Context",
                            "BWAS-Redirecting-Number-Context",
                            "BWAS-Location-Control-Act-Result",
                            "BWAS-Location-Control-Deact-Result",
                            "BWAS-Call-Retrieve-Result",
                            "BWAS-Routing-Number",
                            "BWAS-Origination-Method",
                            "BWAS-Call-Parked-Invoke-Time",
                            "BWAS-BA-Related-Call-Id",
                            "BWAS-Acr-Act-Invoke-Time",
                            "BWAS-Acr-Act-Fac-Result",
                            "BWAS-Acr-Deact-Invoke-Time",
                            "BWAS-Acr-Deact-Fac-Result",
                            "BWAS-Outside-Access-Code",
                            "BWAS-Primary-Device-Line-Port",
                            "BWAS-Called-Asserted-Identity",
                            "BWAS-Called-Asserted-Pres-Indicator",
                            "BWAS-SDP",
                            "BWAS-Media-Initiator-Flag",
                            "BWAS-SDP-Offer-Timestamp",
                            "BWAS-SDP-Answer-Timestamp",
                            "BWAS-Early-Media-SDP",
                            "BWAS-Early-Media-Initiator-Flag",
                            "BWAS-Body-Content-Type",
                            "BWAS-Body-Content-Length",
                            "BWAS-Body-Content-Disposition",
                            "BWAS-Body-Originator",
                            "BWAS-SIP-Error-Code",
                            "BWAS-OtherInfoInPCV",
                            "BWAS-Received-Calling-Number",
                            "BWAS-CustomRingback-Media-Selection",
                            "BWAS-AOC-Type",
                            "BWAS-AOC-Charge",
                            "BWAS-AOC-Currency",
                            "BWAS-AOC-Time",
                            "BWAS-AOC-Sum",
                            "BWAS-AOC-Activation-Time",
                            "BWAS-AOC-Result",
                            "BWAS-AS-Call-Type",
                            "BWAS-Scf-Act-Invoke-Time",
                            "BWAS-Scf-Act-Fac-Result",
                            "BWAS-Scf-Deact-Invoke-Time",
                            "BWAS-Scf-Deact-Fac-Result",
                            "BWAS-Cfa-Inter-Invoke-Time",
                            "BWAS-Cfa-Inter-Fac-Result",
                            "BWAS-Cfna-Inter-Invoke-Time",
                            "BWAS-Cfna-Inter-Fac-Result",
                            "BWAS-Cfb-Inter-Invoke-Time",
                            "BWAS-Cfb-Inter-Fac-Result",
                            "BWAS-CBF-Auth-Code",
                            "BWAS-Call-Bridge-Result",
                            "BWAS-Return-Call-Number-Deletion-Invoke-Time",
                            "BWAS-Return-Call-Number-Deletion-Fac-Result",
                            "BWAS-Prepaid-Status",
                            "BWAS-Configurable-CLID",
                            "BWAS-Call-Center-Night-Service-Act-Result",
                            "BWAS-Call-Center-Night-Service-Deact-Result",
                            "BWAS-Call-Center-Forced-Forwarding-Act-Result",
                            "BWAS-Call-Center-Forced-Forwarding-Deact-Result",
                            "BWAS-Call-Center-Outgoing-Call-Fac-Result",
"BWAS-Call-Center-Outgoing-Personal-Call-Fac-Result",
                            "BWAS-Call-Center-Outgoing-Phone-Number",
                            "BroadSoft-Attr-255",
                            "Brocade-Auth-Role",
                            "Brocade-AVPairs1",
                            "Brocade-AVPairs2",
                            "Brocade-AVPairs3",
                            "Brocade-AVPairs4",
                            "Brocade-Passwd-ExpiryDate",
                            "Brocade-Passwd-WarnPeriod",
                            "Sky-Wifi-AP-ID",
                            "Sky-Wifi-Service-ID",
                            "Sky-Wifi-Filter-Profile",
                            "Sky-Wifi-Billing-Class",
                            "Sky-Wifi-Provider-ID",
                            "Sky-Wifi-Credentials",
                            "SID-Auth",
                            "CableLabs-Reserved",
                            "CableLabs-Event-Message",
                            "CableLabs-MTA-Endpoint-Name",
                            "CableLabs-Calling-Party-Number",
                            "CableLabs-Called-Party-Number",
                            "CableLabs-Database-ID",
                            "CableLabs-Query-Type",
                            "CableLabs-Returned-Number",
                            "CableLabs-Call-Termination-Cause",
                            "CableLabs-Related-Call-Billing-Crl-ID",
                            "CableLabs-First-Call-Calling-Party-Num",
                            "CableLabs-Second-Call-Calling-Party-Num",
                            "CableLabs-Charge-Number",
                            "CableLabs-Forwarded-Number",
                            "CableLabs-Service-Name",
                            "CableLabs-Intl-Code",
                            "CableLabs-Dial-Around-Code",
                            "CableLabs-Location-Routing-Number",
                            "CableLabs-Carrier-Identification-Code",
                            "CableLabs-Trunk-Group-ID",
                            "CableLabs-Routing-Number",
                            "CableLabs-MTA-UDP-Portnum",
                            "CableLabs-Channel-State",
                            "CableLabs-SF-ID",
                            "CableLabs-Error-Description",
                            "CableLabs-QoS-Descriptor",
                            "CableLabs-Direction-indicator",
                            "CableLabs-Time-Adjustment",
                            "CableLabs-SDP-Upstream",
                            "CableLabs-SDP-Downstream",
                            "CableLabs-User-Input",
                            "CableLabs-Translation-Input",
                            "CableLabs-Redirected-From-Info",
                            "CableLabs-Electronic-Surveillance-Ind",
                            "CableLabs-Redirected-From-Party-Number",
                            "CableLabs-Redirected-To-Party-Number",
                            "CableLabs-El-Surveillance-DF-Security",
                            "CableLabs-CCC-ID",
                            "CableLabs-Financial-Entity-ID",
                            "CableLabs-Flow-Direction",
                            "CableLabs-Signal-Type",
                            "CableLabs-Alerting-Signal",
                            "CableLabs-Subject-Audible-Signal",
                            "CableLabs-Terminal-Display-Info",
                            "CableLabs-Switch-Hook-Flash",
                            "CableLabs-Dialed-Digits",
                            "CableLabs-Misc-Signaling-Information",
                            "CableLabs-AM-Opaque-Data",
                            "CableLabs-Subscriber-ID",
                            "CableLabs-Volume-Usage-Limit",
                            "CableLabs-Gate-Usage-Info",
                            "CableLabs-Element-Requesting-QoS",
                            "CableLabs-QoS-Release-Reason",
                            "CableLabs-Policy-Denied-Reason",
                            "CableLabs-Policy-Deleted-Reason",
                            "CableLabs-Policy-Update-Reason",
                            "CableLabs-Policy-Decision-Status",
                            "CableLabs-Application-Manager-ID",
                            "CableLabs-Time-Usage-Limit",
                            "CableLabs-Gate-Time-Info",
                            "CableLabs-Account-Code",
                            "CableLabs-Authorization-Code",
                            "Cabletron-Protocol-Enable",
                            "Cabletron-Protocol-Callable",
                            "Camiant-MI-role",
                            "Camiant-SUI-role",
                            "Camiant-MI-scope",
                            "CP-Gaia-User-Role",
                            "CP-Gaia-SuperUser-Access",
                            "ChilliSpot-Max-Input-Octets",
                            "ChilliSpot-Max-Output-Octets",
                            "ChilliSpot-Max-Total-Octets",
                            "ChilliSpot-Bandwidth-Max-Up",
                            "ChilliSpot-Bandwidth-Max-Down",
                            "ChilliSpot-Config",
                            "ChilliSpot-Lang",
                            "ChilliSpot-Version",
                            "ChilliSpot-OriginalURL",
                            "ChilliSpot-UAM-Allowed",
                            "ChilliSpot-MAC-Allowed",
                            "ChilliSpot-Interval",
                            "Cisco-AVPair",
                            "Cisco-NAS-Port",
                            "Cisco-Fax-Account-Id-Origin",
                            "Cisco-Fax-Msg-Id",
                            "Cisco-Fax-Pages",
                            "Cisco-Fax-Coverpage-Flag",
                            "Cisco-Fax-Modem-Time",
                            "Cisco-Fax-Connect-Speed",
                            "Cisco-Fax-Recipient-Count",
                            "Cisco-Fax-Process-Abort-Flag",
                            "Cisco-Fax-Dsn-Address",
                            "Cisco-Fax-Dsn-Flag",
                            "Cisco-Fax-Mdn-Address",
                            "Cisco-Fax-Mdn-Flag",
                            "Cisco-Fax-Auth-Status",
                            "Cisco-Email-Server-Address",
                            "Cisco-Email-Server-Ack-Flag",
                            "Cisco-Gateway-Id",
                            "Cisco-Call-Type",
                            "Cisco-Port-Used",
                            "Cisco-Abort-Cause",
                            "h323-remote-address",
                            "h323-conf-id",
                            "h323-setup-time",
                            "h323-call-origin",
                            "h323-call-type",
                            "h323-connect-time",
                            "h323-disconnect-time",
                            "h323-disconnect-cause",
                            "h323-voice-quality",
                            "h323-gw-id",
                            "h323-incoming-conf-id",
                            "Cisco-Policy-Up",
                            "Cisco-Policy-Down",
                            "sip-conf-id",
                            "h323-credit-amount",
                            "h323-credit-time",
                            "h323-return-code",
                            "h323-prompt-id",
                            "h323-time-and-day",
                            "h323-redirect-number",
                            "h323-preferred-lang",
                            "h323-redirect-ip-address",
                            "h323-billing-model",
                            "h323-currency",
                            "subscriber",
                            "gw-rxd-cdn",
                            "gw-final-xlated-cdn",
                            "remote-media-address",
                            "release-source",
                            "gw-rxd-cgn",
                            "gw-final-xlated-cgn",
                            "call-id",
                            "session-protocol",
                            "method",
                            "prev-hop-via",
                            "prev-hop-ip",
                            "incoming-req-uri",
                            "outgoing-req-uri",
                            "next-hop-ip",
                            "next-hop-dn",
                            "sip-hdr",
                            "dsp-id",
                            "Cisco-Multilink-ID",
                            "Cisco-Num-In-Multilink",
                            "Cisco-Pre-Input-Octets",
                            "Cisco-Pre-Output-Octets",
                            "Cisco-Pre-Input-Packets",
                            "Cisco-Pre-Output-Packets",
                            "Cisco-Maximum-Time",
                            "Cisco-Disconnect-Cause",
                            "Cisco-Data-Rate",
                            "Cisco-PreSession-Time",
                            "Cisco-PW-Lifetime",
                            "Cisco-IP-Direct",
                            "Cisco-PPP-VJ-Slot-Comp",
                            "Cisco-PPP-Async-Map",
                            "Cisco-IP-Pool-Definition",
                            "Cisco-Assign-IP-Pool",
                            "Cisco-Route-IP",
                            "Cisco-Link-Compression",
                            "Cisco-Target-Util",
                            "Cisco-Maximum-Channels",
                            "Cisco-Data-Filter",
                            "Cisco-Call-Filter",
                            "Cisco-Idle-Limit",
                            "Cisco-Subscriber-Password",
                            "Cisco-Account-Info",
                            "Cisco-Service-Info",
                            "Cisco-Command-Code",
                            "Cisco-Control-Info",
                            "Cisco-Xmit-Rate",
                            "ASA-Simultaneous-Logins",
                            "ASA-Primary-DNS",
                            "ASA-Secondary-DNS",
                            "ASA-Primary-WINS",
                            "ASA-Secondary-WINS",
                            "ASA-SEP-Card-Assignment",
                            "ASA-Tunneling-Protocols",
                            "ASA-IPsec-Sec-Association",
                            "ASA-IPsec-Authentication",
                            "ASA-Banner1",
                            "ASA-IPsec-Allow-Passwd-Store",
                            "ASA-Use-Client-Address",
                            "ASA-PPTP-Encryption",
                            "ASA-L2TP-Encryption",
                            "ASA-Group-Policy",
                            "ASA-IPsec-Split-Tunnel-List",
                            "ASA-IPsec-Default-Domain",
                            "ASA-IPsec-Split-DNS-Names",
                            "ASA-IPsec-Tunnel-Type",
                            "ASA-IPsec-Mode-Config",
                            "ASA-IPsec-Over-UDP",
                            "ASA-IPsec-Over-UDP-Port",
                            "ASA-Banner2",
                            "ASA-PPTP-MPPC-Compression",
                            "ASA-L2TP-MPPC-Compression",
                            "ASA-IPsec-IP-Compression",
                            "ASA-IPsec-IKE-Peer-ID-Check",
                            "ASA-IKE-Keep-Alives",
                            "ASA-IPsec-Auth-On-Rekey",
                            "ASA-Required-Client-Firewall-Vendor-Code",
                            "ASA-Required-Client-Firewall-Product-Code",
                            "ASA-Required-Client-Firewall-Description",
                            "ASA-Require-HW-Client-Auth",
                            "ASA-Required-Individual-User-Auth",
                            "ASA-Authenticated-User-Idle-Timeout",
                            "ASA-Cisco-IP-Phone-Bypass",
                            "ASA-IPsec-Split-Tunneling-Policy",
                            "ASA-IPsec-Required-Client-Firewall-Capability",
                            "ASA-IPsec-Client-Firewall-Filter-Name",
                            "ASA-IPsec-Client-Firewall-Filter-Optional",
                            "ASA-IPsec-Backup-Servers",
                            "ASA-IPsec-Backup-Server-List",
                            "ASA-DHCP-Network-Scope",
                            "ASA-Intercept-DHCP-Configure-Msg",
                            "ASA-MS-Client-Subnet-Mask",
                            "ASA-Allow-Network-Extension-Mode",
                            "ASA-Authorization-Type",
                            "ASA-Authorization-Required",
                            "ASA-Authorization-DN-Field",
                            "ASA-IKE-KeepAlive-Confidence-Interval",
                            "ASA-WebVPN-Content-Filter-Parameters",
                            "ASA-WebVPN-HTML-Filter",
                            "ASA-WebVPN-URL-List",
                            "ASA-WebVPN-Port-Forwarding-List",
                            "ASA-WebVPN-Access-List",
                            "ASA-WebVPNACL",
                            "ASA-WebVPN-HTTP-Proxy-IP-Address",
                            "ASA-Cisco-LEAP-Bypass",
                            "ASA-WebVPN-Default-Homepage",
                            "ASA-Client-Type-Version-Limiting",
"ASA-WebVPN-Group-based-HTTP/HTTPS-Proxy-Exception-List",
                            "ASA-WebVPN-Port-Forwarding-Name",
                            "ASA-IE-Proxy-Server",
                            "ASA-IE-Proxy-Server-Policy",
                            "ASA-IE-Proxy-Exception-List",
                            "ASA-IE-Proxy-Bypass-Local",
                            "ASA-IKE-Keepalive-Retry-Interval",
                            "ASA-Tunnel-Group-Lock",
                            "ASA-Access-List-Inbound",
                            "ASA-Access-List-Outbound",
                            "ASA-Perfect-Forward-Secrecy-Enable",
                            "ASA-NAC-Enable",
                            "ASA-NAC-Status-Query-Timer",
                            "ASA-NAC-Revalidation-Timer",
                            "ASA-NAC-Default-ACL",
                            "ASA-WebVPN-URL-Entry-Enable",
                            "ASA-WebVPN-File-Access-Enable",
                            "ASA-WebVPN-File-Server-Entry-Enable",
                            "ASA-WebVPN-File-Server-Browsing-Enable",
                            "ASA-WebVPN-Port-Forwarding-Enable",
                            "ASA-WebVPN-Port-Forwarding-Exchange-Proxy-Enable",
                            "ASA-WebVPN-Port-Forwarding-HTTP-Proxy",
                            "ASA-WebVPN-Citrix-Metaframe-Enable",
                            "ASA-WebVPN-Apply-ACL",
                            "ASA-WebVPN-SSL-VPN-Client-Enable",
                            "ASA-WebVPN-SSL-VPN-Client-Required",
                            "ASA-WebVPN-SSL-VPN-Client-Keep-Installation",
                            "ASA-SVC-Keepalive",
                            "ASA-WebVPN-SVC-Keepalive-Frequency",
                            "ASA-SVC-DPD-Interval-Client",
                            "ASA-WebVPN-SVC-Client-DPD-Frequency",
                            "ASA-SVC-DPD-Interval-Gateway",
                            "ASA-WebVPN-SVC-Gateway-DPD-Frequency",
                            "ASA-SVC-Rekey-Time",
                            "ASA-WebVPN-SVC-Rekey-Time",
                            "ASA-WebVPN-SVC-Rekey-Method",
                            "ASA-WebVPN-SVC-Compression",
                            "ASA-WebVPN-Customization",
                            "ASA-WebVPN-SSO-Server-Name",
                            "ASA-WebVPN-Deny-Message",
                            "ASA-WebVPN-HTTP-Compression",
                            "ASA-WebVPN-Keepalive-Ignore",
                            "ASA-Extended-Authentication-On-Rekey",
                            "ASA-SVC-DTLS",
                            "ASA-WebVPN-SVC-DTLS-Enable",
                            "ASA-WebVPN-Auto-HTTP-Signon",
                            "ASA-SVC-MTU",
                            "ASA-WebVPN-SVC-DTLS-MTU",
                            "ASA-WebVPN-Hidden-Shares",
                            "ASA-SVC-Modules",
                            "ASA-SVC-Profiles",
                            "ASA-SVC-Ask",
                            "ASA-SVC-Ask-Timeout",
                            "ASA-IE-Proxy-PAC-URL",
                            "ASA-Strip-Realm",
                            "ASA-Smart-Tunnel",
                            "ASA-WebVPN-Smart-Tunnel",
                            "ASA-WebVPN-ActiveX-Relay",
                            "ASA-Smart-Tunnel-Auto",
                            "ASA-WebVPN-Smart-Tunnel-Auto-Start",
                            "ASA-Smart-Tunnel-Auto-Signon-Enable",
                            "ASA-WebVPN-Smart-Tunnel-Auto-Sign-On",
                            "ASA-VLAN",
                            "ASA-NAC-Settings",
                            "ASA-Member-Of",
                            "ASA-TunnelGroupName",
                            "ASA-WebVPN-Idle-Timeout-Alert-Interval",
                            "ASA-WebVPN-Session-Timeout-Alert-Interval",
                            "ASA-ClientType",
                            "ASA-SessionType",
                            "ASA-SessionSubtype",
                            "ASA-WebVPN-Download_Max-Size",
                            "ASA-WebVPN-Upload-Max-Size",
                            "ASA-WebVPN-Post-Max-Size",
                            "ASA-WebVPN-User-Storage",
                            "ASA-WebVPN-Storage-Objects",
                            "ASA-WebVPN-Storage-Key",
                            "ASA-WebVPN-VDI",
                            "ASA-Address-Pools",
                            "ASA-IPv6-Address-Pools",
                            "ASA-IPv6-VPN-Filter",
                            "ASA-Privilege-Level",
                            "ASA-WebVPN-UNIX-User-ID",
                            "ASA-WebVPN-UNIX-Group-ID",
                            "ASA-WebVPN-Macro-Substitution-Value1",
                            "ASA-WebVPN-Macro-Substitution-Value2",
                            "ASA-WebVPNSmart-Card-Removal-Disconnect",
                            "ASA-WebVPN-Smart-Tunnel-Tunnel-Policy",
                            "ASA-WebVPN-Home-Page-Use-Smart-Tunnel",
                            "CVPN5000-Tunnel-Throughput",
                            "CVPN5000-Client-Assigned-IP",
                            "CVPN5000-Client-Real-IP",
                            "CVPN5000-VPN-GroupInfo",
                            "CVPN5000-VPN-Password",
                            "CVPN5000-Echo",
                            "CVPN5000-Client-Assigned-IPX",
                            "CBBSM-Bandwidth",
                            "Citrix-UID",
                            "Citrix-GID",
                            "Citrix-Home",
                            "Citrix-Shell",
                            "Citrix-Group-Names",
                            "Citrix-Group-Ids",
                            "Citrix-User-Groups",
                            "Clavister-User-Group",
                            "BELRAS-Up-Speed-Limit",
                            "BELRAS-Down-Speed-Limit",
                            "BELRAS-Qos-Speed",
                            "BELRAS-User",
                            "BELRAS-DHCP-Router-IP-Address",
                            "BELRAS-DHCP-Mask",
                            "BELRAS-Redirect",
                            "BELRAS-redirect-Pool",
                            "BELRAS-DHCP-Option82",
                            "BELRAS-Session-Octets-Limit",
                            "BELRAS-Octets-Direction",
                            "BELRAS-AKAMAI-Speed",
                            "BELRAS-CACHE-Speed",
                            "BELRAS-CacheFly-Speed",
                            "BELRAS-GGC-Speed",
                            "BELRAS-GOOGLE-Speed",
                            "BELRAS-Incapsula-Speed",
                            "BELRAS-LIMELIGHT-Speed",
                            "BELRAS-OTHERS-Speed",
                            "BELRAS-REDIFF-Speed",
                            "BELRAS-TORRENT-Speed",
                            "BELRAS-BELCACHE-Speed",
                            "BELRAS-DHCP-Lease-Time",
                            "BELRAS-Group",
                            "BELRAS-LIMIT",
                            "BELRAS-Auth",
                            "BELRAS-Acct",
                            "BELRAS-Framed-IP-Address",
                            "BELRAS-BL",
                            "BELRAS-IN",
                            "BELRAS-CO",
                            "Colubris-AVPair",
                            "Colubris-Intercept",
                            "Compatible-Tunnel-Delay",
                            "Compatible-Tunnel-Throughput",
                            "Compatible-Tunnel-Server-Endpoint",
                            "Compatible-Tunnel-Group-Info",
                            "Compatible-Tunnel-Password",
                            "Compatible-Echo",
                            "Compatible-Tunnel-IPX",
                            "Cosine-Connection-Profile-Name",
                            "Cosine-Enterprise-ID",
                            "Cosine-Address-Pool-Name",
                            "Cosine-DS-Byte",
                            "Cosine-VPI-VCI",
                            "Cosine-DLCI",
                            "Cosine-LNS-IP-Address",
                            "Cosine-CLI-User-Permission-ID",
                            "Default-TTL",
                            "DellEMC-AVpair",
                            "DellEMC-Group-Name",
                            "Dlink-User-Level",
                            "Dlink-Ingress-Bandwidth-Assignment",
                            "Dlink-Egress-Bandwidth-Assignment",
                            "Dlink-1p-Priority",
                            "Dlink-VLAN-Name",
                            "Dlink-VLAN-ID",
                            "Dlink-ACL-Profile",
                            "Dlink-ACL-Rule",
                            "Dlink-ACL-Script",
                            "Asterisk-Acc-Code",
                            "Asterisk-Src",
                            "Asterisk-Dst",
                            "Asterisk-Dst-Ctx",
                            "Asterisk-Clid",
                            "Asterisk-Chan",
                            "Asterisk-Dst-Chan",
                            "Asterisk-Last-App",
                            "Asterisk-Last-Data",
                            "Asterisk-Start-Time",
                            "Asterisk-Answer-Time",
                            "Asterisk-End-Time",
                            "Asterisk-Duration",
                            "Asterisk-Bill-Sec",
                            "Asterisk-Disposition",
                            "Asterisk-AMA-Flags",
                            "Asterisk-Unique-ID",
                            "Asterisk-User-Field",
                            "DragonWave-Privilege-Level",
                            "EfficientIP-Version",
                            "EfficientIP-Service-Class",
                            "EfficientIP-Identity-Type",
                            "EfficientIP-First-Name",
                            "EfficientIP-Last-Name",
                            "EfficientIP-Pseudonym",
                            "EfficientIP-IP-Host",
                            "EfficientIP-Email",
                            "EfficientIP-First-Login-Path",
                            "EfficientIP-Maintainer-Group",
                            "EfficientIP-Groups",
                            "EfficientIP-Admin-Group",
                            "EfficientIP-Extra-Blob",
                            "Eltex-AVPair",
                            "Eltex-Disconnect-Code-Local",
                            "Epygi-AVPair",
                            "Epygi-NAS-Port",
                            "Epygi-h323-remote-address",
                            "Epygi-h323-conf-id",
                            "Epygi-h323-setup-time",
                            "Epygi-h323-call-origin",
                            "Epygi-h323-call-type",
                            "Epygi-h323-connect-time",
                            "Epygi-h323-disconnect-time",
                            "Epygi-h323-disconnect-cause",
                            "Epygi-h323-voice-quality",
                            "Epygi-h323-gw-id",
                            "Epygi-h323-incoming-conf-id",
                            "Epygi-h323-credit-amount",
                            "Epygi-h323-credit-time",
                            "Epygi-h323-return-code",
                            "Epygi-h323-prompt-id",
                            "Epygi-h323-time-and-day",
                            "Epygi-h323-redirect-number",
                            "Epygi-h323-preferred-lang",
                            "Epygi-h323-redirect-ip-address",
                            "Epygi-h323-billing-model",
                            "Epygi-h323-currency",
                            "Epygi-RegExpDate",
                            "Epygi-FiadID",
                            "Epygi-PortID",
                            "Epygi-AccessType",
                            "Epygi-CallInfo",
                            "Epygi-OrigCallID",
                            "Epygi-ParentCallID",
                            "Epygi-CallType",
                            "Epygi-DeviceName",
                            "Epygi-InterfaceName",
                            "Epygi-InterfaceNumber",
                            "Epygi-TimeslotNumber",
                            "Epygi-OrigIpAddr",
                            "Epygi-DestIpAddr",
                            "Epygi-OrigIpPort",
                            "Epygi-DestIpPort",
                            "Epygi-CallingPartyNumber",
                            "Epygi-CalledPartyNumber",
                            "Epygi-DateTimeOrigination",
                            "Epygi-DateTimeConnect",
                            "Epygi-DateTimeDisconnect",
                            "Epygi-Duration",
                            "Epygi-OutSourceRTP_IP",
                            "Epygi-OutDestRTP_IP",
                            "Epygi-InSourceRTP_IP",
                            "Epygi-InDestRTP_IP",
                            "Epygi-OutSourceRTP_port",
                            "Epygi-OutDestRTP_port",
                            "Epygi-InSourceRTP_port",
                            "Epygi-InDestRTP_port",
                            "Epygi-CallRedirectReason",
                            "Epygi-CallDisconnectReason",
                            "Epygi-OutRTP_Payload",
                            "Epygi-OutRTP_PacketSize",
                            "Epygi-OutRTP_Packets",
                            "Epygi-OutRTP_Octets",
                            "Epygi-InRTP_Payload",
                            "Epygi-InRTP_PacketSize",
                            "Epygi-InRTP_Packets",
                            "Epygi-InRTP_Octets",
                            "Epygi-InRTP_PacketsLost",
                            "Epygi-InRTP_PacketsDupl",
                            "Epygi-InRTP_Jitter",
                            "Epygi-InRTP_Latency",
                            "ERX-Virtual-Router-Name",
                            "ERX-Address-Pool-Name",
                            "ERX-Local-Loopback-Interface",
                            "ERX-Primary-Dns",
                            "ERX-Secondary-Dns",
                            "ERX-Primary-Wins",
                            "ERX-Secondary-Wins",
                            "ERX-Tunnel-Virtual-Router",
                            "ERX-Tunnel-Password",
                            "ERX-Ingress-Policy-Name",
                            "ERX-Egress-Policy-Name",
                            "ERX-Ingress-Statistics",
                            "ERX-Egress-Statistics",
                            "ERX-Atm-Service-Category",
                            "ERX-Atm-PCR",
                            "ERX-Atm-SCR",
                            "ERX-Atm-MBS",
                            "ERX-Cli-Initial-Access-Level",
                            "ERX-Cli-Allow-All-VR-Access",
                            "ERX-Alternate-Cli-Access-Level",
                            "ERX-Alternate-Cli-Vrouter-Name",
                            "ERX-Sa-Validate",
                            "ERX-Igmp-Enable",
                            "ERX-Pppoe-Description",
                            "ERX-Redirect-VR-Name",
                            "ERX-Qos-Profile-Name",
                            "ERX-Pppoe-Max-Sessions",
                            "ERX-Pppoe-Url",
                            "ERX-Qos-Profile-Interface-Type",
                            "ERX-Tunnel-Nas-Port-Method",
                            "ERX-Service-Bundle",
                            "ERX-Tunnel-Tos",
                            "ERX-Tunnel-Maximum-Sessions",
                            "ERX-Framed-Ip-Route-Tag",
                            "ERX-Dial-Out-Number",
                            "ERX-PPP-Username",
                            "ERX-PPP-Password",
                            "ERX-PPP-Auth-Protocol",
                            "ERX-Minimum-BPS",
                            "ERX-Maximum-BPS",
                            "ERX-Bearer-Type",
                            "ERX-Input-Gigapkts",
                            "ERX-Output-Gigapkts",
                            "ERX-Tunnel-Interface-Id",
                            "ERX-IpV6-Virtual-Router",
                            "ERX-IpV6-Local-Interface",
                            "ERX-Ipv6-Primary-Dns",
                            "ERX-Ipv6-Secondary-Dns",
                            "Sdx-Service-Name",
                            "Sdx-Session-Volume-Quota",
                            "Sdx-Tunnel-Disconnect-Cause-Info",
                            "ERX-Radius-Client-Address",
                            "ERX-Service-Description",
                            "ERX-L2tp-Recv-Window-Size",
                            "ERX-Dhcp-Options",
                            "ERX-Dhcp-Mac-Addr",
                            "ERX-Dhcp-Gi-Address",
                            "ERX-LI-Action",
                            "ERX-Med-Dev-Handle",
                            "ERX-Med-Ip-Address",
                            "ERX-Med-Port-Number",
                            "ERX-MLPPP-Bundle-Name",
                            "ERX-Interface-Desc",
                            "ERX-Tunnel-Group",
                            "ERX-Service-Activate",
                            "ERX-Service-Deactivate",
                            "ERX-Service-Volume",
                            "ERX-Service-Timeout",
                            "ERX-Service-Statistics",
                            "ERX-DF-Bit",
                            "ERX-IGMP-Access-Name",
                            "ERX-IGMP-Access-Src-Name",
                            "ERX-IGMP-OIF-Map-Name",
                            "ERX-MLD-Access-Name",
                            "ERX-MLD-Access-Src-Name",
                            "ERX-MLD-OIF-Map-Name",
                            "ERX-MLD-Version",
                            "ERX-IGMP-Version",
                            "ERX-IP-Mcast-Adm-Bw-Limit",
                            "ERX-IPv6-Mcast-Adm-Bw-Limit",
                            "ERX-Qos-Parameters",
                            "ERX-Service-Session",
                            "ERX-Mobile-IP-Algorithm",
                            "ERX-Mobile-IP-SPI",
                            "ERX-Mobile-IP-Key",
                            "ERX-Mobile-IP-Replay",
                            "ERX-Mobile-IP-Access-Control",
                            "ERX-Mobile-IP-Lifetime",
                            "ERX-L2TP-Resynch-Method",
                            "ERX-Tunnel-Switch-Profile",
                            "ERX-L2c-Up-Stream-Data",
                            "ERX-L2c-Down-Stream-Data",
                            "ERX-Tunnel-Tx-Speed-Method",
                            "ERX-IGMP-Query-Interval",
                            "ERX-IGMP-Max-Resp-Time",
                            "ERX-IGMP-Immediate-Leave",
                            "ERX-MLD-Query-Interval",
                            "ERX-MLD-Max-Resp-Time",
                            "ERX-MLD-Immediate-Leave",
                            "ERX-IP-Block-Multicast",
                            "ERX-IGMP-Explicit-Tracking",
                            "ERX-IGMP-No-Tracking-V2-Grps",
                            "ERX-MLD-Explicit-Tracking",
                            "ERX-MLD-No-Tracking-V1-Grps",
                            "ERX-IPv6-Ingress-Policy-Name",
                            "ERX-IPv6-Egress-Policy-Name",
                            "ERX-CoS-Shaping-Pmt-Type",
                            "ERX-DHCP-Guided-Relay-Server",
                            "ERX-Acc-Loop-Cir-Id",
                            "ERX-Acc-Aggr-Cir-Id-Bin",
                            "ERX-Acc-Aggr-Cir-Id-Asc",
                            "ERX-Act-Data-Rate-Up",
                            "ERX-Act-Data-Rate-Dn",
                            "ERX-Min-Data-Rate-Up",
                            "ERX-Min-Data-Rate-Dn",
                            "ERX-Att-Data-Rate-Up",
                            "ERX-Att-Data-Rate-Dn",
                            "ERX-Max-Data-Rate-Up",
                            "ERX-Max-Data-Rate-Dn",
                            "ERX-Min-LP-Data-Rate-Up",
                            "ERX-Min-LP-Data-Rate-Dn",
                            "ERX-Max-Interlv-Delay-Up",
                            "ERX-Act-Interlv-Delay-Up",
                            "ERX-Max-Interlv-Delay-Dn",
                            "ERX-Act-Interlv-Delay-Dn",
                            "ERX-DSL-Line-State",
                            "ERX-DSL-Type",
                            "ERX-IPv6-NdRa-Prefix",
                            "ERX-Qos-Set-Name",
                            "ERX-Service-Acct-Interval",
                            "ERX-DownStream-Calc-Rate",
                            "ERX-UpStream-Calc-Rate",
                            "ERX-Max-Clients-Per-Interface",
                            "ERX-PPP-Monitor-Ingress-Only",
                            "ERX-CoS-Scheduler-Pmt-Type",
                            "ERX-Backup-Address-Pool",
                            "ERX-ICR-Partition-Id",
                            "ERX-IPv6-Acct-Input-Octets",
                            "ERX-IPv6-Acct-Output-Octets",
                            "ERX-IPv6-Acct-Input-Packets",
                            "ERX-IPv6-Acct-Output-Packets",
                            "ERX-IPv6-Acct-Input-Gigawords",
                            "ERX-IPv6-Acct-Output-Gigawords",
                            "ERX-IPv6-NdRa-Pool-Name",
                            "ERX-PppoE-Padn",
                            "ERX-Dhcp-Option-82",
                            "ERX-Vlan-Map-Id",
                            "ERX-IPv6-Delegated-Pool-Name",
                            "ERX-Tx-Connect-Speed",
                            "ERX-Rx-Connect-Speed",
                            "ERX-Service-Activate-Type",
                            "ERX-Client-Profile-Name",
                            "ERX-Redirect-GW-Address",
                            "ERX-APN-Name",
                            "ERX-Service-Volume-Gigawords",
                            "ERX-Update-Service",
                            "ERX-DHCPv6-Guided-Relay-Server",
                            "ERX-Acc-Loop-Remote-Id",
                            "ERX-Acc-Loop-Encap",
                            "ERX-Inner-Vlan-Map-Id",
                            "ERX-Core-Facing-Interface",
                            "ERX-DHCP-First-Relay-IPv4-Address",
                            "ERX-DHCP-First-Relay-IPv6-Address",
                            "ERX-Input-Interface-Filter",
                            "ERX-Output-Interface-Filter",
                            "ERX-Pim-Enable",
                            "ERX-Bulk-CoA-Transaction-Id",
                            "ERX-Bulk-CoA-Identifier",
                            "ERX-IPv4-Input-Service-Set",
                            "ERX-IPv4-Output-Service-Set",
                            "ERX-IPv4-Input-Service-Filter",
                            "ERX-IPv4-Output-Service-Filter",
                            "ERX-IPv6-Input-Service-Set",
                            "ERX-IPv6-Output-Service-Set",
                            "ERX-IPv6-Input-Service-Filter",
                            "ERX-IPv6-Output-Service-Filter",
                            "ERX-Adv-Pcef-Profile-Name",
                            "ERX-Adv-Pcef-Rule-Name",
                            "ERX-Re-Authentication-Catalyst",
                            "ERX-DHCPv6-Options",
                            "ERX-DHCP-Header",
                            "ERX-DHCPv6-Header",
                            "ERX-Acct-Request-Reason",
                            "Equallogic-Admin-Full-Name",
                            "Equallogic-Admin-Email",
                            "Equallogic-Admin-Phone",
                            "Equallogic-Admin-Mobile",
                            "Equallogic-Poll-Interval",
                            "Equallogic-EQL-Admin-Privilege",
                            "Equallogic-Admin-Pool-Access",
                            "Equallogic-Admin-Repl-Site-Access",
                            "Equallogic-Admin-Account-Type",
                            "Ericsson-ViG-Balance",
                            "Ericsson-ViG-Codec",
                            "Ericsson-ViG-Currency",
                            "Ericsson-ViG-Currency-Quote",
                            "Ericsson-ViG-Endpoint-Type",
                            "Ericsson-ViG-Sequence-Number",
                            "Ericsson-ViG-Access-Agent-IP-Address",
                            "Ericsson-ViG-QoS-Class",
                            "Ericsson-ViG-Digest-Response",
                            "Ericsson-ViG-Digest-Attributes",
                            "Ericsson-ViG-Business-Agreement-Name",
                            "Ericsson-ViG-Call-Role",
                            "Ericsson-ViG-Remote-SK-UA-IP-Address",
                            "Ericsson-ViG-Site",
                            "Ericsson-ViG-TTL-relative",
                            "Ericsson-ViG-Account-error-reason",
                            "Ericsson-ViG-Layer-identity",
                            "Ericsson-ViG-Major-protocol-version",
                            "Ericsson-ViG-Minor-protocol-version",
                            "Ericsson-ViG-Authentication-type",
                            "Ericsson-ViG-Trusted-access",
                            "Ericsson-ViG-User-name",
                            "Ericsson-ViG-Global-unique-call-ID",
                            "Ericsson-ViG-Global-unique-service-ID",
                            "Ericsson-ViG-Interim-interval",
                            "Ericsson-ViG-Alive-Indicator",
                            "Ericsson-ViG-TTL-Absolute",
                            "Ericsson-ViG-TTL-Start-Event",
                            "Ericsson-ViG-SK-IP-address",
                            "Ericsson-ViG-UA-IP-address",
                            "Ericsson-ViG-SA-IP-address",
                            "Ericsson-ViG-Calling-e164-number",
                            "Ericsson-ViG-Calling-H323Id",
                            "Ericsson-ViG-Calling-Email-address",
                            "Ericsson-ViG-Dialled-e164-number",
                            "Ericsson-ViG-Dialled-H323Id",
                            "Ericsson-ViG-Dialled-Email-address",
                            "Ericsson-ViG-Routed-e164-number",
                            "Ericsson-ViG-Routed-H323Id",
                            "Ericsson-ViG-Routed-Email-address",
                            "Ericsson-ViG-SiteKeeper-name",
                            "Ericsson-ViG-Access-Group-name",
                            "Ericsson-ViG-Access-Agent-name",
                            "Ericsson-ViG-User-agent-group-name",
                            "Ericsson-ViG-User-agent-name",
                            "Ericsson-ViG-Routing-tariff",
                            "Ericsson-ViG-Re-selection-counter",
                            "Ericsson-ViG-CPN-digits",
                            "Ericsson-ViG-CPN-TON",
                            "Ericsson-ViG-CPN-NP",
                            "Ericsson-ViG-CPN-PI",
                            "Ericsson-ViG-CPN-SI",
                            "Ericsson-ViG-Dialled-num-digits",
                            "Ericsson-ViG-Dialled-num-TON",
                            "Ericsson-ViG-Dialled-num-NP",
                            "Ericsson-ViG-Routing-num-digits",
                            "Ericsson-ViG-Routing-num-TON",
                            "Ericsson-ViG-Routing-num-NP",
                            "Ericsson-ViG-Redirecting-num-digits",
                            "Ericsson-ViG-Redirecting-num-TON",
                            "Ericsson-ViG-Redirecting-num-NP",
                            "Ericsson-ViG-Redirecting-num-PI",
                            "Ericsson-ViG-Redirecting-num-RFD",
                            "Ericsson-ViG-Time-stamp-UTC",
                            "Ericsson-ViG-Time-stamp-TZ",
                            "Ericsson-ViG-Time-stamp-DST",
                            "Ericsson-ViG-Session-routing-duration",
                            "Ericsson-ViG-Session-ringing-duration",
                            "Ericsson-ViG-Access-type",
                            "Ericsson-ViG-Requested-bandwidth",
                            "Ericsson-ViG-Allowed-bandwidth",
                            "Ericsson-ViG-Media-channel-count",
                            "Ericsson-ViG-Voice-media-rec-forward",
                            "Ericsson-ViG-Voice-media-rec-backward",
                            "Ericsson-ViG-Video-media-rec-forward",
                            "Ericsson-ViG-Video-media-rec-backward",
                            "Ericsson-ViG-Fax-media-rec-forward",
                            "Ericsson-ViG-Fax-media-rec-backward",
                            "Ericsson-ViG-Data-media-rec-forward",
                            "Ericsson-ViG-Data-media-rec-backward",
                            "Ericsson-ViG-Charging-Case",
                            "Ericsson-ViG-Rel-cause-coding-std",
                            "Ericsson-ViG-Rel-cause-location",
                            "Ericsson-ViG-Rel-cause-class",
                            "Ericsson-ViG-Rel-cause-value",
                            "Ericsson-ViG-Rel-reason",
                            "Ericsson-ViG-Internal-Rel-reason-val",
                            "Ericsson-ViG-Internal-Rel-reason-orig",
                            "Ericsson-ViG-Service-ID",
                            "Ericsson-ViG-User-ID",
                            "Ericsson-ViG-Service-Name",
                            "Ericsson-ViG-Test-Call-Indicator",
                            "Ericsson-ViG-Emergency-Call-Indicator",
                            "Ericsson-ViG-Calling-ID",
                            "Ericsson-ViG-Called-ID",
                            "Ericsson-ViG-Translated-ID",
                            "Ericsson-ViG-Calling-User-Group-ID",
                            "Ericsson-ViG-Calling-Usr-Sub-Group-ID",
                            "Ericsson-ViG-Called-Usr-Group-ID",
                            "Ericsson-ViG-Called-Usr-Sub-Group-ID",
                            "Ericsson-ViG-Terminal-Type",
                            "Ericsson-ViG-Service-Duration",
                            "Ericsson-ViG-Service-Execution-Result",
                            "Ericsson-ViG-Service-Exe-Rslt-Desc",
                            "Ericsson-ViG-Service-Description",
                            "Ericsson-ViG-Service-Specific-Info",
                            "Ericsson-ViG-Proxy-IP-Address",
                            "Ericsson-ViG-Auth-DataRequest",
                            "Ericsson-ViG-IPT-Time-Stamp",
                            "Ericsson-ViG-User-Name-Info",
                            "Client-DNS-Pri",
                            "Client-DNS-Sec",
                            "DHCP-Max-Leases",
                            "Context-Name",
                            "Bridge-Group",
                            "BG-Aging-Time",
                            "BG-Path-Cost",
                            "BG-Span-Dis",
                            "BG-Trans-BPDU",
                            "Rate-Limit-Rate",
                            "Rate-Limit-Burst",
                            "Police-Rate",
                            "Police-Burst",
                            "Source-Validation",
                            "Tunnel-Domain",
                            "Tunnel-Local-Name",
                            "Tunnel-Remote-Name",
                            "Tunnel-Function",
                            "Tunnel-Flow-Control",
                            "Tunnel-Static",
                            "Tunnel-Max-Sessions",
                            "Tunnel-Max-Tunnels",
                            "Tunnel-Session-Auth",
                            "Tunnel-Window",
                            "Tunnel-Retransmit",
                            "Tunnel-Cmd-Timeout",
                            "PPPOE-URL",
                            "PPPOE-MOTM",
                            "Tunnel-Group",
                            "Tunnel-Context",
                            "Tunnel-Algorithm",
                            "Tunnel-Deadtime",
                            "Mcast-Send",
                            "Mcast-Receive",
                            "Mcast-MaxGroups",
                            "Ip-Address-Pool-Name",
                            "Tunnel-DNIS",
                            "Medium-Type",
                            "PVC-Encapsulation-Type",
                            "PVC-Profile-Name",
                            "PVC-Circuit-Padding",
                            "Bind-Type",
                            "Bind-Auth-Protocol",
                            "Bind-Auth-Max-Sessions",
                            "Bind-Bypass-Bypass",
                            "Bind-Auth-Context",
                            "Bind-Auth-Service-Grp",
                            "Bind-Bypass-Context",
                            "Bind-Int-Context",
                            "Bind-Tun-Context",
                            "Bind-Ses-Context",
                            "Bind-Dot1q-Slot",
                            "Bind-Dot1q-Port",
                            "Bind-Dot1q-Vlan-Tag-Id",
                            "Bind-Int-Interface-Name",
                            "Bind-L2TP-Tunnel-Name",
                            "Bind-L2TP-Flow-Control",
                            "Bind-Sub-User-At-Context",
                            "Bind-Sub-Password",
                            "Ip-Host-Addr",
                            "IP-TOS-Field",
                            "NAS-Real-Port",
                            "Tunnel-Session-Auth-Ctx",
                            "Tunnel-Session-Auth-Service-Grp",
                            "Tunnel-Rate-Limit-Rate",
                            "Tunnel-Rate-Limit-Burst",
                            "Tunnel-Police-Rate",
                            "Tunnel-Police-Burst",
                            "Tunnel-L2F-Second-Password",
                            "ACL-Definition",
                            "PPPoE-IP-Route-Add",
                            "TTY-Level-Max",
                            "TTY-Level-Start",
                            "Tunnel-Checksum",
                            "Tunnel-Profile",
                            "Tunnel-Client-VPN",
                            "Tunnel-Server-VPN",
                            "Tunnel-Client-Rhost",
                            "Tunnel-Server-Rhost",
                            "Tunnel-Client-Int-Addr",
                            "Tunnel-Server-Int-Addr",
                            "PPP-Compression",
                            "Tunnel-Hello-Timer",
                            "Redback-Reason",
                            "Qos-Policing-Profile-Name",
                            "Qos-Metering-Profile-Name",
                            "Qos-Policy-Queuing",
                            "IGMP-Service-Profile-Name",
                            "Subscriber-Profile-Name",
                            "Forward-Policy",
                            "Remote-Port",
                            "Reauth",
                            "Reauth-More",
                            "Agent-Remote-Id",
                            "Agent-Circuit-Id",
                            "Platform-Type",
                            "Client-NBNS-Pri",
                            "Client-NBNS-Sec",
                            "Shaping-Profile-Name",
                            "BG-Cct-Addr-Max",
                            "IP-Interface-Name",
                            "NAT-Policy-Name",
                            "RB-NPM-Service-Id",
                            "HTTP-Redirect-Profile-Name",
                            "Bind-Auto-Sub-User",
                            "Bind-Auto-Sub-Context",
                            "Bind-Auto-Sub-Password",
                            "Circuit-Protocol-Encap",
                            "OS-Version",
                            "Session-Traffic-Limit",
                            "QOS-Reference",
                            "Rate-Limit-Excess-Burst",
                            "Police-Excess-Burst",
                            "Tunnel-Rate-Limit-Excess-Burst",
                            "Tunnel-Police-Excess-Burst",
                            "DHCP-Vendor-Class-ID",
                            "Qos-Rate",
                            "DHCP-Vendor-Encap-Option",
                            "Acct-Input-Octets-64",
                            "Acct-Output-Octets-64",
                            "Acct-Input-Packets-64",
                            "Acct-Output-Packets-64",
                            "Assigned-IP-Address",
                            "Acct-Mcast-In-Octets-64",
                            "Acct-Mcast-Out-Octets-64",
                            "Acct-Mcast-In-Packets-64",
                            "Acct-Mcast-Out-Packets-64",
                            "LAC-Port",
                            "LAC-Real-Port",
                            "LAC-Port-Type",
                            "LAC-Real-Port-Type",
                            "Acct-Dyn-Ac-Ent",
                            "Session-Error-Code",
                            "Session-Error-Msg",
                            "Acct-Update-Reason",
                            "Mac-Addr",
                            "Vlan-Source-Info",
                            "Acct-Mcast-In-Octets",
                            "Acct-Mcast-Out-Octets",
                            "Acct-Mcast-In-Packets",
                            "Acct-Mcast-Out-Packets",
                            "Reauth-Session-Id",
                            "QOS-Rate-Inbound",
                            "QOS-Rate-Outbound",
                            "Route-Tag",
                            "LI-Id",
                            "LI-Md-Address",
                            "LI-Md-Port",
                            "LI-Action",
                            "LI-Profile",
                            "Dynamic-Policy-Filter",
                            "HTTP-Redirect-URL",
                            "DSL-Actual-Rate-Up",
                            "DSL-Actual-Rate-Down",
                            "DSL-Min-Rate-Up",
                            "DSL-Min-Rate-Down",
                            "DSL-Attainable-Rate-Up",
                            "DSL-Attainable-Rate-Down",
                            "DSL-Max-Rate-Up",
                            "DSL-Max-Rate-Down",
                            "DSL-Min-Low-Power-Rate-Up",
                            "DSL-Min-Low-Power-Rate-Down",
                            "DSL-Max-Inter-Delay-Up",
                            "DSL-Actual-Inter-Delay-Up",
                            "DSL-Max-Inter-Delay-Down",
                            "DSL-Actual-Inter-Delay-Down",
                            "DSL-Line-State",
                            "DSL-L2-Encapsulation",
                            "DSL-Transmission-System",
                            "DSL-PPPOA-PPPOE-Inter-Work-Flag",
                            "DSL-Actual-Rate-Down-Factor",
                            "DSL-Combined-Line-Info",
                            "Class-Volume-limit",
                            "Class-Volume-In-Counter",
                            "Class-Volume-Out-Counter",
                            "Flow-FAC-Profile",
                            "Service-Name",
                            "Service-Action",
                            "Service-Parameter",
                            "Service-Error-Cause",
                            "Deactivate-Service-Name",
                            "Qos-Profile-Overhead",
                            "Dynamic-QoS-Param",
                            "Acct-Alt-Session-ID",
                            "Idle-Timeout-Threshold",
                            "Double-Authentication",
                            "SBC-Adjacency",
                            "DHCP-Field",
                            "DHCP-Option",
                            "Security-Service",
                            "Reauth-Service-Name",
                            "Flow-IP-Profile",
                            "Radius-Throttle-Watermark",
                            "RB-IPV6-DNS",
                            "RB-IPv6-Option",
                            "Cluster-Partition-ID",
                            "Circuit-Group-Member",
                            "Delegated-Max-Prefix",
                            "IPv4-Address-Release-Control",
                            "Acct-Input-IPv4-Octets",
                            "Acct-Output-IPv4-Octets",
                            "Acct-Input-IPv4-Packets",
                            "Acct-Output-IPv4-Packets",
                            "Acct-Input-IPv4-Gigawords",
                            "Acct-Output-IPv4-Gigawords",
                            "Acct-Input-IPv6-Octets",
                            "Acct-Output-IPv6-Octets",
                            "Acct-Input-IPv6-Packets",
                            "Acct-Output-IPv6-Packets",
                            "Acct-Input-IPv6-Gigawords",
                            "Acct-Output-IPv6-Gigawords",
                            "Suggested-Rule-Space",
                            "Suggested-Secondary-Rule-Space",
                            "Extreme-CLI-Authorization",
                            "Extreme-Shell-Command",
                            "Extreme-Netlogin-Vlan",
                            "Extreme-Netlogin-Url",
                            "Extreme-Netlogin-Url-Desc",
                            "Extreme-Netlogin-Only",
                            "Extreme-User-Location",
                            "Extreme-Netlogin-Vlan-Tag",
                            "Extreme-Netlogin-Extended-Vlan",
                            "Extreme-Security-Profile",
                            "Extreme-VM-Name",
                            "Extreme-VM-VPP-Name",
                            "Extreme-VM-IP-Addr",
                            "Extreme-VM-VLAN-ID",
                            "Extreme-VM-VR-Name",
                            "F5-LTM-User-Role",
                            "F5-LTM-User-Role-Universal",
                            "F5-LTM-User-Partition",
                            "F5-LTM-User-Console",
                            "F5-LTM-User-Shell",
                            "F5-LTM-User-Context-1",
                            "F5-LTM-User-Context-2",
                            "F5-LTM-User-Info-1",
                            "F5-LTM-User-Info-2",
                            "F5-LTM-Audit-Msg",
                            "fdXtended-Bandwidth-Up",
                            "fdXtended-Bandwidth-Down",
                            "fdXtended-PostAuthURL",
                            "fdXtended-One2onenat-IP",
                            "fdXtended-ContentFilter",
                            "fdXtended-NetworkPolicy",
                            "fdXtended-BytesDown",
                            "fdXtended-BytesUp",
                            "fdXtended-Expiration",
                            "fdXtended-SessionTimeout",
                            "fdXtended-Wan-Interface",
                            "FreeRADIUS-Proxied-To",
                            "FreeRADIUS-Acct-Session-Start-Time",
                            "FreeRADIUS-Statistics-Type",
                            "FreeRADIUS-Total-Access-Requests",
                            "FreeRADIUS-Total-Access-Accepts",
                            "FreeRADIUS-Total-Access-Rejects",
                            "FreeRADIUS-Total-Access-Challenges",
                            "FreeRADIUS-Total-Auth-Responses",
                            "FreeRADIUS-Total-Auth-Duplicate-Requests",
                            "FreeRADIUS-Total-Auth-Malformed-Requests",
                            "FreeRADIUS-Total-Auth-Invalid-Requests",
                            "FreeRADIUS-Total-Auth-Dropped-Requests",
                            "FreeRADIUS-Total-Auth-Unknown-Types",
                            "FreeRADIUS-Total-Proxy-Access-Requests",
                            "FreeRADIUS-Total-Proxy-Access-Accepts",
                            "FreeRADIUS-Total-Proxy-Access-Rejects",
                            "FreeRADIUS-Total-Proxy-Access-Challenges",
                            "FreeRADIUS-Total-Proxy-Auth-Responses",
                            "FreeRADIUS-Total-Proxy-Auth-Duplicate-Requests",
                            "FreeRADIUS-Total-Proxy-Auth-Malformed-Requests",
                            "FreeRADIUS-Total-Proxy-Auth-Invalid-Requests",
                            "FreeRADIUS-Total-Proxy-Auth-Dropped-Requests",
                            "FreeRADIUS-Total-Proxy-Auth-Unknown-Types",
                            "FreeRADIUS-Total-Accounting-Requests",
                            "FreeRADIUS-Total-Accounting-Responses",
                            "FreeRADIUS-Total-Acct-Duplicate-Requests",
                            "FreeRADIUS-Total-Acct-Malformed-Requests",
                            "FreeRADIUS-Total-Acct-Invalid-Requests",
                            "FreeRADIUS-Total-Acct-Dropped-Requests",
                            "FreeRADIUS-Total-Acct-Unknown-Types",
                            "FreeRADIUS-Total-Proxy-Accounting-Requests",
                            "FreeRADIUS-Total-Proxy-Accounting-Responses",
                            "FreeRADIUS-Total-Proxy-Acct-Duplicate-Requests",
                            "FreeRADIUS-Total-Proxy-Acct-Malformed-Requests",
                            "FreeRADIUS-Total-Proxy-Acct-Invalid-Requests",
                            "FreeRADIUS-Total-Proxy-Acct-Dropped-Requests",
                            "FreeRADIUS-Total-Proxy-Acct-Unknown-Types",
                            "FreeRADIUS-Queue-Len-Internal",
                            "FreeRADIUS-Queue-Len-Proxy",
                            "FreeRADIUS-Queue-Len-Auth",
                            "FreeRADIUS-Queue-Len-Acct",
                            "FreeRADIUS-Queue-Len-Detail",
                            "FreeRADIUS-Stats-Client-IP-Address",
                            "FreeRADIUS-Stats-Client-Number",
                            "FreeRADIUS-Stats-Client-Netmask",
                            "FreeRADIUS-Stats-Server-IP-Address",
                            "FreeRADIUS-Stats-Server-Port",
                            "FreeRADIUS-Stats-Server-Outstanding-Requests",
                            "FreeRADIUS-Stats-Server-State",
                            "FreeRADIUS-Stats-Server-Time-Of-Death",
                            "FreeRADIUS-Stats-Server-Time-Of-Life",
                            "FreeRADIUS-Stats-Start-Time",
                            "FreeRADIUS-Stats-HUP-Time",
                            "FreeRADIUS-Server-EMA-Window",
                            "FreeRADIUS-Server-EMA-USEC-Window-1",
                            "FreeRADIUS-Server-EMA-USEC-Window-10",
                            "FreeRADIUS-Queue-PPS-In",
                            "FreeRADIUS-Queue-PPS-Out",
                            "FreeRADIUS-Queue-Use-Percentage",
                            "FreeRADIUS-Stats-Last-Packet-Recv",
                            "FreeRADIUS-Stats-Last-Packet-Sent",
                            "FreeRADIUS-EAP-FAST-TLV",
                            "FreeRADIUS-EAP-FAST-Result",
                            "FreeRADIUS-EAP-FAST-NAK",
                            "FreeRADIUS-EAP-FAST-Error",
                            "FreeRADIUS-EAP-FAST-Vendor-Specific",
                            "FreeRADIUS-EAP-FAST-EAP-Payload",
                            "FreeRADIUS-EAP-FAST-Intermediate-Result",
                            "FreeRADIUS-EAP-FAST-PAC",
                            "FreeRADIUS-EAP-FAST-PAC-Key",
                            "FreeRADIUS-EAP-FAST-PAC-Opaque-TLV",
                            "FreeRADIUS-EAP-FAST-PAC-Opaque-PAC-Key",
                            "FreeRADIUS-EAP-FAST-PAC-Opaque-PAC-Lifetime",
                            "FreeRADIUS-EAP-FAST-PAC-Opaque-I-ID",
                            "FreeRADIUS-EAP-FAST-PAC-Opaque-PAC-Type",
                            "FreeRADIUS-EAP-FAST-PAC-Lifetime",
                            "FreeRADIUS-EAP-FAST-PAC-A-ID",
                            "FreeRADIUS-EAP-FAST-PAC-I-ID",
                            "FreeRADIUS-EAP-FAST-PAC-A-ID-Info",
                            "FreeRADIUS-EAP-FAST-PAC-Acknowledge",
                            "FreeRADIUS-EAP-FAST-PAC-Info-TLV",
                            "FreeRADIUS-EAP-FAST-PAC-Info-PAC-Lifetime",
                            "FreeRADIUS-EAP-FAST-PAC-Info-A-ID",
                            "FreeRADIUS-EAP-FAST-PAC-Info-I-ID",
                            "FreeRADIUS-EAP-FAST-PAC-Info-A-ID-Info",
                            "FreeRADIUS-EAP-FAST-PAC-Info-PAC-Type",
                            "FreeRADIUS-EAP-FAST-PAC-Type",
                            "FreeRADIUS-EAP-FAST-Crypto-Binding",
                            "FreeRADIUS-EAP-FAST-Trusted-Root",
                            "FreeRADIUS-EAP-FAST-Request-Action",
                            "FreeRADIUS-EAP-FAST-PKCS",
                            "FreeRADIUS-Stats-Error",
                            "Freeswitch-AVPair",
                            "Freeswitch-CLID",
                            "Freeswitch-Dialplan",
                            "Freeswitch-Src",
                            "Freeswitch-Dst",
                            "Freeswitch-Src-Channel",
                            "Freeswitch-Dst-Channel",
                            "Freeswitch-Ani",
                            "Freeswitch-Aniii",
                            "Freeswitch-Lastapp",
                            "Freeswitch-Lastdata",
                            "Freeswitch-Disposition",
                            "Freeswitch-Hangupcause",
                            "Freeswitch-Billusec",
                            "Freeswitch-AMAFlags",
                            "Freeswitch-RDNIS",
                            "Freeswitch-Context",
                            "Freeswitch-Source",
                            "Freeswitch-Callstartdate",
                            "Freeswitch-Callanswerdate",
                            "Freeswitch-Calltransferdate",
                            "Freeswitch-Callenddate",
                            "Freeswitch-Signalbond",
                            "Fortinet-Group-Name",
                            "Fortinet-Client-IP-Address",
                            "Fortinet-Vdom-Name",
                            "Fortinet-Client-IPv6-Address",
                            "Fortinet-Interface-Name",
                            "Fortinet-Access-Profile",
                            "Foundry-Privilege-Level",
                            "Foundry-Command-String",
                            "Foundry-Command-Exception-Flag",
                            "Foundry-INM-Privilege",
                            "Foundry-Access-List",
                            "Foundry-MAC-Authent-needs-802.1x",
                            "Foundry-802.1x-Valid-Lookup",
                            "Foundry-MAC-Based-Vlan-QoS",
                            "Foundry-INM-Role-Aor-List",
                            "Foundry-SI-Context-Role",
                            "Foundry-SI-Role-Template",
                            "Gandalf-Remote-LAN-Name",
                            "Gandalf-Operational-Modes",
                            "Gandalf-Compression-Status",
                            "Gandalf-Min-Outgoing-Bearer",
                            "Gandalf-Authentication-String",
                            "Gandalf-PPP-Authentication",
                            "Gandalf-PPP-NCP-Type",
                            "Gandalf-Fwd-Multicast-In",
                            "Gandalf-Fwd-Broadcast-In",
                            "Gandalf-Fwd-Unicast-In",
                            "Gandalf-Fwd-Multicast-Out",
                            "Gandalf-Fwd-Broadcast-Out",
                            "Gandalf-Fwd-Unicast-Out",
                            "Gandalf-Around-The-Corner",
                            "Gandalf-Channel-Group-Name-1",
                            "Gandalf-Dial-Prefix-Name-1",
                            "Gandalf-Phone-Number-1",
                            "Gandalf-Calling-Line-ID-1",
                            "Gandalf-Channel-Group-Name-2",
                            "Gandalf-Dial-Prefix-Name-2",
                            "Gandalf-Phone-Number-2",
                            "Gandalf-Calling-Line-ID-2",
                            "Gandalf-IPX-Spoofing-State",
                            "Gandalf-IPX-Watchdog-Spoof",
                            "Gandalf-SAP-Group-Name-1",
                            "Gandalf-SAP-Group-Name-2",
                            "Gandalf-SAP-Group-Name-3",
                            "Gandalf-SAP-Group-Name-4",
                            "Gandalf-SAP-Group-Name-5",
                            "Gandalf-Hunt-Group",
                            "Gandalf-Modem-Mode",
                            "Gandalf-Modem-Required-1",
                            "Gandalf-Modem-Required-2",
                            "Acct-Session-Input-Octets",
                            "Acct-Session-Input-Gigawords",
                            "Acct-Session-Output-Octets",
                            "Acct-Session-Output-Gigawords",
                            "Acct-Session-Octets",
                            "Acct-Session-Gigawords",
                            "H3C-Input-Peak-Rate",
                            "H3C-Input-Average-Rate",
                            "H3C-Input-Basic-Rate",
                            "H3C-Remanent-Volume",
                            "H3C-Command",
                            "H3C-Control-Identifier",
                            "H3C-Result-Code",
                            "H3C-Connect_Id",
                            "H3C-Ftp-Directory",
                            "H3C-Exec-Privilege",
                            "H3C-NAS-Startup-Timestamp",
                            "H3C-Ip-Host-Addr",
                            "H3C-User-Notify",
                            "H3C-User-HeartBeat",
                            "H3C-User-Group",
                            "H3C-Security-Level",
                            "H3C-Input-Interval-Octets",
                            "H3C-Output-Interval-Octets",
                            "H3C-Input-Interval-Packets",
                            "H3C-Output-Interval-Packets",
                            "H3C-Input-Interval-Gigawords",
                            "H3C-Output-Interval-Gigawords",
                            "H3C-Backup-NAS-IP",
                            "H3C-Product-ID",
                            "Hillstone-User-vsys-id",
                            "Hillstone-User-Type",
                            "Hillstone-User-Admin-Privilege",
                            "Hillstone-User-Login-Type",
                            "Hillstone-User-Mobile-Number",
                            "Hillstone-User-Mobile-Operator",
                            "Hillstone-User-Policy-dst-ip-begin",
                            "Hillstone-User-Policy-dst-ip-end",
                            "Hillstone-User-Role-Bame",
                            "Hillstone-VPN-DHCP-Gateway",
                            "Hillstone-VPN-DHCP-Mask",
                            "Hillstone-VPN-DHCP-Pool",
                            "Hillstone-VPN-WINS",
                            "Hillstone-VPN-DNS",
                            "Hillstone-VPN-Split-Route",
                            "Hillstone-VPN-Tunnel-IP",
                            "Hillstone-VPN-SNAT",
                            "HP-Privilege-Level",
                            "HP-Command-String",
                            "HP-Command-Exception",
                            "HP-Management-Protocol",
                            "HP-Port-Client-Limit-Dot1x",
                            "HP-Port-Client-Limit-MA",
                            "HP-Port-Client-Limit-WA",
                            "HP-Port-Auth-Mode-Dot1x",
                            "HP-Port-Bounce-Host",
                            "HP-Captive-Portal-URL",
                            "HP-Port-Priority-Regeneration-Table",
                            "HP-Cos",
                            "HP-Bandwidth-Max-Ingress",
                            "HP-Bandwidth-Max-Egress",
                            "HP-Ip-Filter-Raw",
                            "HP-Nas-Filter-Rule",
                            "HP-Nas-Rules-IPv6",
                            "HP-Egress-VLANID",
                            "HP-Egress-VLAN-Name",
                            "HP-VC-groups",
                            "HP-Capability-Advert",
                            "Huawei-Input-Burst-Size",
                            "Huawei-Input-Average-Rate",
                            "Huawei-Input-Peak-Rate",
                            "Huawei-Output-Burst-Size",
                            "Huawei-Output-Average-Rate",
                            "Huawei-Output-Peak-Rate",
                            "Huawei-In-Kb-Before-T-Switch",
                            "Huawei-Out-Kb-Before-T-Switch",
                            "Huawei-In-Pkt-Before-T-Switch",
                            "Huawei-Out-Pkt-Before-T-Switch",
                            "Huawei-In-Kb-After-T-Switch",
                            "Huawei-Out-Kb-After-T-Switch",
                            "Huawei-In-Pkt-After-T-Switch",
                            "Huawei-Out-Pkt-After-T-Switch",
                            "Huawei-Remanent-Volume",
                            "Huawei-Tariff-Switch-Interval",
                            "Huawei-ISP-ID",
                            "Huawei-Max-Users-Per-Logic-Port",
                            "Huawei-Command",
                            "Huawei-Priority",
                            "Huawei-Control-Identifier",
                            "Huawei-Result-Code",
                            "Huawei-Connect-ID",
                            "Huawei-PortalURL",
                            "Huawei-FTP-Directory",
                            "Huawei-Exec-Privilege",
                            "Huawei-IP-Address",
                            "Huawei-Qos-Profile-Name",
                            "Huawei-SIP-Server",
                            "Huawei-User-Password",
                            "Huawei-Command-Mode",
                            "Huawei-Renewal-Time",
                            "Huawei-Rebinding-Time",
                            "Huawei-IGMP-Enable",
                            "Huawei-Destnation-IP-Addr",
                            "Huawei-Destnation-Volume",
                            "Huawei-Startup-Stamp",
                            "Huawei-IPHost-Addr",
                            "Huawei-Up-Priority",
                            "Huawei-Down-Priority",
                            "Huawei-Tunnel-VPN-Instance",
                            "Huawei-VT-Name",
                            "Huawei-User-Date",
                            "Huawei-User-Class",
                            "Huawei-PPP-NCP-Type",
                            "Huawei-VSI-Name",
                            "Huawei-Subnet-Mask",
                            "Huawei-Gateway-Address",
                            "Huawei-Lease-Time",
                            "Huawei-Primary-WINS",
                            "Huawei-Secondary-WINS",
                            "Huawei-Input-Peak-Burst-Size",
                            "Huawei-Output-Peak-Burst-Size",
                            "Huawei-Reduced-CIR",
                            "Huawei-Tunnel-Session-Limit",
                            "Huawei-Zone-Name",
                            "Huawei-Data-Filter",
                            "Huawei-Access-Service",
                            "Huawei-Accounting-Level",
                            "Huawei-Portal-Mode",
                            "Huawei-DPI-Policy-Name",
                            "huawei-Policy-Route",
                            "Huawei-Framed-Pool",
                            "Huawei-L2TP-Terminate-Cause",
                            "Huawei-Multi-Account-Mode",
                            "Huawei-Queue-Profile",
                            "Huawei-Layer4-Session-Limit",
                            "Huawei-Multicast-Profile",
                            "Huawei-VPN-Instance",
                            "Huawei-Policy-Name",
                            "Huawei-Tunnel-Group-Name",
                            "Huawei-Multicast-Source-Group",
                            "Huawei-Multicast-Receive-Group",
                            "Huawei-User-Multicast-Type",
                            "Huawei-Reduced-PIR",
                            "Huawei-LI-ID",
                            "Huawei-LI-Md-Address",
                            "Huawei-LI-Md-Port",
                            "Huawei-LI-Md-VpnInstance",
                            "Huawei-Service-Chg-Cmd",
                            "Huawei-Acct-Packet-Type",
                            "Huawei-Call-Reference",
                            "Huawei-PSTN-Port",
                            "Huawei-Voip-Service-Type",
                            "Huawei-Acct-Connection-Time",
                            "Huawei-Error-Reason",
                            "Huawei-Remain-Monney",
                            "Huawei-Org-GK-ipaddr",
                            "Huawei-Org-GW-ipaddr",
                            "Huawei-Dst-GK-ipaddr",
                            "Huawei-Dst-GW-ipaddr",
                            "Huawei-Access-Num",
                            "Huawei-Remain-Time",
                            "Huawei-Codec-Type",
                            "Huawei-Transfer-Num",
                            "Huawei-New-User-Name",
                            "Huawei-Transfer-Station-Id",
                            "Huawei-Primary-DNS",
                            "Huawei-Secondary-DNS",
                            "Huawei-ONLY-Account-Type",
                            "Huawei-Domain-Name",
                            "Huawei-ANCP-Profile",
                            "Huawei-HTTP-Redirect-URL",
                            "Huawei-Loopback-Address",
                            "Huawei-QoS-Profile-Type",
                            "Huawei-Max-List-Num",
                            "Huawei-Acct-IPv6-Input-Octets",
                            "Huawei-Acct-IPv6-Output-Octets",
                            "Huawei-Acct-IPv6-Input-Packets",
                            "Huawei-Acct-IPv6-Output-Packets",
                            "Huawei-Acct-IPv6-Input-Gigawords",
                            "Huawei-Acct-IPv6-Output-Gigawords",
                            "Huawei-DHCPv6-Option37",
                            "Huawei-DHCPv6-Option38",
                            "Huawei-User-Mac",
                            "Huawei-DNS-Server-IPv6-address",
                            "Huawei-DHCPv4-Option121",
                            "Huawei-DHCPv4-Option43",
                            "Huawei-Framed-Pool-Group",
                            "Huawei-Framed-IPv6-Address",
                            "Huawei-Acct-Update-Address",
                            "Huawei-NAT-Policy-Name",
                            "Huawei-NAT-Public-Address",
                            "Huawei-NAT-Start-Port",
                            "Huawei-NAT-End-Port",
                            "Huawei-NAT-Port-Forwarding",
                            "Huawei-NAT-Port-Range-Update",
                            "Huawei-DS-Lite-Tunnel-Name",
                            "Huawei-PCP-Server-Name",
                            "Huawei-Public-IP-Addr-State",
                            "Huawei-Auth-Type",
                            "Huawei-Acct-Terminate-Subcause",
                            "Huawei-Down-QOS-Profile-Name",
                            "Huawei-Port-Mirror",
                            "Huawei-Account-Info",
                            "Huawei-Service-Info",
                            "Huawei-DHCP-Option",
                            "Huawei-AVpair",
                            "Huawei-Delegated-IPv6-Prefix-Pool",
                            "Huawei-IPv6-Prefix-Lease",
                            "Huawei-IPv6-Address-Lease",
                            "Huawei-IPv6-Policy-Route",
                            "Huawei-MNG-IPv6",
                            "Huawei-Flow-Info",
                            "Huawei-Flow-Id",
                            "Huawei-DHCP-Server-IP",
                            "Huawei-Application-Type",
                            "Huawei-Indication-Flag",
                            "Huawei-Original_NAS-IP_Address",
                            "Huawei-User-Priority",
                            "Huawei-ACS-Url",
                            "Huawei-Provision-Code",
                            "Huawei-Application-Scene",
                            "Huawei-MS-Maximum-MAC-Study-Number",
                            "Huawei-GGSN-Vendor",
                            "Huawei-GGSN-Version",
                            "Huawei-Web-URL",
                            "Huawei-Version",
                            "Huawei-Product-ID",
                            "AM-Interrupt-HTMLFile",
                            "AM-Interrupt-Interval",
                            "AM-Interrupt-Timeout",
                            "AM-Status-HTMLFile",
                            "AM-HTTP-Proxy-Port",
                            "Infinera-User-Category",
                            "Infinera-ENM-User-Category",
                            "Infonet-Proxy",
                            "Infonet-Config",
                            "Infonet-MCS-Country",
                            "Infonet-MCS-Region",
                            "Infonet-MCS-Off-Peak",
                            "Infonet-MCS-Overflow",
                            "Infonet-MCS-Port",
                            "Infonet-MCS-Port-Count",
                            "Infonet-Account-Number",
                            "Infonet-Type",
                            "Infonet-Pool-Request",
                            "Infonet-Surcharge-Type",
                            "Infonet-NAS-Location",
                            "Infonet-Random-IP-Pool",
                            "Infonet-Realm-Type",
                            "Infonet-LoginHost-Dest",
                            "Infonet-Tunnel-Decision-IP",
                            "Issanni-SoftFlow-Template",
                            "Issanni-NAT-Support",
                            "Issanni-Routing-Context",
                            "Issanni-Tunnel-Name",
                            "Issanni-IP-Pool-Name",
                            "Issanni-PPPoE-URL",
                            "Issanni-PPPoE-MOTM",
                            "Issanni-Service",
                            "Issanni-Pri-DNS",
                            "Issanni-Sec-DNS",
                            "Issanni-Pri-NBNS",
                            "Issanni-Sec-NBNS",
                            "Issanni-Traffic-Class",
                            "Issanni-Tunnel-Type",
                            "Issanni-NAT-Type",
                            "Issanni-QOS-Class",
                            "Issanni-Interface-Name",
                            "ITK-Auth-Serv-IP",
                            "ITK-Auth-Serv-Prot",
                            "ITK-Provider-Id",
                            "ITK-Usergroup",
                            "ITK-Banner",
                            "ITK-Username-Prompt",
                            "ITK-Password-Prompt",
                            "ITK-Welcome-Message",
                            "ITK-Prompt",
                            "ITK-IP-Pool",
                            "ITK-Tunnel-IP",
                            "ITK-Tunnel-Prot",
                            "ITK-Acct-Serv-IP",
                            "ITK-Acct-Serv-Prot",
                            "ITK-Filter-Rule",
                            "ITK-Channel-Binding",
                            "ITK-Start-Delay",
                            "ITK-NAS-Name",
                            "ITK-ISDN-Prot",
                            "ITK-PPP-Auth-Type",
                            "ITK-Dialout-Type",
                            "ITK-Ftp-Auth-IP",
                            "ITK-Users-Default-Entry",
                            "ITK-Users-Default-Pw",
                            "ITK-Auth-Req-Type",
                            "ITK-Modem-Pool-Id",
                            "ITK-Modem-Init-String",
                            "ITK-PPP-Client-Server-Mode",
                            "ITK-PPP-Compression-Prot",
                            "ITK-Username",
                            "ITK-Dest-No",
                            "ITK-DDI",
                            "IPU-MIP-Spi",
                            "IPU-MIP-Key",
                            "IPU-MIP-Alg-Type",
                            "IPU-MIP-Alg-Mode",
                            "IPU-MIP-Replay-Prot",
                            "IPU-IKE-Remote-Addr",
                            "IPU-IKE-Local-Addr",
                            "IPU-IKE-Auth",
                            "IPU-IKE-Conf-Name",
                            "IPU-IKE-Cmd",
                            "Juniper-Local-User-Name",
                            "Juniper-Allow-Commands",
                            "Juniper-Deny-Commands",
                            "Juniper-Allow-Configuration",
                            "Juniper-Deny-Configuration",
                            "Juniper-Interactive-Command",
                            "Juniper-Configuration-Change",
                            "Juniper-User-Permissions",
                            "Juniper-Junosspace-Profile",
                            "Juniper-Junosspace-Profiles",
                            "Juniper-CTP-Group",
                            "Juniper-CTPView-APP-Group",
                            "Juniper-CTPView-OS-Group",
                            "Juniper-Primary-Dns",
                            "Juniper-Primary-Wins",
                            "Juniper-Secondary-Dns",
                            "Juniper-Secondary-Wins",
                            "Juniper-Interface-id",
                            "Juniper-Ip-Pool-Name",
                            "Juniper-Keep-Alive",
                            "Juniper-CoS-Traffic-Control-Profile",
                            "Juniper-CoS-Parameter",
                            "Juniper-encapsulation-overhead",
                            "Juniper-cell-overhead",
                            "Juniper-tx-connect-speed",
                            "Juniper-rx-connect-speed",
                            "Juniper-Firewall-filter-name",
                            "Juniper-Policer-Parameter",
                            "Juniper-Local-Group-Name",
                            "Juniper-Local-Interface",
                            "Juniper-Switching-Filter",
                            "Juniper-VoIP-Vlan",
                            "KarlNet-TurboCell-Name",
                            "KarlNet-TurboCell-TxRate",
                            "KarlNet-TurboCell-OpState",
                            "KarlNet-TurboCell-OpMode",
                            "Kineto-UMA-Release-Indicator",
                            "Kineto-UMA-AP-Radio-Identity",
                            "Kineto-UMA-Cell-Identity",
                            "Kineto-UMA-Location-Area-Identification",
                            "Kineto-UMA-Coverage-Indicator",
                            "Kineto-UMA-Classmark",
                            "Kineto-UMA-Geographical-Location",
                            "Kineto-UMA-SGW-IP-Address",
                            "Kineto-UMA-SGW-FQDN",
                            "Kineto-UMA-Redirection-Counter",
                            "Kineto-UMA-Discovery-Reject-Cause",
                            "Kineto-UMA-RRC-State",
                            "Kineto-UMA-Register-Reject-Cause",
                            "Kineto-UMA-Routing-Area-Code",
                            "Kineto-UMA-AP-Location",
                            "Kineto-UMA-Location-Status",
                            "Kineto-UMA-Utran-Cell-Identity",
                            "Kineto-UMA-Location-Blacklist-Indicator",
                            "Kineto-UMA-AP-Service-Name",
                            "Kineto-UMA-Service-Zone-Information",
                            "Kineto-UMA-Serving-UNC-Table-Indicator",
                            "Kineto-UMA-Registration-Indicators",
                            "Kineto-UMA-UMA-PLMN-List",
                            "Kineto-UMA-Required-UMA-Services",
                            "Kineto-UMA-3G-Cell-Identity",
                            "Kineto-UMA-MS-Radio-Identity",
                            "Kineto-UMA-UNC-IP-Address",
                            "Kineto-UMA-UNC-FQDN",
                            "KW-IUH-MESSAGE-TYPE",
                            "KW-HNB-REMOTE-ADDRESS",
                            "KW-HNB-IDENTITY",
                            "KW-HNB-LOC-INFO-MACRO-COVERAGE-IND",
                            "KW-HNB-LOC-INFO-GERAN-CELL-ID",
                            "KW-HNB-LOC-INFO-UTRAN-CELL-ID",
                            "KW-HNB-LOC-INFO-GEO-COORDINATES",
                            "KW-HNB-LOC-INFO-ALTITUDE-Direction",
                            "KW-HNB-LOC-INFO-IP-ADDRESS",
                            "KW-HNB-PLMN-ID",
                            "KW-HNB-CELL-ID",
                            "KW-HNB-LAC",
                            "KW-HNB-RAC",
                            "KW-HNB-SAC",
                            "KW-HNB-CSG-ID",
                            "KW-UE-Capabilities",
                            "LCS-Traffic-Limit",
                            "LCS-Mac-Address",
                            "LCS-Redirection-URL",
                            "LCS-Comment",
                            "LCS-Account-End",
                            "LCS-WPA-Passphrase",
                            "LCS-PbSpotUserName",
                            "LCS-TxRateLimit",
                            "LCS-RxRateLimit",
                            "LCS-Access-Rights",
                            "LCS-Function-Rights",
                            "LCS-Advertisement-URL",
                            "LCS-Advertisement-Interval",
                            "LCS-Traffic-Limit-Gigawords",
                            "LCS-Orig-NAS-Identifier",
                            "LCS-Orig-NAS-IP-Address",
                            "LCS-Orig-NAS-IPv6-Address",
                            "LCS-IKEv2-Local-Password",
                            "LCS-IKEv2-Remote-Password",
                            "LCS-DNS-Server-IPv4-Address",
                            "LCS-VPN-IPv4-Rule",
                            "LCS-VPN-IPv6-Rule",
                            "LCS-Routing-Tag",
                            "LCS-IKEv2-IPv4-Route",
                            "LCS-IKEv2-IPv6-Route",
                            "Lantronix-User-Attributes",
                            "LE-Terminate-Detail",
                            "LE-Advice-of-Charge",
                            "LE-Connect-Detail",
                            "LE-IP-Pool",
                            "LE-IP-Gateway",
                            "LE-Modem-Info",
                            "LE-IPSec-Log-Options",
                            "LE-IPSec-Deny-Action",
                            "LE-IPSec-Active-Profile",
                            "LE-IPSec-Outsource-Profile",
                            "LE-IPSec-Passive-Profile",
                            "LE-NAT-TCP-Session-Timeout",
                            "LE-NAT-Other-Session-Timeout",
                            "LE-NAT-Log-Options",
                            "LE-NAT-Sess-Dir-Fail-Action",
                            "LE-NAT-Inmap",
                            "LE-NAT-Outmap",
                            "LE-NAT-Outsource-Inmap",
                            "LE-NAT-Outsource-Outmap",
                            "LE-Admin-Group",
                            "LE-Multicast-Client",
                            "Local-Web-Client-Ip",
                            "Local-Web-Border-Router",
                            "Local-Web-Tx-Limit",
                            "Local-Web-Rx-Limit",
                            "Local-Web-Acct-Time",
                            "Local-Web-Acct-Duration",
                            "Local-Web-Acct-Interim-Tx-Bytes",
                            "Local-Web-Acct-Interim-Rx-Bytes",
                            "Local-Web-Acct-Interim-Tx-Gigawords",
                            "Local-Web-Acct-Interim-Rx-Gigawords",
                            "Local-Web-Acct-Interim-Tx-Mgmt",
                            "Local-Web-Acct-Interim-Rx-Mgmt",
                            "Local-Web-Acct-Tx-Mgmt",
                            "Local-Web-Acct-Rx-Mgmt",
                            "Local-Web-Reauth-Counter",
                            "Lucent-Max-Shared-Users",
                            "Lucent-IP-DSCP",
                            "Lucent-X25-X121-Source-Address",
                            "Lucent-PPP-Circuit",
                            "Lucent-PPP-Circuit-Name",
                            "Lucent-UU-Info",
                            "Lucent-User-Priority",
                            "Lucent-CIR-Timer",
                            "Lucent-FR-08-Mode",
                            "Lucent-Destination-NAS-Port",
                            "Lucent-FR-SVC-Addr",
                            "Lucent-NAS-Port-Format",
                            "Lucent-ATM-Fault-Management",
                            "Lucent-ATM-Loopback-Cell-Loss",
                            "Lucent-Ckt-Type",
                            "Lucent-SVC-Enabled",
                            "Lucent-Session-Type",
                            "Lucent-H323-Gatekeeper",
                            "Lucent-Global-Call-Id",
                            "Lucent-H323-Conference-Id",
                            "Lucent-H323-Destination-NAS-ID",
                            "Lucent-H323-Dialed-Time",
                            "Lucent-Dialed-Number",
                            "Lucent-Inter-Arrival-Jitter",
                            "Lucent-Dropped-Octets",
                            "Lucent-Dropped-Packets",
                            "Lucent-Auth-Delay",
                            "Lucent-X25-Pad-X3-Profile",
                            "Lucent-X25-Pad-X3-Parameters",
                            "Lucent-Tunnel-VRouter-Name",
                            "Lucent-X25-Reverse-Charging",
                            "Lucent-X25-Nui-Prompt",
                            "Lucent-X25-Nui-Password-Prompt",
                            "Lucent-X25-Cug",
                            "Lucent-X25-Pad-Alias-1",
                            "Lucent-X25-Pad-Alias-2",
                            "Lucent-X25-Pad-Alias-3",
                            "Lucent-X25-X121-Address",
                            "Lucent-X25-Nui",
                            "Lucent-X25-Rpoa",
                            "Lucent-X25-Pad-Prompt",
                            "Lucent-X25-Pad-Banner",
                            "Lucent-X25-Profile-Name",
                            "Lucent-Recv-Name",
                            "Lucent-Bi-Directional-Auth",
                            "Lucent-MTU",
                            "Lucent-Call-Direction",
                            "Lucent-Service-Type",
                            "Lucent-Filter-Required",
                            "Lucent-Traffic-Shaper",
                            "Lucent-Access-Intercept-LEA",
                            "Lucent-Access-Intercept-Log",
                            "Lucent-Private-Route-Table-ID",
                            "Lucent-Private-Route-Required",
                            "Lucent-Cache-Refresh",
                            "Lucent-Cache-Time",
                            "Lucent-Egress-Enabled",
                            "Lucent-QOS-Upstream",
                            "Lucent-QOS-Downstream",
                            "Lucent-ATM-Connect-Vpi",
                            "Lucent-ATM-Connect-Vci",
                            "Lucent-ATM-Connect-Group",
                            "Lucent-ATM-Group",
                            "Lucent-IPX-Header-Compression",
                            "Lucent-Calling-Id-Type-Of-Number",
                            "Lucent-Calling-Id-Numbering-Plan",
                            "Lucent-Calling-Id-Presentation",
                            "Lucent-Calling-Id-Screening",
                            "Lucent-BIR-Enable",
                            "Lucent-BIR-Proxy",
                            "Lucent-BIR-Bridge-Group",
                            "Lucent-IPSEC-Profile",
                            "Lucent-PPPoE-Enable",
                            "Lucent-Bridge-Non-PPPoE",
                            "Lucent-ATM-Direct",
                            "Lucent-ATM-Direct-Profile",
                            "Lucent-Client-Primary-WINS",
                            "Lucent-Client-Secondary-WINS",
                            "Lucent-Client-Assign-WINS",
                            "Lucent-Auth-Type",
                            "Lucent-Port-Redir-Protocol",
                            "Lucent-Port-Redir-Portnum",
                            "Lucent-Port-Redir-Server",
                            "Lucent-IP-Pool-Chaining",
                            "Lucent-Owner-IP-Addr",
                            "Lucent-IP-TOS",
                            "Lucent-IP-TOS-Precedence",
                            "Lucent-IP-TOS-Apply-To",
                            "Lucent-Filter",
                            "Lucent-Telnet-Profile",
                            "Lucent-Dsl-Rate-Type",
                            "Lucent-Redirect-Number",
                            "Lucent-ATM-Vpi",
                            "Lucent-ATM-Vci",
                            "Lucent-Source-IP-Check",
                            "Lucent-Dsl-Rate-Mode",
                            "Lucent-Dsl-Upstream-Limit",
                            "Lucent-Dsl-Downstream-Limit",
                            "Lucent-Dsl-CIR-Recv-Limit",
                            "Lucent-Dsl-CIR-Xmit-Limit",
                            "Lucent-VRouter-Name",
                            "Lucent-Source-Auth",
                            "Lucent-Private-Route",
                            "Lucent-Numbering-Plan-ID",
                            "Lucent-FR-Link-Status-DLCI",
                            "Lucent-Calling-Subaddress",
                            "Lucent-Callback-Delay",
                            "Lucent-Endpoint-Disc",
                            "Lucent-Remote-FW",
                            "Lucent-Multicast-GLeave-Delay",
                            "Lucent-CBCP-Enable",
                            "Lucent-CBCP-Mode",
                            "Lucent-CBCP-Delay",
                            "Lucent-CBCP-Trunk-Group",
                            "Lucent-Appletalk-Route",
                            "Lucent-Appletalk-Peer-Mode",
                            "Lucent-Route-Appletalk",
                            "Lucent-FCP-Parameter",
                            "Lucent-Modem-PortNo",
                            "Lucent-Modem-SlotNo",
                            "Lucent-Modem-ShelfNo",
                            "Lucent-Call-Attempt-Limit",
                            "Lucent-Call-Block-Duration",
                            "Lucent-Maximum-Call-Duration",
                            "Lucent-Route-Preference",
                            "Lucent-Tunneling-Protocol",
                            "Lucent-Shared-Profile-Enable",
                            "Lucent-Primary-Home-Agent",
                            "Lucent-Secondary-Home-Agent",
                            "Lucent-Dialout-Allowed",
                            "Lucent-Client-Gateway",
                            "Lucent-BACP-Enable",
                            "Lucent-DHCP-Maximum-Leases",
                            "Lucent-Client-Primary-DNS",
                            "Lucent-Client-Secondary-DNS",
                            "Lucent-Client-Assign-DNS",
                            "Lucent-User-Acct-Type",
                            "Lucent-User-Acct-Host",
                            "Lucent-User-Acct-Port",
                            "Lucent-User-Acct-Key",
                            "Lucent-User-Acct-Base",
                            "Lucent-User-Acct-Time",
                            "Lucent-Assign-IP-Client",
                            "Lucent-Assign-IP-Server",
                            "Lucent-Assign-IP-Global-Pool",
                            "Lucent-DHCP-Reply",
                            "Lucent-DHCP-Pool-Number",
                            "Lucent-Expect-Callback",
                            "Lucent-Event-Type",
                            "Lucent-Session-Svr-Key",
                            "Lucent-Multicast-Rate-Limit",
                            "Lucent-IF-Netmask",
                            "Lucent-Remote-Addr",
                            "Lucent-Multicast-Client",
                            "Lucent-FR-Circuit-Name",
                            "Lucent-FR-LinkUp",
                            "Lucent-FR-Nailed-Grp",
                            "Lucent-FR-Type",
                            "Lucent-FR-Link-Mgt",
                            "Lucent-FR-N391",
                            "Lucent-FR-DCE-N392",
                            "Lucent-FR-DTE-N392",
                            "Lucent-FR-DCE-N393",
                            "Lucent-FR-DTE-N393",
                            "Lucent-FR-T391",
                            "Lucent-FR-T392",
                            "Lucent-Bridge-Address",
                            "Lucent-TS-Idle-Limit",
                            "Lucent-TS-Idle-Mode",
                            "Lucent-DBA-Monitor",
                            "Lucent-Base-Channel-Count",
                            "Lucent-Minimum-Channels",
                            "Lucent-IPX-Route",
                            "Lucent-FT1-Caller",
                            "Lucent-Backup",
                            "Lucent-Call-Type",
                            "Lucent-Group",
                            "Lucent-FR-DLCI",
                            "Lucent-FR-Profile-Name",
                            "Lucent-Ara-PW",
                            "Lucent-IPX-Node-Addr",
                            "Lucent-Home-Agent-IP-Addr",
                            "Lucent-Home-Agent-Password",
                            "Lucent-Home-Network-Name",
                            "Lucent-Home-Agent-UDP-Port",
                            "Lucent-Multilink-ID",
                            "Lucent-Num-In-Multilink",
                            "Lucent-First-Dest",
                            "Lucent-Pre-Input-Octets",
                            "Lucent-Pre-Output-Octets",
                            "Lucent-Pre-Input-Packets",
                            "Lucent-Pre-Output-Packets",
                            "Lucent-Maximum-Time",
                            "Lucent-Disconnect-Cause",
                            "Lucent-Connect-Progress",
                            "Lucent-Data-Rate",
                            "Lucent-PreSession-Time",
                            "Lucent-Token-Idle",
                            "Lucent-Token-Immediate",
                            "Lucent-Require-Auth",
                            "Lucent-Number-Sessions",
                            "Lucent-Authen-Alias",
                            "Lucent-Token-Expiry",
                            "Lucent-Menu-Selector",
                            "Lucent-Menu-Item",
                            "Lucent-PW-Warntime",
                            "Lucent-PW-Lifetime",
                            "Lucent-IP-Direct",
                            "Lucent-PPP-VJ-Slot-Comp",
                            "Lucent-PPP-VJ-1172",
                            "Lucent-PPP-Async-Map",
                            "Lucent-Third-Prompt",
                            "Lucent-Send-Secret",
                            "Lucent-Receive-Secret",
                            "Lucent-IPX-Peer-Mode",
                            "Lucent-IP-Pool-Definition",
                            "Lucent-Assign-IP-Pool",
                            "Lucent-FR-Direct",
                            "Lucent-FR-Direct-Profile",
                            "Lucent-FR-Direct-DLCI",
                            "Lucent-Handle-IPX",
                            "Lucent-Netware-timeout",
                            "Lucent-IPX-Alias",
                            "Lucent-Metric",
                            "Lucent-PRI-Number-Type",
                            "Lucent-Dial-Number",
                            "Lucent-Route-IP",
                            "Lucent-Route-IPX",
                            "Lucent-Bridge",
                            "Lucent-Send-Auth",
                            "Lucent-Send-Passwd",
                            "Lucent-Link-Compression",
                            "Lucent-Target-Util",
                            "Lucent-Maximum-Channels",
                            "Lucent-Inc-Channel-Count",
                            "Lucent-Dec-Channel-Count",
                            "Lucent-Seconds-Of-History",
                            "Lucent-History-Weigh-Type",
                            "Lucent-Add-Seconds",
                            "Lucent-Remove-Seconds",
                            "Lucent-Data-Filter",
                            "Lucent-Call-Filter",
                            "Lucent-Idle-Limit",
                            "Lucent-Preempt-Limit",
                            "Lucent-Callback",
                            "Lucent-Data-Svc",
                            "Lucent-Force-56",
                            "Lucent-Billing-Number",
                            "Lucent-Call-By-Call",
                            "Lucent-Transit-Number",
                            "Lucent-Host-Info",
                            "Lucent-PPP-Address",
                            "Lucent-MPP-Idle-Percent",
                            "Lucent-Xmit-Rate",
                            "Lucent-Fr05-Traffic-Shaper",
                            "Lucent-Fr05-Vpi",
                            "Lucent-Fr05-Vci",
                            "Lucent-Fr05-Enabled",
                            "Lucent-Tunnel-Auth-Type",
                            "Lucent-MOH-Timeout",
                            "Lucent-ATM-Circuit-Name",
                            "Lucent-Priority-For-PPP",
                            "Lucent-Max-RTP-Delay",
                            "Lucent-RTP-Port-Range",
                            "Lucent-TOS-Copying",
                            "Lucent-Packet-Classification",
                            "Lucent-No-High-Prio-Pkt-Duratio",
                            "Lucent-AT-Answer-String",
                            "Lucent-IP-OUTGOING-TOS",
                            "Lucent-IP-OUTGOING-TOS-Precedence",
                            "Lucent-IP-OUTGOING-DSCP",
                            "Lucent-TermSrv-Login-Prompt",
                            "Lucent-Multicast-Service-Profile-Name",
                            "Lucent-Multicast-Max-Groups",
                            "Lucent-Multicast-Service-Name",
                            "Lucent-Multicast-Service-Active",
                            "Lucent-Multicast-Service-Snmp-Trap",
                            "Lucent-Multicast-Service-Filter-Type",
                            "Lucent-Multicast-Filter-Active",
                            "Lucent-Multicast-Filter-Address",
                            "Lucent-Tunnel-TOS",
                            "Lucent-Tunnel-TOS-Precedence",
                            "Lucent-Tunnel-DSCP",
                            "Lucent-Tunnel-TOS-Filter",
                            "Lucent-Tunnel-TOS-Copy",
                            "Lucent-Http-Redirect-URL",
                            "Lucent-Http-Redirect-Port",
                            "Lucent-L2TP-DCI-Disconnect-Code",
                            "Lucent-L2TP-DCI-Protocol-Number",
                            "Lucent-L2TP-DCI-Direction",
                            "Lucent-L2TP-DCI-Message",
                            "Lucent-L2TP-Q931-Cause-Code",
                            "Lucent-L2TP-Q931-Cause-Message",
                            "Lucent-L2TP-Q931-Advisory-Message",
                            "Lucent-L2TP-RC-Result-Code",
                            "Lucent-L2TP-RC-Error-Code",
                            "Lucent-L2TP-RC-Error-Message",
                            "Lucent-L2TP-Disconnect-Scenario",
                            "Lucent-L2TP-Peer-Disconnect-Cause",
                            "Lucent-L2TP-Peer-Connect-Progress",
                            "Lucent-QuickConnect-Attempted",
                            "Lucent-Num-Moh-Sessions",
                            "Lucent-Cumulative-Hold-Time",
                            "Lucent-Modem-Modulation",
                            "Lucent-User-Acct-Expiration",
                            "Lucent-User-Login-Level",
                            "Lucent-First-Level-User",
                            "Lucent-IP-Source-If",
                            "Lucent-Reverse-Path-Check",
                            "Lucent-LCP-Keepalive-Period",
                            "Lucent-LCP-Keepalive-Missed-Limit",
                            "Lucent-Dsl-Atuc-Chan-Uncorrect-Blks",
                            "Lucent-Dsl-Atuc-Chan-Corrected-Blks",
                            "Lucent-Dsl-Atuc-Chan-Xmit-Blks",
                            "Lucent-Dsl-Atuc-Chan-Recd-Blks",
                            "Lucent-Dsl-Atuc-Perf-Inits",
                            "Lucent-Dsl-Atuc-Perf-ESs",
                            "Lucent-Dsl-Atuc-Perf-Lprs",
                            "Lucent-Dsl-Atuc-Perf-Lols",
                            "Lucent-Dsl-Atuc-Perf-Loss",
                            "Lucent-Dsl-Atuc-Perf-Lofs",
                            "Lucent-Dsl-Atuc-Curr-Attainable-Rate-Dn",
                            "Lucent-Dsl-Atuc-Curr-Output-Pwr-Dn",
                            "Lucent-Dsl-Atuc-Curr-Atn-Up",
                            "Lucent-Dsl-Atuc-Curr-Snr-Mgn-Up",
                            "Lucent-Dsl-Atuc-PS-Fast-Retrains",
                            "Lucent-Dsl-Atuc-PS-Failed-Fast-Retrains",
                            "Lucent-Dsl-Code-Violations",
                            "Lucent-Line-Type",
                            "Lucent-Dsl-Curr-Up-Rate",
                            "Lucent-Dsl-Curr-Dn-Rate",
                            "Lucent-Dsl-Physical-Slot",
                            "Lucent-Dsl-Physical-Line",
                            "Lucent-Dsl-If-Index",
                            "Lucent-Dsl-Oper-Status",
                            "Lucent-Dsl-Related-If-Index",
                            "Lucent-Dsl-Atuc-Curr-Attainable-Rate-Up",
                            "Lucent-Dsl-Atuc-Curr-Output-Pwr-Up",
                            "Lucent-Dsl-Atuc-Curr-Atn-Dn",
                            "Lucent-Dsl-Atuc-Curr-Snr-Mgn-D",
                            "Lucent-Dsl-Related-Slot",
                            "Lucent-Dsl-Related-Port",
                            "Lucent-Dsl-Sparing-Role",
                            "Lucent-Absolute-Time",
                            "Lucent-Configured-Rate-Up-Min",
                            "Lucent-Configured-Rate-Up-Max",
                            "Lucent-Configured-Rate-Dn-Min",
                            "Lucent-Configured-Rate-Dn-Max",
                            "Lucent-Dsl-Physical-Channel",
                            "Lucent-Sonet-Section-ESs",
                            "Lucent-Sonet-Section-SESs",
                            "Lucent-Sonet-Section-SEFSs",
                            "Lucent-Sonet-Section-CVs",
                            "Lucent-Sonet-Line-ESs-Near",
                            "Lucent-Sonet-Line-SESs-Near",
                            "Lucent-Sonet-Line-CVs-Near",
                            "Lucent-Sonet-Line-USs-Near",
                            "Lucent-Sonet-Line-ESs-Far",
                            "Lucent-Sonet-Line-SESs-Far",
                            "Lucent-Sonet-Line-CVs-Far",
                            "Lucent-Sonet-Line-USs-Far",
                            "Lucent-Sonet-Path-ESs-Near",
                            "Lucent-Sonet-Path-SESs-Near",
                            "Lucent-Sonet-Path-CVs-Near",
                            "Lucent-Sonet-Path-USs-Near",
                            "Lucent-Sonet-Path-ESs-Far",
                            "Lucent-Sonet-Path-SESs-Far",
                            "Lucent-Sonet-Path-CVs-Far",
                            "Lucent-Sonet-Path-USs-Far",
                            "Lucent-Ds3-F-Bit-Err",
                            "Lucent-Ds3-P-Bit-Err",
                            "Lucent-Ds3-CCVs",
                            "Lucent-Ds3-PESs",
                            "Lucent-Ds3-PSESs",
                            "Lucent-Ds3-SEFs",
                            "Lucent-Ds3-UASs",
                            "Lucent-Ds3-LCVs",
                            "Lucent-Ds3-PCVs",
                            "Lucent-Ds3-LESs",
                            "Lucent-Ds3-CESs",
                            "Lucent-Ds3-CSESs",
                            "Lucent-Rtp-Local-Number-Of-Samples",
                            "Lucent-Rtp-Remote-Number-Of-Samples",
                            "Lucent-Rtp-Local-Jitter-Minimum",
                            "Lucent-Rtp-Local-Jitter-Maximum",
                            "Lucent-Rtp-Local-Jitter-Mean",
                            "Lucent-Rtp-Local-Jitter-Variance",
                            "Lucent-Rtp-Local-Delay-Minimum",
                            "Lucent-Rtp-Local-Delay-Maximum",
                            "Lucent-Rtp-Local-Delay-Mean",
                            "Lucent-Rtp-Local-Delay-Variance",
                            "Lucent-Rtp-Local-Packets-Sent",
                            "Lucent-Rtp-Local-Packets-Lost",
                            "Lucent-Rtp-Local-Packets-Late",
                            "Lucent-Rtp-Local-Bytes-Sent",
                            "Lucent-Rtp-Local-Silence-Percent",
                            "Lucent-Rtp-Remote-Jitter-Minimum",
                            "Lucent-Rtp-Remote-Jitter-Maximum",
                            "Lucent-Rtp-Remote-Jitter-Mean",
                            "Lucent-Rtp-Remote-Jitter-Variance",
                            "Lucent-Rtp-Remote-Delay-Minimum",
                            "Lucent-Rtp-Remote-Delay-Maximum",
                            "Lucent-Rtp-Remote-Delay-Mean",
                            "Lucent-Rtp-Remote-Delay-Variance",
                            "Lucent-Rtp-Remote-Packets-Sent",
                            "Lucent-Rtp-Remote-Packets-Lost",
                            "Lucent-Rtp-Remote-Packets-Late",
                            "Lucent-Rtp-Remote-Bytes-Sent",
                            "Lucent-Rtp-Remote-Silence-Percent",
                            "Lucent-Tunnel-Auth-Type2",
                            "Lucent-Multi-Packet-Separator",
                            "Lucent-Min-Xmit-Rate",
                            "Lucent-Max-Xmit-Rate",
                            "Lucent-Min-Recv-Rate",
                            "Lucent-Max-Recv-Rate",
                            "Lucent-Error-Correction-Protocol",
                            "Lucent-Compression-Protocol",
                            "Lucent-Modulation",
                            "Lucent-Xmit-Symbol-Rate",
                            "Lucent-Recv-Symbol-Rate",
                            "Lucent-Current-Xmit-Level",
                            "Lucent-Current-Recv-Level",
                            "Lucent-Current-Line-Quality",
                            "Lucent-Current-SNR",
                            "Lucent-Min-SNR",
                            "Lucent-Max-SNR",
                            "Lucent-Local-Retrain-Requested",
                            "Lucent-Remote-Retrain-Requested",
                            "Lucent-Connection-Time",
                            "Lucent-Modem-Disconnect-Reason",
                            "Lucent-Retrain-Reason",
                            "Manzara-User-UID",
                            "Manzara-User-GID",
                            "Manzara-User-Home",
                            "Manzara-User-Shell",
                            "Manzara-PPP-Addr-String",
                            "Manzara-Full-Login-String",
                            "Manzara-Tariff-Units",
                            "Manzara-Tariff-Type",
                            "Manzara-ECP-Session-Key",
                            "Manzara-Map-Name",
                            "Manzara-Map-Key",
                            "Manzara-Map-Value",
                            "Manzara-Map-Error",
                            "Manzara-Service-Type",
                            "MBG-Management-Privilege-Level",
                            "Meraki-Device-Name",
                            "Merit-Proxy-Action",
                            "Merit-User-Id",
                            "Merit-User-Realm",
                            "Meru-Access-Point-Id",
                            "Meru-Access-Point-Name",
                            "Microsemi-User-Full-Name",
                            "Microsemi-User-Name",
                            "Microsemi-User-Initials",
                            "Microsemi-User-Email",
                            "Microsemi-User-Group",
                            "Microsemi-Fallback-User-Group",
                            "Microsemi-Network-Element-Group",
                            "MS-CHAP-Response",
                            "MS-CHAP-Error",
                            "MS-CHAP-CPW-1",
                            "MS-CHAP-CPW-2",
                            "MS-CHAP-LM-Enc-PW",
                            "MS-CHAP-NT-Enc-PW",
                            "MS-MPPE-Encryption-Policy",
                            "MS-MPPE-Encryption-Type",
                            "MS-MPPE-Encryption-Types",
                            "MS-RAS-Vendor",
                            "MS-CHAP-Domain",
                            "MS-CHAP-Challenge",
                            "MS-CHAP-MPPE-Keys",
                            "MS-BAP-Usage",
                            "MS-Link-Utilization-Threshold",
                            "MS-Link-Drop-Time-Limit",
                            "MS-MPPE-Send-Key",
                            "MS-MPPE-Recv-Key",
                            "MS-RAS-Version",
                            "MS-Old-ARAP-Password",
                            "MS-New-ARAP-Password",
                            "MS-ARAP-PW-Change-Reason",
                            "MS-Filter",
                            "MS-Acct-Auth-Type",
                            "MS-Acct-EAP-Type",
                            "MS-CHAP2-Response",
                            "MS-CHAP2-Success",
                            "MS-CHAP2-CPW",
                            "MS-Primary-DNS-Server",
                            "MS-Secondary-DNS-Server",
                            "MS-Primary-NBNS-Server",
                            "MS-Secondary-NBNS-Server",
                            "MS-RAS-Client-Name",
                            "MS-RAS-Client-Version",
                            "MS-Quarantine-IPFilter",
                            "MS-Quarantine-Session-Timeout",
                            "MS-User-Security-Identity",
                            "MS-Identity-Type",
                            "MS-Service-Class",
                            "MS-Quarantine-User-Class",
                            "MS-Quarantine-State",
                            "MS-Quarantine-Grace-Time",
                            "MS-Network-Access-Server-Type",
                            "MS-AFW-Zone",
                            "MS-AFW-Protection-Level",
                            "MS-Machine-Name",
                            "MS-IPv6-Filter",
                            "MS-IPv4-Remediation-Servers",
                            "MS-IPv6-Remediation-Servers",
                            "MS-RNAP-Not-Quarantine-Capable",
                            "MS-Quarantine-SOH",
                            "MS-RAS-Correlation",
                            "MS-Extended-Quarantine-State",
                            "MS-HCAP-User-Groups",
                            "MS-HCAP-Location-Group-Name",
                            "MS-HCAP-User-Name",
                            "MS-User-IPv4-Address",
                            "MS-User-IPv6-Address",
                            "MS-TSG-Device-Redirection",
                            "Mikrotik-Recv-Limit",
                            "Mikrotik-Xmit-Limit",
                            "Mikrotik-Group",
                            "Mikrotik-Wireless-Forward",
                            "Mikrotik-Wireless-Skip-Dot1x",
                            "Mikrotik-Wireless-Enc-Algo",
                            "Mikrotik-Wireless-Enc-Key",
                            "Mikrotik-Rate-Limit",
                            "Mikrotik-Realm",
                            "Mikrotik-Host-IP",
                            "Mikrotik-Mark-Id",
                            "Mikrotik-Advertise-URL",
                            "Mikrotik-Advertise-Interval",
                            "Mikrotik-Recv-Limit-Gigawords",
                            "Mikrotik-Xmit-Limit-Gigawords",
                            "Mikrotik-Wireless-PSK",
                            "Mikrotik-Total-Limit",
                            "Mikrotik-Total-Limit-Gigawords",
                            "Mikrotik-Address-List",
                            "Mikrotik-Wireless-MPKey",
                            "Mikrotik-Wireless-Comment",
                            "Mikrotik-Delegated-IPv6-Pool",
                            "Mikrotik-DHCP-Option-Set",
                            "Mikrotik-DHCP-Option-Param-STR1",
                            "Mikortik-DHCP-Option-ParamSTR2",
                            "Mikrotik-Wireless-VLANID",
                            "Mikrotik-Wireless-VLANID-Type",
                            "Mikrotik-Wireless-Minsignal",
                            "Mikrotik-Wireless-Maxsignal",
                            "Mimosa-Device-Configuration-Parameter",
                            "Mimosa-FirmwareVersion-Parameter",
                            "Mimosa-FirmwareLocation-Parameter",
                            "Mimosa-WirelessProtocol-Parameter",
                            "Mimosa-ManagementIPAddressMode-Parameter",
                            "Mimosa-ManagementIPAddress-Parameter",
                            "Mimosa-ManagementIPNetmask-Parameter",
                            "Mimosa-ManagementIPGateway-Parameter",
                            "Mimosa-ManagementVlanStatus-Parameter",
                            "Mimosa-ManagementVlan-Parameter",
                            "Mimosa-ManagementPassword-Parameter",
                            "Mimosa-DeviceName-Parameter",
                            "Mimosa-TrafficShapingPeak-Parameter",
                            "Mimosa-TrafficShapingCommitted-Parameter",
                            "Mimosa-EthernetPortSpeed-Parameter",
                            "Mimosa-DNS1-Parameter",
                            "Mimosa-DNS2-Parameter",
                            "Mimosa-HTTPPort-Parameter",
                            "Mimosa-EnableHTTPS-Parameter",
                            "Mimosa-HTTPSPort-Parameter",
                            "Mimosa-CloudManagement-Parameter",
                            "Mimosa-EnableSNMP-Parameter",
                            "Mimosa-SNMPCommunityString-Parameter",
                            "Mimosa-SNMPTrapServer-Parameter",
                            "Mimosa-NTPServerAddress-Parameter",
                            "Mimosa-EnableSyslog-Parameter",
                            "Mimosa-SyslogServerAddress-Parameter",
                            "Mimosa-SyslogPort-Parameter",
                            "Mimosa-SyslogProtocol-Parameter",
                            "Motorola-Canopy-LPULCIR",
                            "Motorola-Canopy-LPDLCIR",
                            "Motorola-Canopy-HPULCIR",
                            "Motorola-Canopy-HPDLCIR",
                            "Motorola-Canopy-HPENABLE",
                            "Motorola-Canopy-ULBR",
                            "Motorola-Canopy-ULBL",
                            "Motorola-Canopy-DLBR",
                            "Motorola-Canopy-DLBL",
                            "Motorola-Canopy-VLLEARNEN",
                            "Motorola-Canopy-VLFRAMES",
                            "Motorola-Canopy-VLIDSET",
                            "Motorola-Canopy-VLAGETO",
                            "Motorola-Canopy-VLIGVID",
                            "Motorola-Canopy-VLMGVID",
                            "Motorola-Canopy-VLSMMGPASS",
                            "Motorola-Canopy-BCASTMIR",
                            "Motorola-Canopy-UserLevel",
                            "Motorola-WiMAX-MIP-MN-HOME-ADDRESS",
                            "Motorola-WiMAX-MIP-KEY",
                            "Motorola-WiMAX-MIP-SPI",
                            "Motorola-WiMAX-MN-HA",
                            "Motorola-WiMAX-DNS-Server-IP-Address",
                            "Motorola-WiMAX-User-NAI",
                            "Motorola-WiMAX-Network-Domain-Name",
                            "Motorola-WiMAX-EMS-Address",
                            "Motorola-WiMAX-Provisioning-Server",
                            "Motorola-WiMAX-NTP-Server",
                            "Motorola-WiMAX-HO-SVC-CLASS",
                            "Motorola-WiMAX-Home-BTS",
                            "Motorola-WiMAX-Maximum-Total-Bandwidth",
                            "Motorola-WiMAX-Maximum-Commit-Bandwidth",
                            "Motorola-WiMAX-Convergence-Sublayer",
                            "Motorola-WiMAX-Service-Flows",
                            "Motorola-WiMAX-VLAN-ID",
                            "Motorola-Accounting-Message",
                            "Navini-AVPair",
                            "NS-Admin-Privilege",
                            "NS-VSYS-Name",
                            "NS-User-Group",
                            "NS-Primary-DNS",
                            "NS-Secondary-DNS",
                            "NS-Primary-WINS",
                            "NS-Secondary-WINS",
                            "NS-NSM-User-Domain-Name",
                            "NS-NSM-User-Role-Mapping",
                            "NetSensory-Privilege",
                            "Nexans-Port-Default-VLAN-ID",
                            "Nexans-Port-Voice-VLAN-ID",
                            "UserLogon-Uid",
                            "UserLogon-Gid",
                            "UserLogon-HomeDir",
                            "UserLogon-Type",
                            "UserLogon-QuotaBytes",
                            "UserLogon-QuotaFiles",
                            "UserLogon-Shell",
                            "UserLogon-Restriction",
                            "UserLogon-GroupNames",
                            "UserLogon-DriveNames",
                            "UserLogon-UserDescription",
                            "UserLogon-UserFullName",
                            "UserLogon-UserDomain",
                            "UserLogon-LogonTask",
                            "UserLogon-LogoffTask",
                            "UserLogon-Expiration",
                            "UserLogon-UserProfile",
                            "UserLogon-Acct-TerminateCause",
                            "Nokia-AVPair",
                            "Nokia-User-Profile",
                            "Nokia-Service-Name",
                            "Nokia-Service-Id",
                            "Nokia-Service-Username",
                            "Nokia-Service-Password",
                            "Nokia-Service-Primary-Indicator",
                            "Nokia-Service-Charging-Type",
                            "Nokia-Service-Encrypted-Password",
                            "Nokia-Session-Access-Method",
                            "Nokia-Session-Charging-Type",
                            "Nokia-OCS-ID1",
                            "Nokia-OCS-ID2",
                            "Nokia-TREC-Index",
                            "Nokia-Requested-APN",
                            "Nomadix-Bw-Up",
                            "Nomadix-Bw-Down",
                            "Nomadix-URL-Redirection",
                            "Nomadix-IP-Upsell",
                            "Nomadix-Expiration",
                            "Nomadix-Subnet",
                            "Nomadix-MaxBytesUp",
                            "Nomadix-MaxBytesDown",
                            "Nomadix-EndofSession",
                            "Nomadix-Logoff-URL",
                            "Nomadix-Net-VLAN",
                            "Nomadix-Config-URL",
                            "Nomadix-Goodbye-URL",
                            "Nomadix-Qos-Policy",
                            "Nomadix-SMTP-Redirect",
                            "Nomadix-Centralized-Mgmt",
                            "Nomadix-Group-Policy-Id",
                            "Nomadix-Group-Bw-Max-Up",
                            "Nomadix-Group-Bw-Max-Down",
                            "Nortel-User-Role",
                            "Nortel-Privilege-Level",
                            "Passport-Command-Scope",
                            "Passport-Command-Impact",
                            "Passport-Customer-Identifier",
                            "Passport-Allowed-Access",
                            "Passport-AllowedOut-Access",
                            "Passport-Login-Directory",
                            "Passport-Timeout-Protocol",
                            "Passport-Role",
                            "Packeteer-AVPair",
                            "Packeteer-PC-AVPair",
                            "PaloAlto-Admin-Role",
                            "PaloAlto-Admin-Access-Domain",
                            "PaloAlto-Panorama-Admin-Role",
                            "PaloAlto-Panorama-Admin-Access-Domain",
                            "PaloAlto-User-Group",
                            "Patton-Protocol",
                            "Patton-Group",
                            "Patton-Web-Privilege-Level",
                            "Patton-Setup-Time",
                            "Patton-Connect-Time",
                            "Patton-Disconnect-Time",
                            "Patton-Disconnect-Cause",
                            "Patton-Disconnect-Source",
                            "Patton-Disconnect-Reason",
                            "Patton-Called-Unique-Id",
                            "Patton-Called-IP-Address",
                            "Patton-Called-Numbering-Plan",
                            "Patton-Called-Type-Of-Number",
                            "Patton-Called-Name",
                            "Patton-Called-Station-Id",
                            "Patton-Called-Rx-Octets",
                            "Patton-Called-Tx-Octets",
                            "Patton-Called-Rx-Packets",
                            "Patton-Called-Tx-Packets",
                            "Patton-Called-Rx-Lost-Packets",
                            "Patton-Called-Tx-Lost-Packets",
                            "Patton-Called-Rx-Jitter",
                            "Patton-Called-Tx-Jitter",
                            "Patton-Called-Codec",
                            "Patton-Called-Remote-Ip",
                            "Patton-Called-Remote-Udp-Port",
                            "Patton-Called-Local-Udp-Port",
                            "Patton-Called-Qos",
                            "Patton-Called-MOS",
                            "Patton-Called-Round-Trip-Time",
                            "Patton-Calling-Unique-Id",
                            "Patton-Calling-IP-Address",
                            "Patton-Calling-Numbering-Plan",
                            "Patton-Calling-Type-Of-Number",
                            "Patton-Calling-Presentation-Indicator",
                            "Patton-Calling-Screening-Indicator",
                            "Patton-Calling-Name",
                            "Patton-Calling-Station-Id",
                            "Patton-Calling-Rx-Octets",
                            "Patton-Calling-Tx-Octets",
                            "Patton-Calling-Rx-Packets",
                            "Patton-Calling-Tx-Packets",
                            "Patton-Calling-Lost-Tx-Packets",
                            "Patton-Calling-Lost-Rx-Packets",
                            "Patton-Calling-Rx-Jitter",
                            "Patton-Calling-Tx-Jitter",
                            "Patton-Calling-Codec",
                            "Patton-Calling-Remote-Ip",
                            "Patton-Calling-Remote-Udp-Port",
                            "Patton-Calling-Local-Udp-Port",
                            "Patton-Calling-Qos",
                            "Patton-Calling-MOS",
                            "Patton-Calling-Round-Trip-Time",
                            "Perle-Clustered-Port-Access",
                            "Perle-User-Level",
                            "Perle-Line-Access-Port-1",
                            "Perle-Line-Access-Port-2",
                            "Perle-Line-Access-Port-3",
                            "Perle-Line-Access-Port-4",
                            "Perle-Line-Access-Port-5",
                            "Perle-Line-Access-Port-6",
                            "Perle-Line-Access-Port-7",
                            "Perle-Line-Access-Port-8",
                            "Perle-Line-Access-Port-9",
                            "Perle-Line-Access-Port-10",
                            "Perle-Line-Access-Port-11",
                            "Perle-Line-Access-Port-12",
                            "Perle-Line-Access-Port-13",
                            "Perle-Line-Access-Port-14",
                            "Perle-Line-Access-Port-15",
                            "Perle-Line-Access-Port-16",
                            "Perle-Line-Access-Port-17",
                            "Perle-Line-Access-Port-18",
                            "Perle-Line-Access-Port-19",
                            "Perle-Line-Access-Port-20",
                            "Perle-Line-Access-Port-21",
                            "Perle-Line-Access-Port-22",
                            "Perle-Line-Access-Port-23",
                            "Perle-Line-Access-Port-24",
                            "Perle-Line-Access-Port-25",
                            "Perle-Line-Access-Port-26",
                            "Perle-Line-Access-Port-27",
                            "Perle-Line-Access-Port-28",
                            "Perle-Line-Access-Port-29",
                            "Perle-Line-Access-Port-30",
                            "Perle-Line-Access-Port-31",
                            "Perle-Line-Access-Port-32",
                            "Perle-Line-Access-Port-33",
                            "Perle-Line-Access-Port-34",
                            "Perle-Line-Access-Port-35",
                            "Perle-Line-Access-Port-36",
                            "Perle-Line-Access-Port-37",
                            "Perle-Line-Access-Port-38",
                            "Perle-Line-Access-Port-39",
                            "Perle-Line-Access-Port-40",
                            "Perle-Line-Access-Port-41",
                            "Perle-Line-Access-Port-42",
                            "Perle-Line-Access-Port-43",
                            "Perle-Line-Access-Port-44",
                            "Perle-Line-Access-Port-45",
                            "Perle-Line-Access-Port-46",
                            "Perle-Line-Access-Port-47",
                            "Perle-Line-Access-Port-48",
                            "Perle-Line-Access-Port-49",
                            "Propel-Accelerate",
                            "Propel-Dialed-Digits",
                            "Propel-Client-IP-Address",
                            "Propel-Client-NAS-IP-Address",
                            "Propel-Client-Source-ID",
                            "Propel-Content-Filter-ID",
                            "Prosoft-Home-Agent-Address",
                            "Prosoft-Default-Gateway",
                            "Prosoft-Primary-DNS",
                            "Prosoft-Secondary-DNS",
                            "Prosoft-Security-Parameter-Index",
                            "Prosoft-Security-Key",
                            "Prosoft-MAC-Address",
                            "Prosoft-Authentication-Reason",
                            "Prosoft-ATM-Interface",
                            "Prosoft-ATM-VPI",
                            "Prosoft-ATM-VCI",
                            "Prosoft-RSC-Identifier",
                            "Prosoft-NPM-Identifier",
                            "Prosoft-NPM-IP",
                            "Prosoft-Sector-ID",
                            "Prosoft-Auth-Role",
                            "Proxim_E1_VLAN_MODE",
                            "Proxim_SU_VLAN_NAME",
                            "Proxim_E1_Access_VLAN_ID",
                            "Proxim_E1_Access_VLAN_Pri",
                            "Proxim_Mgmt_VLAN_ID",
                            "Proxim_Mgmt_VLAN_Pri",
                            "Proxim_E1_TrunkID_01",
                            "Proxim_E1_TrunkID_02",
                            "Proxim_E1_TrunkID_03",
                            "Proxim_E1_TrunkID_04",
                            "Proxim_E1_TrunkID_05",
                            "Proxim_E1_TrunkID_06",
                            "Proxim_E1_TrunkID_07",
                            "Proxim_E1_TrunkID_08",
                            "Proxim_E1_TrunkID_09",
                            "Proxim_E1_TrunkID_10",
                            "Proxim_E1_TrunkID_11",
                            "Proxim_E1_TrunkID_12",
                            "Proxim_E1_TrunkID_13",
                            "Proxim_E1_TrunkID_14",
                            "Proxim_E1_TrunkID_15",
                            "Proxim_E1_TrunkID_16",
                            "Proxim_SU_VLAN_Table_Status",
                            "Proxim_Service_VLAN_ID",
                            "Proxim_Service_VLAN_Pri",
                            "Proxim_QoS_Class_Index",
                            "Proxim_QoS_Class_SU_Status",
                            "Proxim_E2_VLAN_MODE",
                            "Proxim_E2_Access_VLAN_ID",
                            "Proxim_E2_Access_VLAN_Pri",
                            "Proxim_E2_TrunkID_01",
                            "Proxim_E2_TrunkID_02",
                            "Proxim_E2_TrunkID_03",
                            "Proxim_E2_TrunkID_04",
                            "Proxim_E2_TrunkID_05",
                            "Proxim_E2_TrunkID_06",
                            "Proxim_E2_TrunkID_07",
                            "Proxim_E2_TrunkID_08",
                            "Proxim_E2_TrunkID_09",
                            "Proxim_E2_TrunkID_10",
                            "Proxim_E2_TrunkID_11",
                            "Proxim_E2_TrunkID_12",
                            "Proxim_E2_TrunkID_13",
                            "Proxim_E2_TrunkID_14",
                            "Proxim_E2_TrunkID_15",
                            "Proxim_E2_TrunkID_16",
                            "Proxim_QinQ_Status",
                            "Proxim_Service_VLAN_TPID",
                            "Proxim_E1_Port_VLAN_ID",
                            "Proxim_E1_Port_VLAN_Pri",
                            "Proxim_E1_Allow_Untag",
                            "Proxim_E2_Port_VLAN_ID",
                            "Proxim_E2_Port_VLAN_Pri",
                            "Proxim_E2_Allow_Untag",
                            "Proxim_E1_SU_Allow_Untag_Mgmt",
                            "Proxim_E2_SU_Allow_Untag_Mgmt",
                            "Purewave-Client-Profile",
                            "Purewave-CS-Type",
                            "Purewave-Max-Downlink-Rate",
                            "Purewave-Max-Uplink-Rate",
                            "Purewave-IP-Address",
                            "Purewave-IP-Netmask",
                            "Purewave-Service-Enable",
                            "Quiconnect-AVPair",
                            "Quiconnect-VNP-Information",
                            "Quiconnect-HSP-Information",
                            "Quintum-AVPair",
                            "Quintum-NAS-Port",
                            "Quintum-h323-remote-address",
                            "Quintum-h323-conf-id",
                            "Quintum-h323-setup-time",
                            "Quintum-h323-call-origin",
                            "Quintum-h323-call-type",
                            "Quintum-h323-connect-time",
                            "Quintum-h323-disconnect-time",
                            "Quintum-h323-disconnect-cause",
                            "Quintum-h323-voice-quality",
                            "Quintum-h323-gw-id",
                            "Quintum-h323-incoming-conf-id",
                            "Quintum-h323-credit-amount",
                            "Quintum-h323-credit-time",
                            "Quintum-h323-return-code",
                            "Quintum-h323-prompt-id",
                            "Quintum-h323-time-and-day",
                            "Quintum-h323-redirect-number",
                            "Quintum-h323-preferred-lang",
                            "Quintum-h323-redirect-ip-address",
                            "Quintum-h323-billing-model",
                            "Quintum-h323-currency-type",
                            "Quintum-Trunkid-In",
                            "Quintum-Trunkid-Out",
                            "RedCreek-Tunneled-IP-Addr",
                            "RedCreek-Tunneled-IP-Netmask",
                            "RedCreek-Tunneled-Gateway",
                            "RedCreek-Tunneled-DNS-Server",
                            "RedCreek-Tunneled-WINS-Server1",
                            "RedCreek-Tunneled-WINS-Server2",
                            "RedCreek-Tunneled-HostName",
                            "RedCreek-Tunneled-DomainName",
                            "RedCreek-Tunneled-Search-List",
                            "Riverbed-Local-User",
                            "Riverstone-Command",
                            "Riverstone-System-Event",
                            "Riverstone-SNMP-Config-Change",
                            "Riverstone-User-Level",
                            "RP-Upstream-Speed-Limit",
                            "RP-Downstream-Speed-Limit",
                            "RP-HURL",
                            "RP-MOTM",
                            "RP-Max-Sessions-Per-User",
                            "RuggedCom-Privilege-level",
                            "Ruckus-User-Groups",
                            "Ruckus-Sta-RSSI",
                            "Ruckus-SSID",
                            "Ruckus-Wlan-Id",
                            "Ruckus-Location",
                            "Ruckus-Grace-Period",
                            "Ruckus-SCG-CBlade-IP",
                            "Ruckus-SCG-DBlade-IP",
                            "Ruckus-VLAN-ID",
                            "Ruckus-Sta-Expiration",
                            "Ruckus-Sta-UUID",
                            "Ruckus-Accept-Enhancement-Reason",
                            "Ruckus-Sta-Inner-Id",
                            "Ruckus-BSSID",
                            "Ruckus-WSG-User",
                            "Ruckus-Triplets",
                            "Ruckus-IMSI",
                            "Ruckus-MSISDN",
                            "Ruckus-APN-NI",
                            "Ruckus-QoS",
                            "Ruckus-Selection-Mode",
                            "Ruckus-APN-Resolution-Req",
                            "Ruckus-Start-Time",
                            "Ruckus-NAS-Type",
                            "Ruckus-Status",
                            "Ruckus-APN-OI",
                            "Ruckus-Auth-Type",
                            "Ruckus-Gn-User-Name",
                            "Ruckus-Brand-Code",
                            "Ruckus-Policy-Name",
                            "Ruckus-Client-Local-IP",
                            "Ruckus-SGSN-IP",
                            "Ruckus-Charging-Charac",
                            "Ruckus-PDP-Type",
                            "Ruckus-Dynamic-Address-Flag",
                            "Ruckus-ChCh-Selection-Mode",
                            "Ruckus-AAA-IP",
                            "Ruckus-CDR-TYPE",
                            "Ruckus-SGSN-Number",
                            "Ruckus-Session-Type",
                            "Ruckus-Accounting-Status",
                            "Ruckus-Zone-Id",
                            "Ruckus-Auth-Server-Id",
                            "Ruckus-Utp-Id",
                            "Ruckus-Area-Code",
                            "Ruckus-Cell-Identifier",
                            "Ruckus-Wispr-Redirect-Policy",
                            "Ruckus-Eth-Profile-Id",
                            "Ruckus-Zone-Name",
                            "Ruckus-Wlan-Name",
                            "Ruckus-Read-Preference",
                            "Ruckus-Client-Host-Name",
                            "Ruckus-Client-Os-Type",
                            "Ruckus-Client-Os-Class",
                            "Ruckus-Vlan-Pool",
                            "NetBorder-AVPair",
                            "NetBorder-CLID",
                            "NetBorder-Dialplan",
                            "NetBorder-Src",
                            "NetBorder-Dst",
                            "NetBorder-Src-Channel",
                            "NetBorder-Dst-Channel",
                            "NetBorder-Ani",
                            "NetBorder-Aniii",
                            "NetBorder-Lastapp",
                            "NetBorder-Lastdata",
                            "NetBorder-Disposition",
                            "NetBorder-Hangupcause",
                            "NetBorder-Billusec",
                            "NetBorder-AMAFlags",
                            "NetBorder-RDNIS",
                            "NetBorder-Context",
                            "NetBorder-Source",
                            "NetBorder-Callstartdate",
                            "NetBorder-Callanswerdate",
                            "NetBorder-Calltransferdate",
                            "NetBorder-Callenddate",
                            "NetBorder-Signalbond",
                            "Shasta-User-Privilege",
                            "Shasta-Service-Profile",
                            "Shasta-VPN-Name",
                            "SG-Filter-Redirect-Gw",
                            "SG-Accounting",
                            "SG-Orig-Name",
                            "SG-Auth-Type",
                            "SG-Action",
                            "SG-SSC-Host",
                            "SG-Service-Name",
                            "SG-Personal-Site",
                            "SG-Mac-Address",
                            "SG-User-Group",
                            "SG-Max-Allowed-Sessions",
                            "SG-Class",
                            "SG-Eds-Enc-Key",
                            "SG-Eds-Cookie",
                            "SG-Original-Url-Prefix",
                            "SG-Max-Allowed-Nodes",
                            "SG-Parent-User-Name",
                            "SG-Node-Group",
                            "SG-Node-Default-Service",
                            "SG-Node-Dynamic-Service",
                            "SG-Dhcp-Server",
                            "SG-Opt82-Relay-Remote-Id",
                            "SG-Discover-Action",
                            "SG-Release-Action",
                            "SG-Fixed-Ip-Address",
                            "SG-Node-Fixed-Ip-Address",
                            "SG-Lease-Time",
                            "SG-Protocol-Type",
                            "SG-Service-Timeout",
                            "SG-Next-Service-Name",
                            "SG-Auto-Service-Name",
                            "SG-Auth-Source",
                            "SG-Data-Quota",
                            "SG-Acl-Data-Quota",
                            "SG-Service-Cache",
                            "SG-Data-Quota-Used",
                            "SG-Acl-Data-Quota-Used",
                            "SG-Acl-Packet-Quota",
                            "SG-Acl-Packet-Quota-Used",
                            "SG-Roaming",
                            "SG-Acl-Eds-Action",
                            "SG-Acl-Idle-Ignore",
                            "SG-Service-Quota-Ignore",
                            "SG-Service-Acl-Quota-Ignore",
                            "SG-Service-Acl-Quota-Indication",
                            "SG-Remote-Filter-Redirect-Gw",
                            "SG-Next-Hop",
                            "SG-Nip-Pipe-Next-Hop",
                            "SG-Advertise-Protocol",
                            "SG-Forward-Addr",
                            "SG-Acl-Tcp-Nat-Redirect",
                            "SG-Acl-Next-Hop",
                            "SG-Tunnel-Id",
                            "SG-L2tp-Tunnel-Password",
                            "SG-Ip-Address",
                            "SG-Tunnel-Assignment-Id",
                            "SG-Tunnel-Client-Ip-Address",
                            "SG-Nativeip",
                            "SG-Ip-Tunnel",
                            "SG-Up-Mean-Rate",
                            "SG-Down-Mean-Rate",
                            "SG-Acl-Up-Mean-Rate",
                            "SG-Acl-Down-Mean-Rate",
                            "SG-Cos",
                            "SG-Acl-Priority",
                            "SG-Burst-Size",
                            "SG-Ip-Primary",
                            "SG-Ip-Secondary",
                            "SG-Wimax-Reduced-Resources",
                            "SG-Wimax-Acl-Schedule-Type",
                            "SG-Wimax-Acl-Min-Reserved-Traffic-Rate",
                            "SG-Wimax-Acl-Maximum-Traffic-Burst",
                            "SG-Wimax-Acl-Tolerated-Jitter",
                            "SG-Wimax-Acl-Maximum-Latency",
                            "SG-Wimax-Acl-Unsolicited-Grant-Int",
                            "SG-Wimax-Acl-Sdu-Size",
                            "SG-Wimax-Acl-Unsolicited-Polling-Int",
                            "SG-Wimax-MSK-Lifetime",
                            "SG-Wimax-DM-Action-Code",
                            "SG-Wimax-Acl-ARQ-Enable",
                            "SG-Wimax-Bsid-Next-Hop",
                            "SG-Wimax-Mobility-Features-Supported",
                            "SG-Wimax-Node-Disconnect",
                            "SG-Wimax-Service-Flow-Modification",
                            "SG-Wimax-Service-Flow-Down",
                            "SG-Node-Acct-Username",
                            "Shiva-User-Attributes",
                            "Shiva-Compression",
                            "Shiva-Dialback-Delay",
                            "Shiva-Call-Durn-Trap",
                            "Shiva-Bandwidth-Trap",
                            "Shiva-Minimum-Call",
                            "Shiva-Default-Host",
                            "Shiva-Menu-Name",
                            "Shiva-User-Flags",
                            "Shiva-Termtype",
                            "Shiva-Break-Key",
                            "Shiva-Fwd-Key",
                            "Shiva-Bak-Key",
                            "Shiva-Dial-Timeout",
                            "Shiva-LAT-Port",
                            "Shiva-Max-VCs",
                            "Shiva-DHCP-Leasetime",
                            "Shiva-LAT-Groups",
                            "Shiva-RTC-Timestamp",
                            "Shiva-Circuit-Type",
                            "Shiva-Called-Number",
                            "Shiva-Calling-Number",
                            "Shiva-Customer-Id",
                            "Shiva-Type-Of-Service",
                            "Shiva-Link-Speed",
                            "Shiva-Links-In-Bundle",
                            "Shiva-Compression-Type",
                            "Shiva-Link-Protocol",
                            "Shiva-Network-Protocols",
                            "Shiva-Session-Id",
                            "Shiva-Disconnect-Reason",
                            "Shiva-Acct-Serv-Switch",
                            "Shiva-Event-Flags",
                            "Shiva-Function",
                            "Shiva-Connect-Reason",
                            "Siemens-URL-Redirection",
                            "Siemens-AP-Name",
                            "Siemens-AP-Serial",
                            "Siemens-VNS-Name",
                            "Siemens-SSID",
                            "Siemens-BSS-MAC",
                            "Siemens-Policy-Name",
                            "Siemens-Topology-Name",
                            "Siemens-Ingress-RC-Name",
                            "Siemens-Egress-RC-Name",
                            "Slipstream-Auth",
                            "SofaWare-Admin",
                            "SofaWare-VPN",
                            "SofaWare-Hotspot",
                            "SofaWare-UFP",
                            "SoftBank-BB-Unit-MAC",
                            "SoftBank-BB-Unit-Manufacturer",
                            "SoftBank-BB-Unit-Model",
                            "SoftBank-BB-Unit-HW-Revision",
                            "SoftBank-TFTP-Config-Server",
                            "SoftBank-TFTP-Config-File",
                            "SoftBank-DNS-IPv6-Primary",
                            "SoftBank-DNS-IPv6-Secondary",
                            "SoftBank-Syslog-Server",
                            "SoftBank-SNTP-Server",
                            "SoftBank-IPv4-Tunnel-Local-Address",
                            "SoftBank-IPv4-Tunnel-Endpoint",
                            "SoftBank-RouteInfo-Server",
                            "SS3-Firewall-User-Privilege",
                            "SonicWall-User-Privilege",
                            "SonicWall-User-Group",
                            "ST-Acct-VC-Connection-Id",
                            "ST-Service-Name",
                            "ST-Service-Domain",
                            "ST-Policy-Name",
                            "ST-Primary-DNS-Server",
                            "ST-Secondary-DNS-Server",
                            "ST-Primary-NBNS-Server",
                            "ST-Secondary-NBNS-Server",
                            "ST-Physical-Port",
                            "ST-Physical-Slot",
                            "ST-Virtual-Path-ID",
                            "ST-Virtual-Circuit-ID",
                            "ST-Realm-Name",
                            "ST-IPSec-Pfs-Group",
                            "ST-IPSec-Client-Firewall",
                            "ST-IPSec-Client-Subnet",
                            "SN-VPN-ID",
                            "SN-VPN-Name",
                            "SN-Disconnect-Reason",
                            "SN-PPP-Progress-Code",
                            "SN-Primary-DNS-Server",
                            "SN-Secondary-DNS-Server",
                            "SN-Re-CHAP-Interval",
                            "SN-IP-Pool-Name",
                            "SN-PPP-Data-Compression",
                            "SN-IP-Filter-In",
                            "SN-IP-Filter-Out",
                            "SN-Local-IP-Address",
                            "SN-IP-Source-Validation",
                            "SN-PPP-Outbound-Password",
                            "SN-PPP-Keepalive",
                            "SN-IP-In-ACL",
                            "SN-IP-Out-ACL",
                            "SN-PPP-Data-Compression-Mode",
                            "SN-Subscriber-Permission",
                            "SN-Admin-Permission",
                            "SN-Simultaneous-SIP-MIP",
                            "SN-Min-Compress-Size",
                            "SN-Service-Type",
                            "SN-DNS-Proxy-Use-Subscr-Addr",
                            "SN-Tunnel-Password",
                            "SN-Tunnel-Load-Balancing",
                            "SN-MN-HA-Timestamp-Tolerance",
                            "SN-Prepaid-Compressed-Count",
                            "SN-Prepaid-Inbound-Octets",
                            "SN-Prepaid-Outbound-Octets",
                            "SN-Prepaid-Total-Octets",
                            "SN-Prepaid-Timeout",
                            "SN-Prepaid-Watermark",
                            "SN-NAI-Construction-Domain",
                            "SN-Tunnel-ISAKMP-Crypto-Map",
                            "SN-Tunnel-ISAKMP-Secret",
                            "SN-Ext-Inline-Srvr-Context",
                            "SN-L3-to-L2-Tun-Addr-Policy",
                            "SN-Long-Duration-Timeout",
                            "SN-Long-Duration-Action",
                            "SN-PDSN-Handoff-Req-IP-Addr",
                            "SN-HA-Send-DNS-ADDRESS",
                            "SN-MIP-Send-Term-Verification",
                            "SN-Data-Tunnel-Ignore-DF-Bit",
                            "SN-MIP-AAA-Assign-Addr",
                            "SN-Proxy-MIP",
                            "SN-MIP-Match-AAA-Assign-Addr",
                            "SN-IP-Alloc-Method",
                            "SN-Gratuitous-ARP-Aggressive",
                            "SN-Ext-Inline-Srvr-Up-Addr",
                            "SN-Ext-Inline-Srvr-Down-Addr",
                            "SN-Ext-Inline-Srvr-Preference",
                            "SN-Ext-Inline-Srvr-Up-VLAN",
                            "SN-Ext-Inline-Srvr-Down-VLAN",
                            "SN-IP-Hide-Service-Address",
                            "SN-PPP-Outbound-Username",
                            "SN-GTP-Version",
                            "SN-Access-link-IP-Frag",
                            "SN-Subscriber-Accounting",
                            "SN-Nw-Reachability-Server-Name",
                            "SN-Subscriber-IP-Hdr-Neg-Mode",
                            "SN-GGSN-MIP-Required",
                            "SN-Subscriber-Acct-Start",
                            "SN-Subscriber-Acct-Interim",
                            "SN-Subscriber-Acct-Stop",
                            "SN-QoS-Tp-Dnlk",
                            "SN-Tp-Dnlk-Committed-Data-Rate",
                            "SN-Tp-Dnlk-Peak-Data-Rate",
                            "SN-Tp-Dnlk-Burst-Size",
                            "SN-Tp-Dnlk-Exceed-Action",
                            "SN-Tp-Dnlk-Violate-Action",
                            "SN-QoS-Tp-Uplk",
                            "SN-Tp-Uplk-Committed-Data-Rate",
                            "SN-Tp-Uplk-Peak-Data-Rate",
                            "SN-Tp-Uplk-Burst-Size",
                            "SN-Tp-Uplk-Exceed-Action",
                            "SN-Tp-Uplk-Violate-Action",
                            "SN-Subscriber-IP-TOS-Copy",
                            "SN-QoS-Conversation-Class",
                            "SN-QoS-Streaming-Class",
                            "SN-QoS-Interactive1-Class",
                            "SN-QoS-Interactive2-Class",
                            "SN-QoS-Interactive3-Class",
                            "SN-QoS-Background-Class",
                            "SN-PPP-NW-Layer-IPv4",
                            "SN-PPP-NW-Layer-IPv6",
                            "SN-Virtual-APN-Name",
                            "SN-PPP-Accept-Peer-v6Ifid",
                            "SN-IPv6-rtr-advt-interval",
                            "SN-IPv6-num-rtr-advt",
                            "SN-NPU-Qos-Priority",
                            "SN-MN-HA-Hash-Algorithm",
                            "SN-Subscriber-Acct-Rsp-Action",
                            "SN-IPv6-Primary-DNS",
                            "SN-IPv6-Secondary-DNS",
                            "SN-IPv6-Egress-Filtering",
                            "SN-Mediation-VPN-Name",
                            "SN-Mediation-Acct-Rsp-Action",
                            "SN-Home-Sub-Use-GGSN",
                            "SN-Visiting-Sub-Use-GGSN",
                            "SN-Roaming-Sub-Use-GGSN",
                            "SN-Home-Profile",
                            "SN-IP-Src-Validation-Drop-Limit",
                            "SN-QoS-Class-Conversational-PHB",
                            "SN-QoS-Class-Streaming-PHB",
                            "SN-QoS-Class-Background-PHB",
                            "SN-QoS-Class-Interactive-1-PHB",
                            "SN-QoS-Class-Interactive-2-PHB",
                            "SN-QoS-Class-Interactive-3-PHB",
                            "SN-Visiting-Profile",
                            "SN-Roaming-Profile",
                            "SN-Home-Behavior",
                            "SN-Visiting-Behavior",
                            "SN-Roaming-Behavior",
                            "SN-Internal-SM-Index",
                            "SN-Mediation-Enabled",
                            "SN-IPv6-Sec-Pool",
                            "SN-IPv6-Sec-Prefix",
                            "SN-IPv6-DNS-Proxy",
                            "SN-Subscriber-Nexthop-Address",
                            "SN-Prepaid",
                            "SN-Prepaid-Preference",
                            "SN-PPP-Always-On-Vse",
                            "SN-Voice-Push-List-Name",
                            "SN-Unclassify-List-Name",
                            "SN-Subscriber-No-Interims",
                            "SN-Permit-User-Mcast-PDUs",
                            "SN-Prepaid-Final-Duration-Alg",
                            "SN-IPv6-Min-Link-MTU",
                            "SN-Charging-VPN-Name",
                            "SN-Chrg-Char-Selection-Mode",
                            "SN-Cause-For-Rec-Closing",
                            "SN-Change-Condition",
                            "SN-Dynamic-Addr-Alloc-Ind-Flag",
                            "SN-Ntk-Initiated-Ctx-Ind-Flag",
                            "SN-Ntk-Session-Disconnect-Flag",
                            "SN-Enable-QoS-Renegotiation",
                            "SN-QoS-Renegotiation-Timeout",
                            "SN-QoS-Negotiated",
                            "SN-Mediation-No-Interims",
                            "SN-Primary-NBNS-Server",
                            "SN-Secondary-NBNS-Server",
                            "SN-IP-Header-Compression",
                            "SN-Mode",
                            "SN-Assigned-VLAN-ID",
                            "SN-Direction",
                            "SN-MIP-HA-Assignment-Table",
                            "SN-Tun-Addr-Policy",
                            "SN-DHCP-Lease-Expiry-Policy",
                            "SN-Subscriber-Template-Name",
                            "SN-Subs-IMSA-Service-Name",
                            "SN-Traffic-Group",
                            "SN-Rad-APN-Name",
                            "SN-MIP-Send-Ancid",
                            "SN-MIP-Send-Imsi",
                            "SN-MIP-Dual-Anchor",
                            "SN-MIP-ANCID",
                            "SN-IMS-AM-Address",
                            "SN-IMS-AM-Domain-Name",
                            "SN-Service-Address",
                            "SN-PDIF-MIP-Required",
                            "SN-FMC-Location",
                            "SN-PDIF-MIP-Release-TIA",
                            "SN-PDIF-MIP-Simple-IP-Fallback",
                            "SN-Tunnel-Gn",
                            "SN-MIP-Reg-Lifetime-Realm",
                            "SN-Ecs-Data-Volume",
                            "SN-QoS-Traffic-Policy",
                            "SN-ANID",
                            "SN-PPP-Reneg-Disc",
                            "SN-MIP-Send-Correlation-Info",
                            "SN-PDSN-Correlation-Id",
                            "SN-PDSN-NAS-Id",
                            "SN-PDSN-NAS-IP-Address",
                            "SN-Subscriber-Acct-Mode",
                            "SN-IP-In-Plcy-Grp",
                            "SN-IP-Out-Plcy-Grp",
                            "SN-IP-Source-Violate-No-Acct",
                            "SN-Firewall-Enabled",
                            "SNA-PPP-Unfr-data-In-Oct",
                            "SNA-PPP-Unfr-data-Out-Oct",
                            "SNA-PPP-Unfr-Data-In-Gig",
                            "SNA-PPP-Unfr-Data-Out-Gig",
                            "SN-Admin-Expiry",
                            "SNA-Input-Gigawords",
                            "SNA-Output-Gigawords",
                            "SN-DNS-Proxy-Intercept-List",
                            "SN-Subscriber-Class",
                            "SN-CFPolicy-ID",
                            "SN-Subs-VJ-Slotid-Cmp-Neg-Mode",
                            "SN-Primary-DCCA-Peer",
                            "SN-Secondary-DCCA-Peer",
                            "SN-Subs-Acc-Flow-Traffic-Valid",
                            "SN-Acct-Input-Packets-Dropped",
                            "SN-Acct-Output-Packets-Dropped",
                            "SN-Acct-Input-Octets-Dropped",
                            "SN-Acct-Output-Octets-Dropped",
                            "SN-Acct-Input-Giga-Dropped",
                            "SN-Acct-Output-Giga-Dropped",
                            "SN-Overload-Disc-Connect-Time",
                            "SN-Overload-Disconnect",
                            "SN-Radius-Returned-Username",
                            "SN-ROHC-Profile-Name",
                            "SN-Firewall-Policy",
                            "SN-Transparent-Data",
                            "SN-MS-ISDN",
                            "SN-Routing-Area-Id",
                            "SN-Rulebase",
                            "SN-Call-Id",
                            "SN-IMSI",
                            "SN-Long-Duration-Notification",
                            "SN-SIP-Method",
                            "SN-Event",
                            "SN-Role-Of-Node",
                            "SN-Session-Id",
                            "SN-SIP-Request-Time-Stamp",
                            "SN-SIP-Response-Time-Stamp",
                            "SN-IMS-Charging-Identifier",
                            "SN-Originating-IOI",
                            "SN-Terminating-IOI",
                            "SN-SDP-Session-Description",
                            "SN-GGSN-Address",
                            "SN-Sec-IP-Pool-Name",
                            "SN-Authorised-Qos",
                            "SN-Cause-Code",
                            "SN-Node-Functionality",
                            "SN-Is-Unregistered-Subscriber",
                            "SN-Content-Type",
                            "SN-Content-Length",
                            "SN-Content-Disposition",
                            "SN-CSCF-Rf-SDP-Media-Components",
                            "SN-ROHC-Flow-Marking-Mode",
                            "SN-CSCF-App-Server-Info",
                            "SN-ISC-Template-Name",
                            "SN-CF-Forward-Unconditional",
                            "SN-CF-Forward-No-Answer",
                            "SN-CF-Forward-Busy-Line",
                            "SN-CF-Forward-Not-Regd",
                            "SN-CF-Follow-Me",
                            "SN-CF-CId-Display",
                            "SN-CF-CId-Display-Blocked",
                            "SN-CF-Call-Waiting",
                            "SN-CF-Call-Transfer",
                            "SN-Cscf-Subscriber-Ip-Address",
                            "SN-Software-Version",
                            "SN-Max-Sec-Contexts-Per-Subs",
                            "SN-CF-Call-Local",
                            "SN-CF-Call-LongDistance",
                            "SN-CF-Call-International",
                            "SN-CF-Call-Premium",
                            "SN-CR-International-Cid",
                            "SN-CR-LongDistance-Cid",
                            "SN-NAT-IP-Address",
                            "SN-CF-Call-RoamingInternatnl",
                            "SN-PDG-TTG-Required",
                            "SN-Bandwidth-Policy",
                            "SN-Acs-Credit-Control-Group",
                            "SN-CBB-Policy",
                            "SN-QOS-HLR-Profile",
                            "SN-Fast-Reauth-Username",
                            "SN-Pseudonym-Username",
                            "SN-WiMAX-Auth-Only",
                            "SN-TrafficSelector-Class",
                            "SN-DHCP-Options",
                            "SN-Handoff-Indicator",
                            "SN-User-Privilege",
                            "SN-IPv6-Alloc-Method",
                            "SN-Congestion-Mgmt-Policy",
                            "SN-WSG-MIP-Required",
                            "SN-WSG-MIP-Release-TIA",
                            "SN-WSG-MIP-Simple-IP-Fallback",
                            "SN-WLAN-AP-Identifier",
                            "SN-WLAN-UE-Identifier",
                            "SNA-PPP-Ctrl-Input-Octets",
                            "SNA-PPP-Ctrl-Output-Octets",
                            "SNA-PPP-Ctrl-Input-Packets",
                            "SNA-PPP-Ctrl-Output-Packets",
                            "SNA-PPP-Framed-Input-Octets",
                            "SNA-PPP-Framed-Output-Octets",
                            "SNA-PPP-Discards-Input",
                            "SNA-PPP-Discards-Output",
                            "SNA-PPP-Errors-Input",
                            "SNA-PPP-Errors-Output",
                            "SNA-PPP-Bad-Addr",
                            "SNA-PPP-Bad-Ctrl",
                            "SNA-PPP-Packet-Too-Long",
                            "SNA-PPP-Bad-FCS",
                            "SNA-PPP-Echo-Req-Input",
                            "SNA-PPP-Echo-Req-Output",
                            "SNA-PPP-Echo-Rsp-Input",
                            "SNA-PPP-Echo-Rsp-Output",
                            "SNA-RPRRQ-Rcvd-Total",
                            "SNA-RPRRQ-Rcvd-Acc-Reg",
                            "SNA-RPRRQ-Rcvd-Acc-Dereg",
                            "SNA-RPRRQ-Rcvd-Msg-Auth-Fail",
                            "SNA-RPRRQ-Rcvd-Mis-ID",
                            "SNA-RPRRQ-Rcvd-Badly-Formed",
                            "SNA-RPRRQ-Rcvd-VID-Unsupported",
                            "SNA-RPRRQ-Rcvd-T-Bit-Not-Set",
                            "SNA-RPRAK-Rcvd-Total",
                            "SNA-RPRAK-Rcvd-Acc-Ack",
                            "SNA-RPRAK-Rcvd-Msg-Auth-Fail",
                            "SNA-RPRAK-Rcvd-Mis-ID",
                            "SNA-RP-Reg-Reply-Sent-Total",
                            "SNA-RP-Reg-Reply-Sent-Acc-Reg",
                            "SNA-RP-Reg-Reply-Sent-Acc-Dereg",
                            "SNA-RP-Reg-Reply-Sent-Bad-Req",
                            "SNA-RP-Reg-Reply-Sent-Denied",
                            "SNA-RP-Reg-Reply-Sent-Mis-ID",
                            "SNA-RP-Reg-Reply-Sent-Send-Err",
                            "SNA-RP-Reg-Upd-Sent",
                            "SNA-RP-Reg-Upd-Re-Sent",
                            "SNA-RP-Reg-Upd-Send-Err",
                            "SN-Proxy-MIPV6",
                            "Surfnet-AVPair",
                            "Surfnet-Service-Identifier",
                            "Surfnet-Service-Provider",
                            "Symbol-Admin-Role",
                            "Symbol-Current-ESSID",
                            "Symbol-Allowed-ESSID",
                            "Symbol-WLAN-Index",
                            "Symbol-QoS-Profile",
                            "Symbol-Allowed-Radio",
                            "Symbol-Expiry-Date-Time",
                            "Symbol-Start-Date-Time",
                            "Symbol-Posture-Status",
                            "Symbol-Downlink-Limit",
                            "Symbol-Uplink-Limit",
                            "Symbol-User-Group",
                            "Symbol-Login-Source",
                            "Telebit-Login-Command",
                            "Telebit-Port-Name",
                            "Telebit-Activate-Command",
                            "Telebit-Accounting-Info",
                            "Telebit-Login-Option",
                            "Eduroam-SP-Country",
                            "Eduroam-Monitoring-Inflate",
                            "Trapeze-VLAN-Name",
                            "Trapeze-Mobility-Profile",
                            "Trapeze-Encryption-Type",
                            "Trapeze-Time-Of-Day",
                            "Trapeze-SSID",
                            "Trapeze-End-Date",
                            "Trapeze-Start-Date",
                            "Trapeze-URL",
                            "Trapeze-User-Group-Name",
                            "Trapeze-QoS-Profile",
                            "Trapeze-Simultaneous-Logins",
                            "Trapeze-CoA-Username",
                            "Trapeze-Audit",
                            "TP-Gateway-Version",
                            "TP-Firmware-Variant",
                            "TP-Firmware-Version",
                            "TP-Gateway-Config",
                            "TP-ENC-IV",
                            "TP-Password",
                            "TP-User-Agent",
                            "TP-Auth-Reply",
                            "TP-Access-Class-Id",
                            "TP-Host-Name",
                            "TP-DHCP-Request-Option-List",
                            "TP-DHCP-Parameter-Request-List",
                            "TP-DHCP-Vendor-Class-Id",
                            "TP-DHCP-Client-Id",
                            "TP-Location-Id",
                            "TP-NAT-IP-Address",
                            "TP-Zone-Id",
                            "TP-Monitor-Id",
                            "TP-Related-Session-Id",
                            "TP-Monitor-Session-Id",
                            "TP-Max-Input-Octets",
                            "TP-Max-Output-Octets",
                            "TP-Max-Total-Octets",
                            "TP-Exit-Access-Class-Id",
                            "TP-Access-Rule",
                            "TP-Access-Group",
                            "TP-NAT-Pool-Id",
                            "TP-NAT-Port-Start",
                            "TP-NAT-Port-End",
                            "TP-Keep-Alive-Timeout",
                            "TP-TLS-Auth-Type",
                            "TP-TLS-Pre-Shared-Key",
                            "TP-CAPWAP-Timestamp",
                            "TP-CAPWAP-WTP-Version",
                            "TP-CAPWAP-Session-Id",
                            "TP-CAPWAP-Radio-Id",
                            "TP-CAPWAP-WWAN-Id",
                            "TP-CAPWAP-WWAN-RAT",
                            "TP-CAPWAP-WWAN-RSSi",
                            "TP-CAPWAP-WWAN-CREG",
                            "TP-CAPWAP-WWAN-LAC",
                            "TP-CAPWAP-WWAN-Latency",
                            "TP-CAPWAP-WWAN-MCC",
                            "TP-CAPWAP-WWAN-MNC",
                            "TP-CAPWAP-WWAN-Cell-Id",
                            "TP-CAPWAP-POWER-SAVE-IDLE-TIMEOUT",
                            "TP-CAPWAP-POWER-SAVE-BUSY-TIMEOUT",
                            "TP-CAPWAP-SSID",
                            "TP-CAPWAP-Max-WIFI-Clients",
                            "TP-CAPWAP-Walled-Garden",
                            "TP-CAPWAP-GPS-Latitude",
                            "TP-CAPWAP-GPS-Longitude",
                            "TP-CAPWAP-GPS-Altitude",
                            "TP-CAPWAP-GPS-Hdop",
                            "TP-CAPWAP-GPS-Timestamp",
                            "TP-CAPWAP-Hardware-Version",
                            "TP-CAPWAP-Software-Version",
                            "TP-CAPWAP-Boot-Version",
                            "TP-CAPWAP-Other-Software-Version",
                            "Tropos-Unicast-Cipher",
                            "Tropos-Layer2-Input-Octets",
                            "Tropos-Layer2-Output-Octets",
                            "Tropos-Layer2-Input-Frames",
                            "Tropos-Layer2-Output-Frames",
                            "Tropos-Layer2-Input-Drops",
                            "Tropos-Noise-Floor",
                            "Tropos-Noise-Upper-Bound",
                            "Tropos-Release",
                            "Tropos-Secondary-IP",
                            "Tropos-Terminate-Cause",
                            "Tropos-Average-RSSI",
                            "Tropos-Channel",
                            "Tropos-Retries-Sent",
                            "Tropos-Retry-Bits",
                            "Tropos-Rates-Sent",
                            "Tropos-Rates-Received",
                            "Tropos-Routed-Time",
                            "Tropos-Routless-Since",
                            "Tropos-Capability-Info",
                            "Tropos-Input-Cap",
                            "Tropos-Output-Cap",
                            "Tropos-Class-Mult",
                            "Tropos-Cell-Name",
                            "Tropos-Cell-Location",
                            "Tropos-Serial-Number",
                            "Tropos-Latitude",
                            "Tropos-Longitude",
                            "T-Systems-Nova-Location-ID",
                            "T-Systems-Nova-Location-Name",
                            "T-Systems-Nova-Logoff-URL",
                            "T-Systems-Nova-Redirection-URL",
                            "T-Systems-Nova-Bandwidth-Min-Up",
                            "T-Systems-Nova-Bandwidth-Min-Down",
                            "T-Systems-Nova-Bandwidth-Max-Up",
                            "T-Systems-Nova-Bandwidth-Max-Down",
                            "T-Systems-Nova-Session-Terminate-Time",
                            "T-Systems-Nova-Session-Terminate-EoD",
                            "T-Systems-Nova-Billing-Class-Of-Service",
                            "T-Systems-Nova-Service-Name",
                            "T-Systems-Nova-Price-Of-Service",
                            "T-Systems-Nova-Visiting-Provider-Code",
                            "T-Systems-Nova-UnknownAVP",
                            "UKERNA-GSS-Acceptor-Service-Name",
                            "UKERNA-GSS-Acceptor-Host-Name",
                            "UKERNA-GSS-Acceptor-Service-Specific",
                            "UKERNA-GSS-Acceptor-Realm-Name",
                            "SAML-AAA-Assertion",
                            "EAP-Channel-Binding-Message",
                            "Trust-Router-COI",
                            "Trust-Router-APC",
                            "Moonshot-Host-TargetedId",
                            "Moonshot-Realm-TargetedId",
                            "Moonshot-TR-COI-TargetedId",
                            "Moonshot-MSTID-GSS-Acceptor",
                            "Moonshot-MSTID-Namespace",
                            "Moonshot-MSTID-TargetedId",
                            "Moonshot-OTP-Secret",
                            "Unix-FTP-UID",
                            "Unix-FTP-GID",
                            "Unix-FTP-Home",
                            "Unix-FTP-Shell",
                            "Unix-FTP-Group-Names",
                            "Unix-FTP-Group-Ids",
                            "UTStarcom-VLAN-ID",
                            "UTStarcom-CommittedBandwidth",
                            "UTStarcom-MaxBandwidth",
                            "UTStarcom-Priority",
                            "UTStarcom-Error-Reason",
                            "UTStarcom-PrimaryDNS",
                            "UTStarcom-SecondaryDNS",
                            "UTStarcom-MaxBurstSize",
                            "UTStarcom-MaxDelay",
                            "UTStarcom-MaxJitter",
                            "UTStarcom-DeviceId",
                            "UTStarcom-Module-Id",
                            "UTStarcom-Port-No",
                            "UTStarcom-Logical-Port-No",
                            "UTStarcom-UNI-MAX-MAC",
                            "UTStarcom-Default-Gateway",
                            "UTStarcom-CLI-Access-Level",
                            "UTStarcom-Act-Input-Octets",
                            "UTStarcom-Act-Output-Octets",
                            "UTStarcom-Act-Input-Frames",
                            "UTStarcom-Act-Output-Frames",
                            "UTStarcom-Onu-MC-Filter-Enable",
                            "UTStarcom-UNI-Auto-Negotiation",
                            "UTStarcom-UNI-Speed",
                            "UTStarcom-UNI-Duplex",
                            "UTStarcom-ONU-Admin_status",
                            "UTStarcom-ONU-FW-SC-Upgrade",
                            "VNC-PPPoE-CBQ-RX",
                            "VNC-PPPoE-CBQ-TX",
                            "VNC-PPPoE-CBQ-RX-Fallback",
                            "VNC-PPPoE-CBQ-TX-Fallback",
                            "VNC-Splash",
                            "Acct-Interim-Record-Number",
                            "UE-Info-Type",
                            "UE-Info-Value",
                            "Dynamic-Address-Flag",
                            "Local-Seq-Number",
                            "Time-First-Usage",
                            "Time-Last-Usage",
                            "Charging-Group-ID",
                            "Service-Data-Container-Bin",
                            "Service-Data-Container",
                            "Versanet-Termination-Cause",
                            "Waverider-Grade-Of-Service",
                            "Waverider-Priority-Enabled",
                            "Waverider-Authentication-Key",
                            "Waverider-Current-Password",
                            "Waverider-New-Password",
                            "Waverider-Radio-Frequency",
                            "Waverider-SNMP-Read-Community",
                            "Waverider-SNMP-Write-Community",
                            "Waverider-SNMP-Trap-Server",
                            "Waverider-SNMP-Contact",
                            "Waverider-SNMP-Location",
                            "Waverider-SNMP-Name",
                            "Waverider-Max-Customers",
                            "Waverider-Rf-Power",
                            "WB-AUTH-Time-Left",
                            "WB-Auth-Accum-BW",
                            "WB-Auth-BW-Quota",
                            "WB-Auth-BW-Count",
                            "WB-Auth-Upload-Limit",
                            "WB-Auth-Download-Limit",
                            "WB-Auth-Login-Time",
                            "WB-Auth-Logout-Time",
                            "WB-Auth-Time-Diff",
                            "WB-Auth-BW-Usage",
                            "Wichorus-Policy-Name",
                            "Wichorus-User-Privilege",
                            "HS20-Subscription-Remediation-Needed",
                            "HS20-AP-Version",
                            "HS20-Mobile-Device-Version",
                            "HS20-Deauthentication-Request",
                            "HS20-Session-Information-URL",
                            "WiMAX-Capability",
                            "WiMAX-Release",
                            "WiMAX-Accounting-Capabilities",
                            "WiMAX-Hotlining-Capabilities",
                            "WiMAX-Idle-Mode-Notification-Cap",
                            "WiMAX-Device-Authentication-Indicator",
                            "WiMAX-GMT-Timezone-offset",
                            "WiMAX-AAA-Session-Id",
                            "WiMAX-MSK",
                            "WiMAX-hHA-IP-MIP4",
                            "WiMAX-hHA-IP-MIP6",
                            "WiMAX-MN-hHA-MIP4-Key",
                            "WiMAX-MN-hHA-MIP4-SPI",
                            "WiMAX-MN-hHA-MIP6-Key",
                            "WiMAX-MN-hHA-MIP6-SPI",
                            "WiMAX-FA-RK-Key",
                            "WiMAX-HA-RK-Key",
                            "WiMAX-HA-RK-SPI",
                            "WiMAX-HA-RK-Lifetime",
                            "WiMAX-RRQ-MN-HA-Key",
                            "WiMAX-RRQ-MN-HA-SPI",
                            "WiMAX-Session-Continue",
                            "WiMAX-Beginning-Of-Session",
                            "WiMAX-IP-Technology",
                            "WiMAX-Hotline-Indicator",
                            "WiMAX-Prepaid-Indicator",
                            "WiMAX-PDFID",
                            "WiMAX-SDFID",
                            "WiMAX-Packet-Flow-Descriptor",
                            "WiMAX-Packet-Data-Flow-Id",
                            "WiMAX-Service-Data-Flow-Id",
                            "WiMAX-Service-Profile-Id",
                            "WiMAX-Direction",
                            "WiMAX-Activation-Trigger",
                            "WiMAX-Transport-Type",
                            "WiMAX-Uplink-QOS-Id",
                            "WiMAX-Downlink-QOS-Id",
                            "WiMAX-Uplink-Classifier",
                            "WiMAX-Downlink-Classifier",
                            "WiMAX-Classifier",
                            "WiMAX-ClassifierID",
                            "WiMAX-Classifer-Priority",
                            "WiMAX-Classifer-Protocol",
                            "WiMAX-Classifer-Direction",
                            "WiMAX-Source-Specification",
                            "WiMAX-Source-IPAddress",
                            "WiMAX-Source-IPAddressMask",
                            "WiMAX-Source-Port",
                            "WiMAX-Source-Port-Range",
                            "WiMAX-Source-Inverted",
                            "WiMAX-Source-Assigned",
                            "WiMAX-Destination-Specification",
                            "WiMAX-Destination-IPAddress",
                            "WiMAX-Destination-IPAddressMask",
                            "WiMAX-Destination-Port",
                            "WiMAX-Destination-Port-Range",
                            "WiMAX-Destination-Inverted",
                            "WiMAX-Destination-Assigned",
                            "WiMAX-IP-TOS/DSCP-Range-and-Mask",
                            "WiMAX-VLAN-ID",
                            "WiMAX-802.1p",
                            "WiMAX-QoS-Descriptor",
                            "WiMAX-QoS-Id",
                            "WiMAX-Global-Service-Class-Name",
                            "WiMAX-Service-Class-Name",
                            "WiMAX-Schedule-Type",
                            "WiMAX-Traffic-Priority",
                            "WiMAX-Maximum-Sustained-Traffic-Rate",
                            "WiMAX-Minimum-Reserved-Traffic-Rate",
                            "WiMAX-Maximum-Traffic-Burst",
                            "WiMAX-Tolerated-Jitter",
                            "WiMAX-Maximum-Latency",
                            "WiMAX-Reduced-Resources-Code",
                            "WiMAX-Media-Flow-Type",
                            "WiMAX-Unsolicited-Grant-Interval",
                            "WiMAX-SDU-Size",
                            "WiMAX-Unsolicited-Polling-Interval",
                            "WiMAX-Media-Flow-Description-SDP",
                            "WiMAX-R3-IF-Descriptor",
                            "WiMAX-R3-IF-Name",
                            "WiMAX-R3-IF-ID",
                            "WiMAX-IPv4-addr",
                            "WiMAX-IPv4-Netmask",
                            "WiMAX-DGW-IPv4-addr",
                            "WiMAX-DHCP-Option",
                            "WiMAX-Ref-R3-IF-Name",
                            "WiMAX-DHCP-Option-Container",
                            "WiMAX-Uplink-Granted-QoS",
                            "WiMAX-Control-Packets-In",
                            "WiMAX-Control-Octets-In",
                            "WiMAX-Control-Packets-Out",
                            "WiMAX-Control-Octets-Out",
                            "WiMAX-PPAC",
                            "WiMAX-Available-In-Client",
                            "WiMAX-Session-Termination-Capability",
                            "WiMAX-PPAQ",
                            "WiMAX-PPAQ-Quota-Identifier",
                            "WiMAX-Volume-Quota",
                            "WiMAX-Volume-Threshold",
                            "WiMAX-Duration-Quota",
                            "WiMAX-Duration-Threshold",
                            "WiMAX-Resource-Quota",
                            "WiMAX-Resource-Threshold",
                            "WiMAX-Update-Reason",
                            "WiMAX-Service-Id",
                            "WiMAX-Rating-Group-Id",
                            "WiMAX-Termination-Action",
                            "WiMAX-Pool-Id",
                            "WiMAX-Pool-Multiplier",
                            "WiMAX-Requested-Action",
                            "WiMAX-Check-Balance-Result",
                            "WiMAX-Cost-Information-AVP",
                            "WiMAX-Prepaid-Tariff-Switching",
                            "WiMAX-Prepaid-Quota-Identifier",
                            "WiMAX-Volume-Used-After",
                            "WiMAX-Tariff-Switch-Interval",
                            "WiMAX-Time-Interval-After",
                            "WiMAX-Active-Time-Duration",
                            "WiMAX-DHCP-RK",
                            "WiMAX-DHCP-RK-Key-Id",
                            "WiMAX-DHCP-RK-Lifetime",
                            "WiMAX-DHCP-Msg-Server-IP",
                            "WiMAX-Idle-Mode-Transition",
                            "WiMAX-NAP-Id",
                            "WiMAX-BS-Id",
                            "WiMAX-Location",
                            "WiMAX-Acct-Input-Packets-Gigaword",
                            "WiMAX-Acct-Output-Packets-Gigaword",
                            "WiMAX-Uplink-Flow-Description",
                            "WiMAX-Blu-Coa-IPv6",
                            "WiMAX-Hotline-Profile-Id",
                            "WiMAX-HTTP-Redirection-Rule",
                            "WiMAX-IP-Redirection-Rule",
                            "WiMAX-Hotline-Session-Timer",
                            "WiMAX-NSP-Id",
                            "WiMAX-HA-RK-Key-Requested",
                            "WiMAX-Count-Type",
                            "WiMAX-DM-Action-Code",
                            "WiMAX-FA-RK-SPI",
                            "WiMAX-Downlink-Flow-Description",
                            "WiMAX-Downlink-Granted-QoS",
                            "WiMAX-vHA-IP-MIP4",
                            "WiMAX-vHA-IP-MIP6",
                            "WiMAX-vHA-MIP4-Key",
                            "WiMAX-vHA-RK-Key",
                            "WiMAX-vHA-RK-SPI",
                            "WiMAX-vHA-RK-Lifetime",
                            "WiMAX-MN-vHA-MIP6-Key",
                            "WiMAX-MN-vHA-MIP4-SPI",
                            "WiMAX-MN-vHA-MIP6-SPI",
                            "WiMAX-vDHCPv4-Server",
                            "WiMAX-vDHCPv6-Server",
                            "WiMAX-vDHCP-RK",
                            "WiMAX-vDHCP-RK-Key-ID",
                            "WiMAX-vDHCP-RK-Lifetime",
                            "WiMAX-PMIP-Authenticated-Network-Identity",
                            "WiMAX-Visited-Framed-IP-Address",
                            "WiMAX-Visited-Framed-IPv6-Prefix",
                            "WiMAX-Visited-Framed-Interface-Id",
                            "WiMAX-MIP-Authorization-Status",
                            "WiMAX-Flow-Descriptor-v2",
                            "WiMAX-Packet-Flow-Descriptor-v2",
                            "WiMAX-PFDv2-Packet-Data-Flow-Id",
                            "WiMAX-PFDv2-Service-Data-Flow-Id",
                            "WiMAX-PFDv2-Service-Profile-Id",
                            "WiMAX-PFDv2-Direction",
                            "WiMAX-PFDv2-Activation-Trigger",
                            "WiMAX-PFDv2-Transport-Type",
                            "WiMAX-PFDv2-Uplink-QoS-Id",
                            "WiMAX-PFDv2-Downlink-QoS-Id",
                            "WiMAX-PFDv2-Classifier",
                            "WiMAX-PFDv2-Classifier-Id",
                            "WiMAX-PFDv2-Classifier-Priority",
                            "WiMAX-PFDv2-Classifier-Protocol",
                            "WiMAX-PFDv2-Classifier-Direction",
                            "WiMAX-PFDv2-Classifier-Source-Spec",
                            "WiMAX-PFDv2-Src-IP-Address-Range",
                            "WiMAX-PFDv2-Src-Port",
                            "WiMAX-PFDv2-Src-Port-Range",
                            "WiMAX-PFDv2-Src-Inverted",
                            "WiMAX-PFDv2-Src-Assigned",
                            "WiMAX-PFDv2-Src-MAC-Address",
                            "WiMAX-PFDv2-Src-MAC-Mask",
                            "WiMAX-PFDv2-Classifier-Dest-Spec",
                            "WiMAX-PFDv2-Classifier-IP-ToS-DSCP",
                            "WiMAX-PFDv2-Classifier-Action",
                            "WiMAX-PFDv2-Classifier-Eth-Option",
                            "WiMAX-PFDv2-Eth-Proto-Type",
                            "WiMAX-PFDv2-Eth-Proto-Type-Ethertype",
                            "WiMAX-PFDv2-Eth-Proto-Type-DSAP",
                            "WiMAX-PFDv2-Eth-VLAN-Id",
                            "WiMAX-PFDv2-Eth-VLAN-Id-S-VID",
                            "WiMAX-PFDv2-Eth-VLAN-Id-C-VID",
                            "WiMAX-PFDv2-Eth-Priority-Range",
                            "WiMAX-PFDv2-Eth-Priority-Range-Low",
                            "WiMAX-PFDv2-Eth-Priority-Range-High",
                            "WiMAX-XXX",
                            "WiMAX-PFDv2-Paging-Preference",
                            "WiMAX-PFDv2-VLAN-Tag-Rule-Id",
                            "WiMAX-VLAN-Tag-Processing-Descriptor",
                            "WiMAX-VLAN-Tag-Rule-Id",
                            "WiMAX-VLAN-Tag-C-VLAN-Priority",
                            "WiMAX-VLAN-Tag-VLAN-Id-Assignment",
                            "WiMAX-VLAN-Tag-C-VLAN-Id",
                            "WiMAX-VLAN-Tag-S-VLAN-Id",
                            "WiMAX-VLAN-Tag-C-S-VLAN-Id-Mapping",
                            "WiMAX-VLAN-Tag-Local-Config-Info",
                            "WiMAX-hDHCP-Server-Parameters",
                            "WiMAX-hDHCP-DHCPv4-Address",
                            "WiMAX-hDHCP-DHCPv6-Address",
                            "WiMAX-hDHCP-DHCP-RK",
                            "WiMAX-hDHCP-DHCP-RK-Key-Id",
                            "WiMAX-hDHCP-DHCP-RK-Lifetime",
                            "WiMAX-vDHCP-Server-Parameters",
                            "WiMAX-vDHCP-DHCPv4-Address",
                            "WiMAX-vDHCP-DHCPv6-Address",
                            "WiMAX-vDHCP-DHCP-RK",
                            "WiMAX-vDHCP-DHCP-RK-Key-Id",
                            "WiMAX-vDHCP-DHCP-RK-Lifetime",
                            "WiMAX-BS-Location",
                            "WiMAX-Visited-IPv4-HoA-PMIP6",
                            "WiMAX-MS-Authenticated",
                            "WiMAX-PMIP6-Service-Info",
                            "WiMAX-hLMA-IPv6-PMIP6",
                            "WiMAX-hLMA-IPv4-PMIP6",
                            "WiMAX-vLMA-IPv6-PMIP6",
                            "WiMAX-vLMA-IPv4-PMIP6",
                            "WiMAX-PMIP6-RK-Key",
                            "WiMAX-PMIP6-RK-SPI",
                            "WiMAX-Home-HNP-PMIP6",
                            "WiMAX-Home-Interface-Id-PMIP6",
                            "WiMAX-Home-IPv4-HoA-PMIP6",
                            "WiMAX-Visited-HNP-PMIP6",
                            "WiMAX-Visited-Interface-Id-PMIP6",
                            "WiMAX-Visited-IPv4-HoA-PMIP6-2",
                            "WISPr-Location-ID",
                            "WISPr-Location-Name",
                            "WISPr-Logoff-URL",
                            "WISPr-Redirection-URL",
                            "WISPr-Bandwidth-Min-Up",
                            "WISPr-Bandwidth-Min-Down",
                            "WISPr-Bandwidth-Max-Up",
                            "WISPr-Bandwidth-Max-Down",
                            "WISPr-Session-Terminate-Time",
                            "WISPr-Session-Terminate-End-Of-Day",
                            "WISPr-Billing-Class-Of-Service",
                            "Xedia-DNS-Server",
                            "Xedia-NetBios-Server",
                            "Xedia-Address-Pool",
                            "Xedia-PPP-Echo-Interval",
                            "Xedia-SSH-Privileges",
                            "Xedia-Client-Access-Network",
                            "Xedia-Client-Firewall-Setting",
                            "Xedia-Save-Password",
                            "Xylan-Auth-Group",
                            "Xylan-Slot-Port",
                            "Xylan-Time-of-Day",
                            "Xylan-Client-IP-Addr",
                            "Xylan-Group-Desc",
                            "Xylan-Port-Desc",
                            "Xylan-Profil-Numb",
                            "Xylan-Auth-Group-Protocol",
                            "Xylan-Asa-Access",
                            "Xylan-End-User-Profile",
                            "Xylan-Primary-Home-Agent",
                            "Xylan-Secondary-Home-Agent",
                            "Xylan-Home-Agent-Password",
                            "Xylan-Home-Network-Name",
                            "Xylan-Access-Priv",
                            "Xylan-Nms-Group",
                            "Xylan-Nms-First-Name",
                            "Xylan-Nms-Last-Name",
                            "Xylan-Nms-Description",
                            "Xylan-Acce-Priv-R1",
                            "Xylan-Acce-Priv-R2",
                            "Xylan-Acce-Priv-W1",
                            "Xylan-Acce-Priv-W2",
                            "Xylan-Acce-Priv-G1",
                            "Xylan-Acce-Priv-G2",
                            "Xylan-Acce-Priv-F-R1",
                            "Xylan-Acce-Priv-F-R2",
                            "Xylan-Acce-Priv-F-W1",
                            "Xylan-Acce-Priv-F-W2",
                            "Xylan-Policy-List",
                            "Xylan-Redirect-Url",
                            "Xylan-Device-Name",
                            "Xylan-Device-Location",
                            "Yubikey-Key",
                            "Yubikey-Public-ID",
                            "Yubikey-Private-ID",
                            "Yubikey-Counter",
                            "Yubikey-Timestamp",
                            "Yubikey-Random",
                            "Yubikey-OTP",
                            "Zeus-ZXTM-Group",
                            "ZTE-Client-DNS-Pri",
                            "ZTE-Client-DNS-Sec",
                            "ZTE-Context-Name",
                            "ZTE-Tunnel-Max-Sessions",
                            "ZTE-Tunnel-Max-Tunnels",
                            "ZTE-Tunnel-Window",
                            "ZTE-Tunnel-Retransmit",
                            "ZTE-Tunnel-Cmd-Timeout",
                            "ZTE-PPPOE-URL",
                            "ZTE-PPPOE-MOTM",
                            "ZTE-Tunnel-Algorithm",
                            "ZTE-Tunnel-Deadtime",
                            "ZTE-Mcast-Send",
                            "ZTE-Mcast-Receive",
                            "ZTE-Mcast-MaxGroups",
                            "ZTE-Access-Type",
                            "ZTE-QoS-Type",
                            "ZTE-QoS-Profile-Down",
                            "ZTE-Rate-Ctrl-SCR-Down",
                            "ZTE-Rate-Ctrl-Burst-Down",
                            "ZTE-Rate-Ctrl-PCR",
                            "ZTE-TCP-Syn-Rate",
                            "ZTE-Rate-Ctrl-SCR-Up",
                            "ZTE-Priority-Level",
                            "ZTE-Rate-Ctrl-Burst-Up",
                            "ZTE-Rate-Ctrl-Burst-Max-Down",
                            "ZTE-Rate-Ctrl-Burst-Max-Up",
                            "ZTE-QOS-Profile-Up",
                            "ZTE-TCP-Limit-Num",
                            "ZTE-TCP-Limit-Mode",
                            "ZTE-IGMP-Service-Profile-Num",
                            "ZTE-PPP-Sservice-Type",
                            "ZTE-SW-Privilege",
                            "ZTE-Access-Domain",
                            "ZTE-VPN-ID",
                            "ZTE_Rate-Bust-DPIR",
                            "ZTE_Rate-Bust-UPIR",
                            "ZTE-Rate-Ctrl-PBS-Down",
                            "ZTE-Rate-Ctrl-PBS-Up",
                            "ZTE-Rate-Ctrl-SCR-Up-v6",
                            "ZTE-Rate-Ctrl-Burst-Up-v6",
                            "ZTE-Rate-Ctrl-Burst-Max-Up-v6",
                            "ZTE-Rate-Ctrl-PBS-Up-v6",
                            "ZTE-QoS-Profile-Up-v6",
                            "ZTE-Rate-Ctrl-SCR-Down-v6",
                            "ZTE-Rate-Ctrl-Burst-Down-v6",
                            "ZTE-Rate-Ctrl-Burst-Max-Down-v6",
                            "ZTE-Rate-Ctrl-PBS-Down-v6",
                            "ZTE-QoS-Profile-Down-v6",
                            "Zyxel-Privilege-AVPair",
                            "Zyxel-Callback-Option",
                            "Zyxel-Callback-Phone-Source",
                        )
                    ]
                }
            );
        }
    );
}

sub custom_startup_hook {

}

=head2 set_tenant_id

Set the tenant ID to the one specified in the header, or reset it to the default one if there is none

=cut

sub set_tenant_id {
    my ($c) = @_;
    my $tenant_id = $c->req->headers->header('X-PacketFence-Tenant-Id');
    if (defined $tenant_id) {
        unless (pf::dal->set_tenant($tenant_id)) {
            $c->render(json => { message => "Invalid tenant id provided $tenant_id"}, status => 404);
        }
    } else {
        pf::dal->reset_tenant();
    }
}

=head2 ReadonlyEndpoint

ReadonlyEndpoint

=cut

sub ReadonlyEndpoint {
    my ($model) = @_;
    return {
        controller => $model,
        collection => {
            http_methods => {
                'get'    => 'list',
            },
            subroutes => {
                map { $_ => { post => $_ } } qw(search)
            }
        },
        resource => {
            http_methods => {
                'get'    => 'get',
            },
        },
    },
}

=head2 setup_api_v1_crud_routes

setup_api_v1_crud_routes

=cut

sub setup_api_v1_crud_routes {
    my ($self, $root) = @_;
    $self->setup_api_v1_users_routes($root);
    $self->setup_api_v1_nodes_routes($root);
    $self->setup_api_v1_tenants_routes($root);
    $self->setup_api_v1_locationlogs_routes($root);
    $self->setup_api_v1_dhcp_option82s_routes($root);
    $self->setup_api_v1_auth_logs_routes($root);
    $self->setup_api_v1_radius_audit_logs_routes($root);
    $self->setup_api_v1_dns_audit_logs_routes($root);
    $self->setup_api_v1_admin_api_audit_logs_routes($root);
    $self->setup_api_v1_wrix_locations_routes($root);
    $self->setup_api_v1_security_events_routes($root);
    $self->setup_api_v1_sms_carriers_routes($root);
    $self->setup_api_v1_node_categories_routes($root);
    $self->setup_api_v1_classes_routes($root);
    $self->setup_api_v1_ip4logs_routes($root);
    $self->setup_api_v1_ip6logs_routes($root);
    return;
}

=head2 setup_api_v1_sms_carriers_routes

setup_api_v1_sms_carriers_routes

=cut

sub setup_api_v1_sms_carriers_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "SMSCarriers",
        "/sms_carriers",
        "/sms_carrier/#sms_carrier_id",
        "api.v1.SMSCarriers"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_routes

setup api v1 config routes

=cut

sub setup_api_v1_config_routes {
    my ($self, $root) = @_;
    $self->setup_api_v1_config_admin_roles_routes($root);
    $self->setup_api_v1_config_bases_routes($root);
    $self->setup_api_v1_config_billing_tiers_routes($root);
    $self->setup_api_v1_config_certificates_routes($root);
    $self->setup_api_v1_config_connection_profiles_routes($root);
    $self->setup_api_v1_config_self_services_routes($root);
    $self->setup_api_v1_config_domains_routes($root);
    $self->setup_api_v1_config_filters_routes($root);
    $self->setup_api_v1_config_fingerbank_settings_routes($root);
    $self->setup_api_v1_config_firewalls_routes($root);
    $self->setup_api_v1_config_floating_devices_routes($root);
    $self->setup_api_v1_config_maintenance_tasks_routes($root);
    $self->setup_api_v1_config_misc_routes($root);
    $self->setup_api_v1_config_interfaces_routes($root);
    $self->setup_api_v1_config_l2_networks_routes($root);
    $self->setup_api_v1_config_routed_networks_routes($root);
    $self->setup_api_v1_config_pki_providers_routes($root);
    $self->setup_api_v1_config_portal_modules_routes($root);
    $self->setup_api_v1_config_provisionings_routes($root);
    $self->setup_api_v1_config_realms_routes($root);
    $self->setup_api_v1_config_roles_routes($root);
    $self->setup_api_v1_config_scans_routes($root);
    $self->setup_api_v1_config_security_events_routes($root);
    $self->setup_api_v1_config_sources_routes($root);
    $self->setup_api_v1_config_switches_routes($root);
    $self->setup_api_v1_config_switch_groups_routes($root);
    $self->setup_api_v1_config_syslog_forwarders_routes($root);
    $self->setup_api_v1_config_syslog_parsers_routes($root);
    $self->setup_api_v1_config_template_switches_routes($root);
    $self->setup_api_v1_config_traffic_shaping_policies_routes($root);
    $self->setup_api_v1_config_wmi_rules_routes($root);
    return;
}

=head2 setup_api_v1_config_misc_routes

setup_api_v1_config_misc_routes

=cut

sub setup_api_v1_config_misc_routes {
    my ($self, $root) = @_;
    $root->register_sub_action({ controller => 'Config', action => 'fix_permissions', method => 'POST' });
    $root->register_sub_action({ controller => 'Config', action => 'checkup', method => 'GET' });
    return ;
}

=head2 setup_api_v1_current_user_routes

setup_api_v1_current_user_routes

=cut

sub setup_api_v1_current_user_routes {
    my ($self, $root) = @_;
    my $route = $root->any("/current_user")->to( controller => "CurrentUser" )->name("CurrentUser");
    $route->register_sub_actions(
        {
            actions => [
                qw(
                  allowed_user_unreg_date allowed_user_roles allowed_node_roles
                  allowed_user_access_levels allowed_user_actions allowed_user_access_durations
                )
            ],
            method => 'GET'
        }
    );
    return;
}

=head2 setup_api_v1_tenants_routes

setup_api_v1_tenants_routes

=cut

sub setup_api_v1_tenants_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "Tenants",
        "/tenants",
        "/tenant/#tenant_id",
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_locationlogs_routes

setup_api_v1_locationlogs_routes

=cut

sub setup_api_v1_locationlogs_routes {
    my ($self, $root) = @_;
    my $controller = "Locationlogs";
    my $name = $self->make_name_from_controller($root, $controller);
    my $collection_route = $root->any("/locationlogs")->to(controller => $controller)->name($name);

    $collection_route->register_sub_action({ action => 'list', path => '', method => 'GET' });
    $collection_route->register_sub_action({ action => 'search', method => 'POST' });
    $collection_route->register_sub_action({ action => 'ssids', method => 'GET' });

    return ($collection_route, undef);
}

=head2 setup_api_v1_dhcp_option82s_routes

setup_api_v1_dhcp_option82s_routes

=cut

sub setup_api_v1_dhcp_option82s_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "DhcpOption82s",
        "/dhcp_option82s",
        "/dhcp_option82/#dhcp_option82_id",
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_auth_logs_routes

setup_api_v1_auth_logs_routes

=cut

sub setup_api_v1_auth_logs_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "AuthLogs",
        "/auth_logs",
        "/auth_log/#auth_log_id",
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_radius_audit_logs_routes

setup_api_v1_radius_audit_logs_routes

=cut

sub setup_api_v1_radius_audit_logs_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "RadiusAuditLogs",
        "/radius_audit_logs",
        "/radius_audit_log/#radius_audit_log_id",
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_dns_audit_logs_routes

setup_api_v1_dns_audit_logs_routes

=cut

sub setup_api_v1_dns_audit_logs_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "DnsAuditLogs",
        "/dns_audit_logs",
        "/dns_audit_log/#dns_audit_log_id",
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_ip4logs_routes

setup_api_v1_ip4logs_routes

=cut

sub setup_api_v1_ip4logs_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "Ip4logs",
        "/ip4logs",
        "/ip4log/#ip4log_id",
    );

    $collection_route->register_sub_action({ method => 'GET', path => "/history/#search", action => 'history'});
    $collection_route->register_sub_action({ method => 'GET', path => "/archive/#search", action => 'archive'});
    $collection_route->register_sub_action({ method => 'GET', path => "/open/#search", action => 'open'});
    $collection_route->register_sub_action({ method => 'GET', path => "/mac2ip/#mac", action => 'mac2ip'});
    $collection_route->register_sub_action({ method => 'GET', path => "/ip2mac/#ip", action => 'ip2mac'});

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_ip6logs_routes

setup_api_v1_ip6logs_routes

=cut

sub setup_api_v1_ip6logs_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "Ip6logs",
        "/ip6logs",
        "/ip6log/#ip6log_id",
    );

    $collection_route->register_sub_action({ method => 'GET', path => "/history/#search", action => 'history'});
    $collection_route->register_sub_action({ method => 'GET', path => "/archive/#search", action => 'archive'});
    $collection_route->register_sub_action({ method => 'GET', path => "/open/#search", action => 'open'});
    $collection_route->register_sub_action({ method => 'GET', path => "/mac2ip/#mac", action => 'mac2ip'});
    $collection_route->register_sub_action({ method => 'GET', path => "/ip2mac/#ip", action => 'ip2mac'});

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_users_routes

setup_api_v1_users_routes

=cut

sub setup_api_v1_users_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "Users",
        "/users",
        "/user/#user_id",
    );

    $resource_route->register_sub_action({ method => 'GET', action => 'security_events' });
    $resource_route->register_sub_actions({ method => 'POST', actions => [qw(unassign_nodes close_security_events)], auditable => 1 });
    $collection_route->register_sub_actions(
        {
            method  => 'POST',
            actions => [
                qw(
                  bulk_register bulk_deregister bulk_close_security_events
                  bulk_reevaluate_access bulk_apply_security_event
                  bulk_apply_role bulk_apply_bypass_role bulk_fingerbank_refresh
                  bulk_delete bulk_import
                  )
            ],
            auditable => 1,
        }
    );
    my ($sub_collection_route, $sub_resource_route) = 
      $self->setup_api_v1_std_crud_routes(
        $resource_route,
        "Users::Nodes",
        "/nodes",
        "/node/#node_id",
    );

    my $password_route = $resource_route->any("/password")->to(controller => "Users::Password")->name("api.v1.Users.resource.Password");
    $password_route->register_sub_action({path => '', action => 'get', method => 'GET'});
    $password_route->register_sub_action({path => '', action => 'remove', method => 'DELETE', auditable => 1});
    $password_route->register_sub_action({path => '', action => 'update', method => 'PATCH', auditable => 1});
    $password_route->register_sub_action({path => '', action => 'replace', method => 'PUT', auditable => 1});
    $password_route->register_sub_action({path => '', action => 'create', method => 'POST', auditable => 1});

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_nodes_routes

setup_api_v1_nodes_routes

=cut

sub setup_api_v1_nodes_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "Nodes",
        "/nodes",
        "/node/#node_id",
    );

    $resource_route->register_sub_actions({
        method => 'POST',
        actions => [ qw( register deregister restart_switchport reevaluate_access apply_security_event close_security_event fingerbank_refresh park unpark) ],
        auditable => 1,
    });

    $resource_route->register_sub_actions({
        method => 'GET',
        actions => [ qw(fingerbank_info rapid7 security_events) ],
    });

    $collection_route->register_sub_actions({
        method => 'POST',
        actions => [
        qw(
          bulk_register bulk_deregister bulk_close_security_events
          bulk_reevaluate_access bulk_restart_switchport bulk_apply_security_event
          bulk_apply_role bulk_apply_bypass_role bulk_fingerbank_refresh
          bulk_apply_bypass_vlan bulk_import
          )
        ],
        auditable => 1
    });

    $collection_route->register_sub_action({
        method => 'POST',
        action => 'network_graph',
    });

    return ( $collection_route, $resource_route );
}


=head2 add_subroutes

add_subroutes

=cut

sub add_subroutes {
    my ($self, $root, $controller, $method, @subroutes) = @_;
    my $name = $root->name;
    for my $subroute (@subroutes) {
        $root
          ->any([$method] => "/$subroute")
          ->to("$controller#$subroute")
          ->name("${name}.$subroute");
    }
    return ;
}

=head2 setup_api_v1_security_events_routes

setup_api_v1_security_events_routes

=cut

sub setup_api_v1_security_events_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "SecurityEvents",
        "/security_events",
        "/security_event/#security_event_id",
    );

    $collection_route->any(['GET'] => '/by_mac/#search')->to("SecurityEvents#by_mac")->name("api.v1.SecurityEvents.by_mac");
    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_node_categories_routes

setup_api_v1_node_categories_routes

=cut

sub setup_api_v1_node_categories_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_readonly_routes(
        $root,
        "NodeCategories",
        "/node_categories",
        "/node_category/#node_category_id",
        "api.v1.NodeCategories",
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_admin_api_audit_logs_routes

setup_api_v1_admin_api_audit_logs_routes

=cut

sub setup_api_v1_admin_api_audit_logs_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_readonly_routes(
        $root,
        "AdminApiAuditLogs",
        "/admin_api_audit_logs",
        "/admin_api_audit_log/#admin_api_audit_log_id",
        "api.v1.AdminApiAuditLogs",
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_classes_routes

setup_api_v1_classes_routes

=cut

sub setup_api_v1_classes_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_readonly_routes(
        $root,
        "Classes",
        "/classes",
        "/class/#class_id",
        "api.v1.Classes",
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_wrix_locations_routes

setup_api_v1_wrix_locations_routes

=cut

sub setup_api_v1_wrix_locations_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "WrixLocations",
        "/wrix_locations",
        "/wrix_location/#wrix_location_id",
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_std_crud_readonly_routes

setup_api_v1_std_crud_readonly_routes

=cut

sub setup_api_v1_std_crud_readonly_routes {
    my ($self, $root, $controller, $collection_path, $resource_path, $name) = @_;
    my $collection_route = $root->any($collection_path)->name($name);
    $collection_route->any(['GET'])->to("$controller#list")->name("${name}.list");
    $collection_route->any(['POST'] => "/search")->to("$controller#search")->name("${name}.search");
    my $resource_route = $root->under($resource_path)->to("${controller}#resource")->name("${name}.resource");
    $resource_route->any(['GET'])->to("$controller#get")->name("${name}.resource.get");
    return ($collection_route, $resource_route);
}

sub make_name_from_controller {
    my ($self, $root, $controller) = @_;
    my $name = $controller;
    my $root_name = $root->name;
    $name =~ s/::/./g;
    $name = "${root_name}.${name}";
    return $name;
}

=head2 setup_api_v1_std_crud_routes

setup_api_v1_std_crud_routes

=cut

sub setup_api_v1_std_crud_routes {
    my ($self, $root, $controller, $collection_path, $resource_path, $name) = @_;
    my $root_name = $root->name;
    if (!defined $name) {
        $name = $self->make_name_from_controller($root, $controller);
    }

    my $collection_route = $root->any($collection_path)->to(controller=> $controller)->name($name);
    $self->setup_api_v1_std_crud_collection_routes($collection_route);
    my $resource_route = $root->under($resource_path)->to(controller => $controller, action => "resource")->name("${name}.resource");
    $self->setup_api_v1_std_crud_resource_routes($resource_route);
    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_std_crud_collection_routes

setup_api_v1_std_crud_collection_routes

=cut

sub setup_api_v1_std_crud_collection_routes {
    my ($self, $root) = @_;
    $root->register_sub_action({path => '', action => 'list', method => 'GET'});
    $root->register_sub_action({path => '', action => 'create', method => 'POST', auditable => 1});
    $root->register_sub_action({action => 'search', method => 'POST'});
    return ;
}

=head2 setup_api_v1_std_crud_resource_routes

setup_api_v1_std_crud_resource_routes

=cut

sub setup_api_v1_std_crud_resource_routes {
    my ($self, $root) = @_;
    $root->register_sub_action({path => '', action => 'get', method => 'GET'});
    $root->register_sub_action({path => '', action => 'update', method => 'PATCH', auditable => 1});
    $root->register_sub_action({path => '', action => 'replace', method => 'PUT', auditable => 1});
    $root->register_sub_action({path => '', action => 'remove', method => 'DELETE', auditable => 1});
    return ;
}

=head2 setup_api_v1_std_config_routes

setup_api_v1_std_config_routes

=cut

sub setup_api_v1_std_config_routes {
    my ($self, $root, $controller, $collection_path, $resource_path, $name) = @_;
    if (!defined $name) {
        $name = $self->make_name_from_controller($root, $controller);
    }

    my $collection_route = $root->any($collection_path)->to(controller => $controller)->name($name);
    $self->setup_api_v1_std_config_collection_routes($collection_route, $name, $controller);
    my $resource_route = $root->under($resource_path)->to(controller => $controller, action => "resource")->name("${name}.resource");
    $self->setup_api_v1_std_config_resource_routes($resource_route);
    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_std_config_collection_routes

setup_api_v1_standard_config_collection_routes

=cut

sub setup_api_v1_std_config_collection_routes {
    my ($self, $root, $name, $controller) = @_;
    $root->register_sub_action({path => '', action => 'list', method => 'GET'});
    $root->register_sub_action({path => '', action => 'create', method => 'POST', auditable => 1});
    $root->register_sub_action({path => '', action => 'options', method => 'OPTIONS'});
    $root->register_sub_action({action => 'sort_items', method => 'PATCH', auditable => 1});
    $root->register_sub_action({action => 'search', method => 'POST'});
    return ;
}

=head2 setup_api_v1_std_config_resource_routes

setup_api_v1_std_config_resource_routes

=cut

sub setup_api_v1_std_config_resource_routes {
    my ($self, $root) = @_;
    $root->register_sub_action({path => '', action => 'get', method => 'GET'});
    $root->register_sub_action({path => '', action => 'update', method => 'PATCH', auditable => 1});
    $root->register_sub_action({path => '', action => 'replace', method => 'PUT', auditable => 1});
    $root->register_sub_action({path => '', action => 'remove', method => 'DELETE', auditable => 1});
    $root->register_sub_action({path => '', action => 'resource_options', method => 'OPTIONS'});
    return ;
}

=head2 setup_api_v1_config_admin_roles_routes

 setup_api_v1_config_admin_roles_routes

=cut

sub setup_api_v1_config_admin_roles_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::AdminRoles",
        "/admin_roles",
        "/admin_role/#admin_role_id",
        "api.v1.Config.AdminRoles"
    );

    return ($collection_route, $resource_route);
}


=head2 setup_api_v1_config_bases_routes

 setup_api_v1_config_bases_routes

=cut

sub setup_api_v1_config_bases_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::Bases",
        "/bases",
        "/base/#base_id",
        "api.v1.Config.Bases"
    );

    $collection_route->register_sub_action({ action => 'test_smtp', method => 'POST'});
    return ($collection_route, $resource_route);
}


=head2 setup_api_v1_config_billing_tiers_routes

 setup_api_v1_config_billing_tiers_routes

=cut

sub setup_api_v1_config_billing_tiers_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::BillingTiers",
        "/billing_tiers",
        "/billing_tier/#billing_tier_id",
        "api.v1.Config.BillingTiers"
    );

    return ($collection_route, $resource_route);
}


=head2 setup_api_v1_config_self_services_routes

 setup_api_v1_config_self_services_routes

=cut

sub setup_api_v1_config_self_services_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::SelfServices",
        "/self_services",
        "/self_service/#self_service_id",
        "api.v1.Config.SelfServices"
    );

    return ($collection_route, $resource_route);
}


=head2 setup_api_v1_config_domains_routes

 setup_api_v1_config_domains_routes

=cut

sub setup_api_v1_config_domains_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::Domains",
        "/domains",
        "/domain/#domain_id",
        "api.v1.Config.Domains"
    );
    $resource_route->register_sub_action({path => '/test_join', action => 'test_join', method => 'GET'});
    $resource_route->register_sub_actions({method=> 'POST', actions => [qw(join unjoin rejoin)], auditable => 1});
    return ($collection_route, $resource_route);
}


=head2 setup_api_v1_config_floating_devices_routes

 setup_api_v1_config_floating_devices_routes

=cut

sub setup_api_v1_config_floating_devices_routes {
    my ( $self, $root ) = @_;
    my ( $collection_route, $resource_route ) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::FloatingDevices",
        "/floating_devices",
        "/floating_device/#floating_device_id",
        "api.v1.Config.FloatingDevices"
      );

    return ($collection_route, $resource_route);
}


=head2 setup_api_v1_config_maintenance_tasks_routes

 setup_api_v1_config_maintenance_tasks_routes

=cut

sub setup_api_v1_config_maintenance_tasks_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::MaintenanceTasks",
        "/maintenance_tasks",
        "/maintenance_task/#maintenance_task_id",
        "api.v1.Config.MaintenanceTasks"
      );

    return ($collection_route, $resource_route);
}


=head2 setup_api_v1_config_pki_providers_routes

 setup_api_v1_config_pki_providers_routes

=cut

sub setup_api_v1_config_pki_providers_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::PkiProviders",
        "/pki_providers",
        "/pki_provider/#pki_provider_id",
        "api.v1.Config.PkiProviders"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_portal_modules_routes

 setup_api_v1_config_portal_modules_routes

=cut

sub setup_api_v1_config_portal_modules_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::PortalModules",
        "/portal_modules",
        "/portal_module/#portal_module_id",
        "api.v1.Config.PortalModules"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_provisionings_routes

 setup_api_v1_config_provisionings_routes

=cut

sub setup_api_v1_config_provisionings_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::Provisionings",
        "/provisionings",
        "/provisioning/#provisioning_id",
        "api.v1.Config.Provisionings"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_realms_routes

 setup_api_v1_config_realms_routes

=cut

sub setup_api_v1_config_realms_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::Realms",
        "/realms",
        "/realm/#realm_id",
        "api.v1.Config.Realms"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_roles_routes

 setup_api_v1_config_roles_routes

=cut

sub setup_api_v1_config_roles_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::Roles",
        "/roles",
        "/role/#role_id",
        "api.v1.Config.Roles"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_scans_routes

 setup_api_v1_config_scans_routes

=cut

sub setup_api_v1_config_scans_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::Scans",
        "/scans",
        "/scan/#scan_id",
        "api.v1.Config.Scans"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_switch_groups_routes

 setup_api_v1_config_switch_groups_routes

=cut

sub setup_api_v1_config_switch_groups_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::SwitchGroups",
        "/switch_groups",
        "/switch_group/#switch_group_id",
        "api.v1.Config.SwitchGroups"
    );

    $resource_route->register_sub_action({action => 'members', method => 'GET'});
    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_syslog_forwarders_routes

 setup_api_v1_config_syslog_forwarders_routes

=cut

sub setup_api_v1_config_syslog_forwarders_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::SyslogForwarders",
        "/syslog_forwarders",
        "/syslog_forwarder/#syslog_forwarder_id",
        "api.v1.Config.SyslogForwarders"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_traffic_shaping_policies_routes

 setup_api_v1_config_traffic_shaping_policies_routes

=cut

sub setup_api_v1_config_traffic_shaping_policies_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::TrafficShapingPolicies",
        "/traffic_shaping_policies",
        "/traffic_shaping_policy/#traffic_shaping_policy_id",
        "api.v1.Config.TrafficShapingPolicies"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_security_events_routes

 setup_api_v1_config_security_events_routes

=cut

sub setup_api_v1_config_security_events_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::SecurityEvents",
        "/security_events",
        "/security_event/#security_event_id",
        "api.v1.Config.SecurityEvents"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_l2_networks_routes

setup_api_v1_config_l2_networks_routes

=cut

sub setup_api_v1_config_l2_networks_routes {
    my ($self, $root) = @_;
    my $collection_route = $root->any("/l2_networks")->name("api.v1.Config.L2Networks");
    $collection_route->any(['GET'] => "/")->to("Config::L2Networks#list")->name("api.v1.Config.L2Networks.list");
    $collection_route->any(['OPTIONS'] => "/")->to("Config::L2Networks#options")->name("api.v1.Config.L2Networks.options");
    my $resource_route = $root->under("/l2_network/#network_id")->to("Config::L2Networks#resource")->name("api.v1.Config.L2Networks.resource");
    $resource_route->any(['GET'] => "/")->to("Config::L2Networks#get")->name("api.v1.Config.L2Networks.get");
    $resource_route->any(['PATCH'] => "/")->to("Config::L2Networks#update")->name("api.v1.Config.L2Networks.update");
    $resource_route->any(['PUT'] => "/")->to("Config::L2Networks#replace")->name("api.v1.Config.L2Networks.replace");
    $resource_route->any(['OPTIONS'] => "/")->to("Config::L2Networks#resource_options")->name("api.v1.Config.L2Networks.resource_options");
    return (undef, $resource_route);
}

=head2 setup_api_v1_config_routed_networks_routes

setup_api_v1_config_routed_networks_routes

=cut

sub setup_api_v1_config_routed_networks_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::RoutedNetworks",
        "/routed_networks",
        "/routed_network/#network_id",
        "api.v1.Config.RoutedNetworks"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_firewalls_routes

setup_api_v1_config_firewalls_routes

=cut

sub setup_api_v1_config_firewalls_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::Firewalls",
        "/firewalls",
        "/firewall/#firewall_id",
        "api.v1.Config.Firewalls"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_connection_profiles_routes

setup_api_v1_config_connection_profiles_routes

=cut

sub setup_api_v1_config_connection_profiles_routes {
    my ($self, $root) = @_;
    my $controller = "Config::ConnectionProfiles";
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        $controller,
        "/connection_profiles",
        "/connection_profile/#connection_profile_id",
        "api.v1.Config.ConnectionProfiles"
    );

    $self->setup_api_v1_config_connection_profiles_files_routes($controller, $resource_route);
    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_connection_profiles_files_routes

setup_api_v1_config_connection_profiles_files_routes

=cut

sub setup_api_v1_config_connection_profiles_files_routes {
    my ($self, $controller, $root) = @_;
    my $name = "api.v1.Config.ConnectionProfiles.resource.files";
    my $files_route = $root->any("/files")->name($name);
    $files_route->any(['GET'])->to("$controller#files" => {})->name("${name}.dir");
    my $file_route = $files_route->any("/*file_name")->name("${name}.file");
    $file_route->any(['GET'])->to("$controller#get_file" => {})->name("${name}.file.get");
    $file_route->any(['PATCH'])->to("$controller#replace_file" => {})->name("${name}.file.replace");
    $file_route->any(['PUT'])->to("$controller#new_file" => {})->name("${name}.file.new");
    $file_route->any(['DELETE'])->to("$controller#delete_file" => {})->name("${name}.file.delete");

    return ;
}

=head2 setup_api_v1_config_switches_routes

setup_api_v1_config_switches_routes

=cut

sub setup_api_v1_config_switches_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::Switches",
        "/switches",
        "/switch/#switch_id",
        "api.v1.Config.Switches"
    );

    $resource_route->any(['POST'] => "/invalidate_cache")->to("Config::Switches#invalidate_cache", auditable => 1)->name("api.v1.Config.Switches.invalidate_cache");

    return ($collection_route, $resource_route);
}


=head2 setup_api_v1_config_template_switches_routes

setup_api_v1_config_template_switches_routes

=cut

sub setup_api_v1_config_template_switches_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::TemplateSwitches",
        "/template_switches",
        "/template_switch/#template_switch_id",
        "api.v1.Config.TemplateSwitches"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_sources_routes

setup_api_v1_config_sources_routes

=cut

sub setup_api_v1_config_sources_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::Sources",
        "/sources",
        "/source/#source_id",
        "api.v1.Config.Source"
    );

    $collection_route->any(['POST'] => "/test")->to("Config::Sources#test")->name("api.v1.Config.Sources.test");
    $resource_route->register_sub_action({ method => 'GET', action => 'saml_metadata'});

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_syslog_parsers_routes

setup_api_v1_config_syslog_parsers_routes

=cut

sub setup_api_v1_config_syslog_parsers_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::SyslogParsers",
        "/syslog_parsers",
        "/syslog_parser/#syslog_parser_id",
        "api.v1.Config.SyslogParsers"
    );

    $collection_route->any(['POST'] => "/dry_run")->to("Config::SyslogParsers#dry_run")->name("api.v1.Config.SyslogParsers.dry_run");

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_filters_routes

setup_api_v1_config_filters_routes

=cut

sub setup_api_v1_config_filters_routes {
    my ($self, $root) = @_;
    my $collection_route = $root->any(['GET'] => '/filters')->to(controller => "Config::Filters", action => 'list')->name("api.v1.Config.Filters.list");
    my $resource_route = $root->under("/filter/#filter_id")->to(controller => "Config::Filters", action => "resource")->name("api.v1.Config.Filters.resource");
    $resource_route->any(['GET'])->to(controller => "Config::Filters", action => "get")->name("api.v1.Config.Filters.resource.get");
    $resource_route->any(['PUT'])->to(controller => "Config::Filters", action => "replace")->name("api.v1.Config.Filters.resource.replace");

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_fingerbank_settings_routes

setup_api_v1_config_fingerbank_settings_routes

=cut

sub setup_api_v1_config_fingerbank_settings_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::FingerbankSettings",
        "/fingerbank_settings",
        "/fingerbank_setting/#fingerbank_setting_id",
        "api.v1.Config.FingerbankSettings"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_certificates_routes

setup_api_v1_config_certificates_routes

=cut

sub setup_api_v1_config_certificates_routes {
    my ($self, $root) = @_;
    my $root_name = $root->name;
    $root->any(["GET"] => "/certificates/lets_encrypt/test")->to("Config::Certificates#lets_encrypt_test")->name("${root_name}.Certificates.lets_encrypt_test");

    my $resource_route = $root->under("/certificate/#certificate_id")->to(controller => "Config::Certificates", action => 'resource')->name("${root_name}.Certificates.resource");
    my $resource_name = $resource_route->name;
    $resource_route->any(['GET'] => '')->to(action => "get")->name("${resource_name}.get");
    $resource_route->any(['PUT'])->to(action => "replace")->name("${resource_name}.replace");
    $resource_route->any(['GET'] => "/info")->to(action => "info")->name("${resource_name}.info");
    $resource_route->any(['POST'] => "/generate_csr")->to(action => "generate_csr")->name("${resource_name}.generate_csr");
    $resource_route->any(['PUT'] => "/lets_encrypt")->to(action => "lets_encrypt_replace")->name("${resource_name}.lets_encrypt_replace");

    return (undef, $resource_route);
}

=head2 setup_api_v1_translations_routes

setup_api_v1_translations_routes

=cut

sub setup_api_v1_translations_routes {
    my ($self, $root) = @_;
    my $collection_route =
      $root->any( ['GET'] => "/translations" )
      ->to(controller => "Translations", action => "list")
      ->name("api.v1.Config.Translations.list");
    my $resource_route =
      $root->under("/translation/#translation_id")
      ->to(controller => "Translations", action => "resource")
      ->name("api.v1.Config.Translations.resource");
    $resource_route->any(['GET'])->to(action => "get")->name("api.v1.Config.Translations.resource.get");
    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_preferences_routes

setup_api_v1_preferences_routes

=cut

sub setup_api_v1_preferences_routes {
    my ($self, $root) = @_;
    my $collection_route = $root->any(['GET'] => "/preferences")->to("Preferences#list")->name("api.v1.Config.Preferences.list");
    my $resource_route = $root->under("/preference/#preference_id")->to("Preferences#resource")->name("api.v1.Config.Preferences.resource");
    $resource_route->any(['GET'])->to("Preferences#get")->name("api.v1.Config.Preferences.resource.get");
    $resource_route->any(['PUT'])->to("Preferences#replace")->name("api.v1.Config.Preferences.resource.replace");
    $resource_route->any(['DELETE'])->to("Preferences#delete")->name("api.v1.Config.Preferences.resource.delete");
    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_reports_routes

setup_api_v1_reports_routes

=cut

sub setup_api_v1_reports_routes {
    my ($self, $root) = @_;
    $root
      ->any(['GET'] => "/os")
      ->to("Reports#os_all")
      ->name("api.v1.Reports.os_all");
    $root
      ->any(['GET'] => "/os/#start/#end")
      ->to("Reports#os_range")
      ->name("api.v1.Reports.os_range");
    $root
      ->any(['GET'] => "/os/active")
      ->to("Reports#os_active")
      ->name("api.v1.Reports.os_active");
    $root
      ->any(['GET'] => "/osclass")
      ->to("Reports#osclass_all")
      ->name("api.v1.Reports.osclass_all");
    $root
      ->any(['GET'] => "/osclass/active")
      ->to("Reports#osclass_active")
      ->name("api.v1.Reports.osclass_active");
    $root
      ->any(['GET'] => "/inactive")
      ->to("Reports#inactive_all")
      ->name("api.v1.Reports.inactive_all");
    $root
      ->any(['GET'] => "/active")
      ->to("Reports#active_all")
      ->name("api.v1.Reports.active_all");
    $root
      ->any(['GET'] => "/unregistered")
      ->to("Reports#unregistered_all")
      ->name("api.v1.Reports.unregistered_all");
    $root
      ->any(['GET'] => "/unregistered/active")
      ->to("Reports#unregistered_active")
      ->name("api.v1.Reports.unregistered_active");
    $root
      ->any(['GET'] => "/registered")
      ->to("Reports#registered_all")
      ->name("api.v1.Reports.registered_all");
    $root
      ->any(['GET'] => "/registered/active")
      ->to("Reports#registered_active")
      ->name("api.v1.Reports.registered_active");
    $root
      ->any(['GET'] => "/unknownprints")
      ->to("Reports#unknownprints_all")
      ->name("api.v1.Reports.unknownprints_all");
    $root
      ->any(['GET'] => "/unknownprints/active")
      ->to("Reports#unknownprints_active")
      ->name("api.v1.Reports.unknownprints_active");
    $root
      ->any(['GET'] => "/statics")
      ->to("Reports#statics_all")
      ->name("api.v1.Reports.statics_all");
    $root
      ->any(['GET'] => "/statics/active")
      ->to("Reports#statics_active")
      ->name("api.v1.Reports.statics_active");
    $root
      ->any(['GET'] => "/opensecurity_events")
      ->to("Reports#opensecurity_events_all")
      ->name("api.v1.Reports.opensecurity_events_all");
    $root
      ->any(['GET'] => "/opensecurity_events/active")
      ->to("Reports#opensecurity_events_active")
      ->name("api.v1.Reports.opensecurity_events_active");
    $root
      ->any(['GET'] => "/connectiontype")
      ->to("Reports#connectiontype_all")
      ->name("api.v1.Reports.connectiontype_all");
    $root
      ->any(['GET'] => "/connectiontype/#start/#end")
      ->to("Reports#connectiontype_range")
      ->name("api.v1.Reports.connectiontype_range");
    $root
      ->any(['GET'] => "/connectiontype/active")
      ->to("Reports#connectiontype_active")
      ->name("api.v1.Reports.connectiontype_active");
    $root
      ->any(['GET'] => "/connectiontypereg")
      ->to("Reports#connectiontypereg_all")
      ->name("api.v1.Reports.connectiontypereg_all");
    $root
      ->any(['GET'] => "/connectiontypereg/active")
      ->to("Reports#connectiontypereg_active")
      ->name("api.v1.Reports.connectiontypereg_active");
    $root
      ->any(['GET'] => "/ssid")
      ->to("Reports#ssid_all")
      ->name("api.v1.Reports.ssid_all");
    $root
      ->any(['GET'] => "/ssid/#start/#end")
      ->to("Reports#ssid_range")
      ->name("api.v1.Reports.ssid_range");
    $root
      ->any(['GET'] => "/ssid/active")
      ->to("Reports#ssid_active")
      ->name("api.v1.Reports.ssid_active");
    $root
      ->any(['GET'] => "/osclassbandwidth")
      ->to("Reports#osclassbandwidth_all")
      ->name("api.v1.Reports.osclassbandwidth_all");
    $root
      ->any(['GET'] => "/osclassbandwidth/#start/#end")
      ->to("Reports#osclassbandwidth_range")
      ->name("api.v1.Reports.osclassbandwidth_range");
    $root
      ->any(['GET'] => "/osclassbandwidth/day")
      ->to("Reports#osclassbandwidth_day")
      ->name("api.v1.Reports.osclassbandwidth_day");
    $root
      ->any(['GET'] => "/osclassbandwidth/week")
      ->to("Reports#osclassbandwidth_week")
      ->name("api.v1.Reports.osclassbandwidth_week");
    $root
      ->any(['GET'] => "/osclassbandwidth/month")
      ->to("Reports#osclassbandwidth_month")
      ->name("api.v1.Reports.osclassbandwidth_month");
    $root
      ->any(['GET'] => "/osclassbandwidth/year")
      ->to("Reports#osclassbandwidth_year")
      ->name("api.v1.Reports.osclassbandwidth_year");
    $root
      ->any(['GET'] => "/nodebandwidth")
      ->to("Reports#nodebandwidth_all")
      ->name("api.v1.Reports.nodebandwidth_all");
    $root
      ->any(['GET'] => "/nodebandwidth/#start/#end")
      ->to("Reports#nodebandwidth_range")
      ->name("api.v1.Reports.nodebandwidth_range");
    $root
      ->any(['GET'] => "/userbandwidth")
      ->to("Reports#userbandwidth_all")
      ->name("api.v1.Reports.userbandwidth_all");
    $root
      ->any(['GET'] => "/userbandwidth/#start/#end")
      ->to("Reports#userbandwidth_range")
      ->name("api.v1.Reports.userbandwidth_range");
    $root
      ->any(['GET'] => "/topauthenticationfailures/mac/#start/#end")
      ->to("Reports#topauthenticationfailures_by_mac")
      ->name("api.v1.Reports.topauthenticationfailures_by_mac");
    $root
      ->any(['GET'] => "/topauthenticationfailures/ssid/#start/#end")
      ->to("Reports#topauthenticationfailures_by_ssid")
      ->name("api.v1.Reports.topauthenticationfailures_by_ssid");
    $root
      ->any(['GET'] => "/topauthenticationfailures/username/#start/#end")
      ->to("Reports#topauthenticationfailures_by_username")
      ->name("api.v1.Reports.topauthenticationfailures_by_username");
    $root
      ->any(['GET'] => "/topauthenticationsuccesses/mac/#start/#end")
      ->to("Reports#topauthenticationsuccesses_by_mac")
      ->name("api.v1.Reports.topauthenticationsuccesses_by_mac");
    $root
      ->any(['GET'] => "/topauthenticationsuccesses/ssid/#start/#end")
      ->to("Reports#topauthenticationsuccesses_by_ssid")
      ->name("api.v1.Reports.topauthenticationsuccesses_by_ssid");
    $root
      ->any(['GET'] => "/topauthenticationsuccesses/username/#start/#end")
      ->to("Reports#topauthenticationsuccesses_by_username")
      ->name("api.v1.Reports.topauthenticationsuccesses_by_username");
    $root
      ->any(['GET'] => "/topauthenticationsuccesses/computername/#start/#end")
      ->to("Reports#topauthenticationsuccesses_by_computername")
      ->name("api.v1.Reports.topauthenticationsuccesses_by_computername");
    return ( undef, undef );
}

=head2 setup_api_v1_config_interfaces_routes

setup_api_v1_config_interfaces_routes

=cut

sub setup_api_v1_config_interfaces_routes {
    my ($self, $root) = @_;
    my $root_name = $root->name;
    my $name = "$root_name.Interfaces";
    my $controller = "Config::Interfaces";
    my $collection_route = $root->any("/interfaces")->to(controller => $controller)->name($name);
    $collection_route->register_sub_action({path => '', action => 'list', method => 'GET'});
    $collection_route->register_sub_action({path => '', action => 'create', method => 'POST', auditable => 1});
    my $resource_route = $root->under("/interface/#interface_id")->to(controller => "Config::Interfaces", action => "resource")->name("$name.resource");
    $resource_route->register_sub_action({path => '', action => 'get', method => 'GET'});
    $resource_route->register_sub_action({path => '', action => 'update', method => 'PATCH', auditable => 1});
    $resource_route->register_sub_action({path => '', action => 'delete', method => 'DELETE', auditable => 1});
    $resource_route->register_sub_actions({method=> 'POST', actions => [qw(up down)], auditable => 1});
    return ($collection_route, $resource_route);
}

sub setup_api_v1_dynamic_reports_routes {
    my ( $self, $root ) = @_;
    my $root_name = $root->name;
    my $controller = "DynamicReports";
    my $name = "$root_name.DynamicReports";
    my $collection_route = $root->any("/dynamic_reports")->to(controller => $controller)->name($name);
    $collection_route->register_sub_action({path => '', action => 'list', method => 'GET'});
    my $resource_route = $root->under("/dynamic_report/#report_id")->to(controller => $controller, action => "resource")->name("${name}.resource");
    $resource_route->register_sub_action({path => '', action => 'get', method => 'GET'});
    $resource_route->register_sub_action({action => 'search', method => 'POST'});
    return ( $collection_route, $resource_route );
}

=head2 setup_api_v1_cluster_routes

setup_api_v1_cluster_routes

=cut

sub setup_api_v1_cluster_routes {
    my ($self, $root) = @_;
    my $resource_route = $root->any("/cluster")->to(controller => "Cluster")->name("api.v1.Cluster");;
    $resource_route->any(['GET'] => "/servers")->to(action => "servers")->name("api.v1.Cluster.servers");
    return (undef, $resource_route);
}

=head2 setup_api_v1_services_routes

setup_api_v1_services_routes

=cut

sub setup_api_v1_services_routes {
    my ($self, $root) = @_;
    my $collection_route = $root->any("/services")->to(controller => "Services")->name("api.v1.Config.Services");
    $collection_route->register_sub_action({action => 'list', path => '', method => 'GET'});
    $collection_route->register_sub_actions({actions => [qw(status_all)], method => 'GET'});
    my $resource_route = $root->under("/service/#service_id")->to("Services#resource")->name("api.v1.Config.Services.resource");
    $self->add_subroutes($resource_route, "Services", "GET", qw(status));
    $self->add_subroutes($resource_route, "Services", "POST", qw(start stop restart enable disable));
    
    my $cs_collection_route = $collection_route->any("/cluster_statuses")->to(controller => "Services::ClusterStatuses")->name("api.v1.Config.Services.ClusterStatuses");
    $cs_collection_route->register_sub_action({action => 'list', path => '', method => 'GET'});
    my $cs_resource_route = $root->under("/services/cluster_status/#server_id")->to("Services::ClusterStatuses#resource")->name("api.v1.Config.Services.ClusterStatuses.resource");
    $cs_resource_route->register_sub_action({action => 'get', path => '', method => 'GET'});

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_authentication_routes

setup_api_v1_authentication_routes

=cut

sub setup_api_v1_authentication_routes {
    my ($self, $root) = @_;
    my $route = $root->any("/authentication")->name("api.v1.Authentication");
    $route->any(['POST'] => "/admin_authentication")->to("Authentication#adminAuthentication")->name("api.v1.Authentication.admin_authentication");
    return ;
}

=head2 setup_api_v1_queues_routes

setup_api_v1_queues_routes

=cut

sub setup_api_v1_queues_routes {
    my ($self, $root) = @_;
    my $route = $root->any("/queues")->name("api.v1.Queues");
    $route->register_sub_action({ action => "stats", method => "GET", controller => 'Queues'});
    return ;
}

=head2 setup_api_v1_fingerbank_routes

setup_api_v1_fingerbank_routes

=cut

sub setup_api_v1_fingerbank_routes {
    my ($self, $root) = @_;
    $root->register_sub_action({ action => "update_upstream_db", method => "POST"});
    $root->register_sub_action({ action => "account_info", method => "GET" });
    my $upstream = $root->any("/upstream")->to(scope => "Upstream")->name( $root->name . ".Upstream");
    my $local_route = $root->any("/local")->to(scope => "Local")->name( $root->name . ".Local");
    my $all_route = $root->any("/all")->to(scope => "All")->name( $root->name . ".All");
    $self->setup_api_v1_std_fingerbank_routes($all_route, $upstream, $local_route, "Combinations", "/combinations", "/combination/#combination_id");
    $self->setup_api_v1_std_fingerbank_routes($all_route, $upstream, $local_route, "Devices", "/devices", "/device/#device_id");
    $self->setup_api_v1_std_fingerbank_routes($all_route, $upstream, $local_route, "DHCP6Enterprises", "/dhcp6_enterprises", "/dhcp6_enterprise/#dhcp6_enterprise_id");
    $self->setup_api_v1_std_fingerbank_routes($all_route, $upstream, $local_route, "DHCP6Fingerprints", "/dhcp6_fingerprints", "/dhcp6_fingerprint/#dhcp6_fingerprint_id");
    $self->setup_api_v1_std_fingerbank_routes($all_route, $upstream, $local_route, "DHCPFingerprints", "/dhcp_fingerprints", "/dhcp_fingerprint/#dhcp_fingerprint_id");
    $self->setup_api_v1_std_fingerbank_routes($all_route, $upstream, $local_route, "DHCPVendors", "/dhcp_vendors", "/dhcp_vendor/#dhcp_vendor_id");
    $self->setup_api_v1_std_fingerbank_routes($all_route, $upstream, $local_route, "MacVendors", "/mac_vendors", "/mac_vendor/#mac_vendor_id");
    $self->setup_api_v1_std_fingerbank_routes($all_route, $upstream, $local_route, "UserAgents", "/user_agents", "/user_agent/#user_agent_id");
    return ;
}

=head2 setup_api_v1_std_fingerbank_routes

setup_api_v1_std_fingerbank_routes

=cut

sub setup_api_v1_std_fingerbank_routes {
    my ($self, $all_route, $upstream_root, $local_root, $name, $collection_path, $resource_path) = @_;
    my $controller = "Fingerbank::${name}";
    $self->setup_api_v1_std_readonly_fingerbank_routes($all_route, $name, $controller, $collection_path, $resource_path);
    $self->setup_api_v1_std_readonly_fingerbank_routes($upstream_root, $name, $controller, $collection_path, $resource_path);
    $self->setup_api_v1_std_local_fingerbank_routes($local_root, $name, $controller, $collection_path, $resource_path);
    return ;
}

=head2 setup_api_v1_std_upstream_fingerbank_routes

setup_api_v1_std_upstream_fingerbank_routes

=cut

sub setup_api_v1_std_readonly_fingerbank_routes {
    my ($self, $root, $name, $controller, $collection_path, $resource_path) = @_;
    my $root_name = $root->name;
    my $collection_route = $root->any($collection_path)->to(controller => $controller )->name("${root_name}.${name}");
    $collection_route->register_sub_action({ method => 'GET', action => 'list', path => ''});
    $collection_route->register_sub_action({ method => 'POST', action => 'search'});
    my $resource_route = $root->under($resource_path)->to(controller=> $controller, action => "resource")->name("${root_name}.${name}.resource");
    $resource_route->register_sub_action({ method => 'GET', action => 'get', path => ''});
    return ;
}

=head2 setup_api_v1_std_local_fingerbank_routes

setup_api_v1_std_local_fingerbank_routes

=cut

sub setup_api_v1_std_local_fingerbank_routes {
    my ($self, $root, $name, $controller, $collection_path, $resource_path) = @_;
    my $root_name = $root->name;
    my $collection_route = $root->any($collection_path)->to(controller => $controller )->name("${root_name}.${name}");
    $collection_route->register_sub_action({ method => 'GET', action => 'list', path => ''});
    $collection_route->register_sub_action({ method => 'POST', action => 'create', path => '', auditable => 1});
    $collection_route->register_sub_action({ method => 'POST', action => 'search'});
    my $resource_route = $root->under($resource_path)->to(controller=> $controller, action => "resource")->name("${root_name}.${name}.resource");
    $resource_route->register_sub_action({ method => 'GET', action => 'get', path => ''});
    $resource_route->register_sub_action({ method => 'DELETE', action => 'remove', path => '', auditable => 1});
    $resource_route->register_sub_action({ method => 'PUT', action => 'replace', path => '', auditable => 1});
    $resource_route->register_sub_action({ method => 'PATCH', action => 'update', path => '', auditable => 1});
    return ;
}

=head2 setup_api_v1_config_wmi_rules_routes

setup_api_v1_config_wmi_rules_routes

=cut

sub setup_api_v1_config_wmi_rules_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::WMIRules",
        "/wmi_rules",
        "/wmi_rule/#wmi_rule_id",
        "api.v1.Config.WMIRules"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_system_summary_route

setup_api_v1_system_summary_route

=cut

sub setup_api_v1_system_summary_route {
    my ($self, $root) = @_;
    $root->any( ['GET'] => "/system_summary" )
      ->to(controller => "SystemSummary", action => "get")
      ->name("api.v1.SystemSummary.get");
    return ;
}

=head2 setup_api_v1_emails_route

setup_api_v1_emails_route

=cut

sub setup_api_v1_emails_route {
    my ($self, $root) = @_;
    my $resource_route = $root->any("email")->to(controller => "Emails" )->name("api.v1.Emails");
    $resource_route->register_sub_action({ method => 'POST', action => 'preview', path => 'preview'});
    $resource_route->register_sub_action({ method => 'POST', action => 'send_email', path => 'send'});
    return ;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
