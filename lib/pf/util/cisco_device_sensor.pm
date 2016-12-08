package pf::util::cisco_device_sensor;

=head1 NAME

pf::util::cisco_device_sensor -

=cut

=head1 DESCRIPTION

pf::util::cisco_device_sensor is used to decode Cisco-AVPair tlv attributes

=cut

use strict;
use warnings;

BEGIN {
    use Exporter ();
    our (@ISA, @EXPORT);
    @ISA    = qw(Exporter);
    @EXPORT = qw(decode_avpair);
}

use pf::log;
use pf::constants;
use bytes;


## The parser maps for the options
##
our %OPTIONS_FILTER = (
    'lldp-tlv' => {
        '0'  => {
            desc => 'end-of-lldpdu',
            type => \&_ZEROSIZE,
        },
        '1'  => {
            desc => 'chassis-id',
            type => \&_NSTRING,
        },
        '2'  => {
            desc => 'port-id',
            type => \&_BLOB,
        },
        '3'  => {
            desc => 'time-to-live',
            type => \&_RANGEBYTE,
        },
        '4'  => {
            desc => 'port-description',
            type => \&_NSTRING,
        },
        '5'  => {
            desc => 'system-name',
            type => \&_NSTRING,
        },
        '6'  => {
            desc => 'system-description',
            type => \&_NSTRING,
        },
        '7'  => {
            desc => 'system-capabilities',
            type => \&_SHORT,
            extra => \&_lldp_capabilities,
        },
        '8'  => {
            desc => 'management-address',
            type => \&_IPADDR,
        },
    },
    'http-tlv' => {
        '1'  => {
            desc => 'user-agent',
            type => \&_NSTRING,
            extra => \&_user_agent,
        },
    },
    'cdp-tlv' => {
        '1'  => {
            desc => 'device-name',
            type => \&_NSTRING,
        },
        '2'  => {
            desc => 'address-type',
            type => \&_IPADDR,
        },
        '3'  => {
            desc => 'port-id-type',
            type => \&_NSTRING,
        },
        '4'  => {
            desc => 'cdp-capabilities-type',
            type => \&_SHORT,
            extra => \&_cdp_capabilities,
        },
        '5'  => {
            desc => 'version-type',
            type => \&_NSTRING,
        },
        '6'  => {
            desc => 'platform-type',
            type => \&_NSTRING,
        },
        '7'  => {
            desc => 'ipprefix-type',
            type => \&_IPADDR,
        },
        '8'  => {
            desc => 'protocol-hello-type',
            type => \&_NSTRING,
        },
        '9'  => {
            desc => 'vtp-mgmt-domain-type',
            type => \&_NSTRING,
        },
        '10' => {
            desc => 'native-vlan-type',
            type => \&_NSTRING,
        },
        '11' => {
            desc => 'duplex-type',
            type => \&_NSTRING,
        },
       '16' => {
            desc => 'power-type',
            type => \&_NSTRING,
        },
        '17' => {
            desc => 'mtu-type',
            type => \&_NSTRING,
        },
        '18' => {
            desc => 'trust-type',
            type => \&_NSTRING,
        },
        '19' => {
            desc => 'cos-type',
            type => \&_NSTRING,
        },
        '22' => {
            desc => 'mgmt-address-type',
            type => \&_IPADDR,
        },
        '23' => {
            desc => 'external_port_id_type',
            type => \&_NSTRING,
        },
        '24' => {
            desc => 'power-request-type',
            type => \&_NSTRING,
        },
        '26' => {
            desc => 'power-available-type',
            type => \&_NSTRING,
        },
        '27' => {
            desc => 'unidirectional-mode-type',
            type => \&_NSTRING,
        },
    # Unknow id
    # trigger-type              Trigger Type
    # twoway-connectivity-type  Twoway Connectivity Type
    # vvid-type                 VVID Type
    },
    'dhcp-option' => {
        '1' => {
            desc => 'subnet-mask',
            type => \&_IPADDR,
        },
        '2' => {
            desc => 'time-offset',
            type => \&_STIME,
        },
        '3' => {
            desc => 'routers',
            type => \&_IPADDR,
        },
        '4' => {
            desc => 'time-servers',
            type => \&_IPADDR,
        },
        '5' => {
            desc => 'name-servers',
            type => \&_IPADDR,
        },
        '6' => {
             desc => 'domain-name-servers',
             type => \&_IPADDR,
        },
        '7' => {
             desc => 'log-servers',
             type => \&_IPADDR,
        },
        '8' => {
             desc => 'cookie-servers',
             type => \&_IPADDR,
        },
        '9' => {
             desc => 'lpr-servers',
             type => \&_IPADDR,
        },
        '10' => {
             desc => 'impress-servers',
             type => \&_IPADDR,
        },
        '11' => {
             desc => 'resource-location-servers',
             type => \&_IPADDR,
        },
        '12' => {
             desc => 'host-name',
             type => \&_NSTRING,
             extra => \&_computer_name,
        },
        '13' => {
             desc => 'boot-size',
             type => \&_SHORT,
        },
        '14' => {
             desc => 'merit-dump',
             type => \&_NSTRING,
        },
        '15' => {
             desc => 'domain-name',
             type => \&_NSTRING,
        },
        '16' => {
             desc => 'swap-server',
             type => \&_IPADDR,
        },
        '17' => {
             desc => 'root-path',
             type => \&_NSTRING,
        },
        '18' => {
             desc => 'extensions-path',
             type => \&_NSTRING,
        },
        '19' => {
             desc => 'ip-forwarding',
             type => \&_BOOL,
        },
        '20' => {
             desc => 'non-local-source-routing',
             type => \&_BOOL,
        },
        '21' => {
             desc => 'policy-filters',
             type => \&_IPADDR,
        },
        '22' => {
             desc => 'max-dgram-reassembly',
             type => \&_SHORT,
        },
        '23' => {
             desc => 'default-ip-ttl',
             type => \&_RANGEBYTE,
        },
        '24' => {
             desc => 'path-mtu-aging-timeout',
             type => \&_TIME,
        },
        '25' => {
             desc => 'path-mtu-plateau-tables',
             type => \&_RANGESHORT,
        },
        '26' => {
             desc => 'interface-mtu',
             type => \&_RANGESHORT,
        },
        '27' => {
             desc => 'all-subnets-local',
             type => \&_BOOL,
        },
        '28' => {
             desc => 'broadcast-address',
             type => \&_IPADDR,
        },
        '29' => {
             desc => 'perform-mask-discovery',
             type => \&_BOOL,
        },
        '30' => {
             desc => 'mask-supplier',
             type => \&_BOOL,
        },
        '31' => {
             desc => 'router-discovery',
             type => \&_BOOL,
        },
        '32' => {
             desc => 'router-solicitation-address',
             type => \&_IPADDR,
        },
        '33' => {
             desc => 'static-routes',
             type => \&_IPADDR,
        },
        '34' => {
             desc => 'trailer-encapsulation',
             type => \&_BOOL,
        },
        '35' => {
             desc => 'arp-cache-timeout',
             type => \&_TIME,
        },
        '36' => {
             desc => 'ethernet-encapsulation',
             type => \&_BOOL,
        },
        '37' => {
             desc => 'default-tcp-ttl',
             type => \&_RANGEBYTE,
        },
        '38' => {
             desc => 'tcp-keepalive-interval',
             type => \&_TIME,
        },
        '39' => {
             desc => 'tcp-keepalive-garbage',
             type => \&_BOOL,
        },
        '40' => {
             desc => 'nis-domain',
             type => \&_NSTRING,
        },
        '41' => {
             desc => 'nis-servers',
             type => \&_IPADDR,
        },
        '42' => {
             desc => 'ntp-servers',
             type => \&_IPADDR,
        },
        '43' => {
             desc => 'vendor-encapsulated-options',
             type => \&_BLOB,
        },
        '44' => {
             desc => 'netbios-name-servers',
             type => \&_IPADDR,
        },
        '45' => {
             desc => 'netbios-dd-servers',
             type => \&_IPADDR,
        },
        '46' => {
             desc => 'netbios-node-type',
             type => \&_RANGEBYTE,
        },
        '47' => {
             desc => 'netbios-scope',
             type => \&_NSTRING,
        },
        '48' => {
             desc => 'font-servers',
             type => \&_IPADDR,
        },
        '49' => {
             desc => 'x-display-managers',
             type => \&_IPADDR,
        },
        '50' => {
             desc => 'requested-address',
             type => \&_IPADDR,
        },
        '51' => {
             desc => 'lease-time',
             type => \&_TIME,
        },
        '52' => {
             desc => 'option-overload',
             type => \&_OVERLOAD,
        },
        '53' => {
             desc => 'dhcp-message-type',
             type => \&_MESSAGE,
        },
        '54' => {
             desc => 'server-identifier',
             type => \&_IPADDR,
        },
        '55' => {
             desc  => 'parameter-request-list',
             type  => \&_INT8,
             extra => \&_dhcp_fingerprint,
        },
        '56' => {
             desc => 'message',
             type => \&_NSTRING,
        },
        '57' => {
             desc => 'max-message-size',
             type => \&_SHORT,
        },
        '58' => {
             desc => 'renewal-time',
             type => \&_TIME,
        },
        '59' => {
             desc => 'rebinding-time',
             type => \&_TIME,
        },
        '60' => {
             desc => 'class-identifier',
             type => \&_NSTRING,
             extra => \&_dhcp_vendor,
        },
        '61' => {
             desc => 'client-identifier',
             type => \&_BLOB,
        },
        '62' => {
             desc => 'netware-ip-domain',
             type => \&_NSTRING,
        },
        '63' => {
             desc => 'netware-ip-information',
             type => \&_BLOB,
        },
        '64' => {
             desc => 'nis-plus-domain',
             type => \&_NSTRING,
        },
        '65' => {
             desc => 'nis-plus-servers',
             type => \&_IPADDR,
        },
        '66' => {
             desc => 'tftp-server',
             type => \&_NSTRING,
        },
        '67' => {
             desc => 'boot-file',
             type => \&_NSTRING,
        },
        '68' => {
             desc => 'mobile-ip-home-agents',
             type => \&_IPADDR,
        },
        '69' => {
             desc => 'smtp-servers',
             type => \&_IPADDR,
        },
        '70' => {
             desc => 'pop3-servers',
             type => \&_IPADDR,
        },
        '71' => {
             desc => 'nntp-servers',
             type => \&_IPADDR,
        },
        '72' => {
             desc => 'www-servers',
             type => \&_IPADDR,
        },
        '73' => {
             desc => 'finger-servers',
             type => \&_IPADDR,
        },
        '74' => {
             desc => 'irc-servers',
             type => \&_IPADDR,
        },
        '75' => {
             desc => 'streettalk-servers',
             type => \&_IPADDR,
        },
        '76' => {
             desc => 'streettalk-directory-assistance-servers',
             type => \&_IPADDR,
        },
        '77' => {
             desc => 'user-class-id',
             type => \&_TYPECN,
        },
        '78' => {
             desc => 'slp-directory-agent',
             type => \&_BLOB,
        },
        '79' => {
             desc => 'slp-service-scope',
             type => \&_BLOB,
        },
        '80' => {
             desc => 'rapid-commit',
             type => \&_ZEROSIZE,
        },
        '81' => {
             desc => 'client-fqdn',
             type => \&_BLOB,
        },
        '82' => {
             desc => 'relay-agent-info',
             type => \&_BLOB,
        },
        '83' => {
             desc => 'i-sns',
             type => \&_BLOB,
        },
        '85' => {
             desc => 'nds-servers',
             type => \&_IPADDR,
        },
        '86' => {
             desc => 'nds-tree',
             type => \&_NSTRING,
        },
        '87' => {
             desc => 'nds-context',
             type => \&_NSTRING,
        },
        '88' => {
             desc => 'bcmcs-servers-d',
             type => \&_DNSNAME,
        },
        '89' => {
             desc => 'bcmcs-servers-a',
             type => \&_IPADDR,
        },
        '90' => {
             desc => 'authentication',
             type => \&_BLOB,
        },
        '91' => {
             desc => 'lq-client-last-transaction-time',
             type => \&_TIME,
        },
        '92' => {
             desc => 'lq-associated-ip',
             type => \&_IPADDR,
        },
        '93' => {
             desc => 'pxe-client-arch',
             type => \&_SHORT,
        },
        '94' => {
             desc => 'pxe-client-network-id',
             type => \&_BLOB,
        },
        '95' => {
             desc => 'ldap-url',
             type => \&_NSTRING,
        },
        '97' => {
             desc => 'pxe-client-machine-id',
             type => \&_BLOB,
        },
        '98' => {
             desc => 'user-auth',
             type => \&_NSTRING,
        },
        '99' => {
             desc => 'geo-conf-civic',
             type => \&_BLOB,
        },
        '112' => {
             desc => 'netinfo-parent-server-address',
             type => \&_IPADDR,
        },
        '113' => {
             desc => 'netinfo-parent-server-tag',
             type => \&_NSTRING,
        },
        '114' => {
             desc => 'initial-url',
             type => \&_NSTRING,
        },
        '116' => {
             desc => 'auto-configure',
             type => \&_RANGEBYTE,
        },
        '117' => {
             desc => 'name-service-search',
             type => \&_SHORT,
        },
        '118' => {
             desc => 'subnet-selection',
             type => \&_IPADDR,
        },
        '119' => {
             desc => 'domain-search',
             type => \&_BLOB,
        },
        '120' => {
             desc => 'sip-servers',
             type => \&_BLOB,
        },
        '121' => {
             desc => 'classless-static-route',
             type => \&_BLOB,
        },
        '122' => {
             desc => 'cablelabs-client-configuration',
             type => \&_BLOB,
        },
        '123' => {
             desc => 'geo-conf',
             type => \&_BLOB,
        },
        '124' => {
             desc => 'v-i-vendor-class',
             type => \&_VENDOR_CLASS,
        },
        '125' => {
             desc => 'v-i-vendor-opts',
             type => \&_VENDOR_OPTS,
        },
        '128' => {
             desc => 'mcns-security-server',
             type => \&_IPADDR,
        },
        '161' => {
             desc => 'cisco-leased-ip',
             type => \&_IPADDR,
        },
        '162' => {
             desc => 'cisco-client-requested-host-name',
             type => \&_NSTRING,
        },
        '163' => {
             desc => 'cisco-client-last-transaction-time',
             type => \&_INT,
        },
        '185' => {
             desc => 'vpn-id',
             type => \&_BLOB,
        },
        '220' => {
             desc => 'subnet-alloc',
             type => \&_BLOB,
        },
        '221' => {
             desc => 'cisco-vpn-id',
             type => \&_BLOB,
        },
        '251' => {
             desc => 'cisco-auto-configure',
             type => \&_RANGEBYTE,
        },
        '255' => {
             desc => 'end',
             type => \&_NOLEN,
        },
    },
);


our %CDP_CAPABILITIES_MAP = (
    'Router'                  => 0x001,
    'Trans-Bridge'            => 0x002,
    'Source-Route-Bridge'     => 0x004,
    'Switch'                  => 0x008,
    'Host'                    => 0x010,
    'IGMP'                    => 0x020,
    'Repeater'                => 0x040,
    'VoIP-Phone'              => 0x080,
    'Remotely-Managed-Device' => 0x100,
    'Supports-STP-Dispute'    => 0x200,
    'Two-port Mac Relay'      => 0x400,
);

our %LLDP_CAPABILITIES_MAP = (
    'other'                   => 0x001,
    'repeater'                => 0x002,
    'bridge'                  => 0x004,
    'wlanAccessPoint'         => 0x008,
    'router'                  => 0x010,
    'telephone'               => 0x020,
    'docsisCableDevice'       => 0x040,
    'stationOnly'             => 0x080,
);


=head2 decode_avpair

Decoded the Cisco-AVPair options into an array of hashes

=cut

sub decode_avpair {
    my ($radius_request) = @_;
    my $cisco_avpair = $radius_request->{'Cisco-AVPair'};
    my $option = {};
    $option->{mac} = $radius_request->{'Calling-Station-Id'};
    foreach my $attribute (@$cisco_avpair) {
        my ($type, $binvalue) = split ('=', $attribute);
        
        if( exists $OPTIONS_FILTER{$type} ) {
            $option->{$type} = $TRUE;
            my ($option_name, $value) = unpack("nn/a*", $binvalue);
            if( exists $OPTIONS_FILTER{$type}{$option_name} ) {
                my $option_data = $OPTIONS_FILTER{$type}{$option_name}{type}->($value);
                $option->{$OPTIONS_FILTER{$type}{$option_name}{desc}} = $option_data;
                if( exists $OPTIONS_FILTER{$type}{$option_name}{extra} ) {
                    my $option_sub_data = $OPTIONS_FILTER{$type}{$option_name}{extra}->($option_data);
                    if (ref($option_sub_data) eq 'ARRAY') {
                        $option = { %$option, @{$option_sub_data}};
                    } elsif (ref($option_sub_data) eq 'HASH') {
                        $option = { %$option, %{$option_sub_data}};
                    }
                }
            } else {
                #No filter then you get it raw
                $option->{$option_name} = $value;
            }
        } else {
            #No filter then you get it raw
            $option->{$type} = $binvalue;
        }
    }
    return $option;
}

sub _INT8 {
    my ($value) = @_;
    return join(',',unpack("C*", $value));
}

sub _SHORT {
    my ($value) = @_;
    return $value;
}

sub _NSTRING {
    my ($value) = @_;
    return $value;
}

sub _IPADDR {
    my ($value) = @_;
    return join('.',unpack 'C4',$value);
}

sub _BLOB {
    my ($value) = @_;
    return $value;
}

sub _BOOL {
    my ($value) = @_;
    return $value;
}

sub _DNSNAME {
    my ($value) = @_;
    return $value;
}

sub _INT {
    my ($value) = @_;
    return $value;
}


sub _MESSAGE {
    my ($value) = @_;
    return $value;
}

sub _NOLEN {
    my ($value) = @_;
    return $value;
}

sub _OVERLOAD {
    my ($value) = @_;
    return $value;
}

sub _RANGEBYTE {
    my ($value) = @_;
    return $value;
}

sub _RANGESHORT {
    my ($value) = @_;
    return $value;
}

sub _STIME {
    my ($value) = @_;
    return $value;
}

sub _TIME {
    my ($value) = @_;
    return $value;
}

sub _TYPECN {
    my ($value) = @_;
    return $value;
}

sub _VENDOR_CLASS {
    my ($value) = @_;
    return $value;
}

sub _VENDOR_OPTS {
    my ($value) = @_;
    return $value;
}

sub _ZEROSIZE {
    my ($value) = @_;
    return $value;
}

sub _dhcp_fingerprint {
    my ($value) = @_;
    return {'dhcp_fingerprint' => $value};
}

sub _dhcp_vendor {
    my ($value) = @_;
    return {'dhcp_vendor' => $value};
}

sub _computer_name {
    my ($value) = @_;
    return {'computer_name' => $value};
}

sub _user_agent {
    my ($value) = @_;
    return {'user_agent' => $value};
}

sub _lldp_capabilities {
    my ($value) = @_;
    my %options;
    my %option;
    foreach my $key (keys %LLDP_CAPABILITIES_MAP) {
        if (unpack("N", $value) & $LLDP_CAPABILITIES_MAP{$key}) {
           $option{$key} = $TRUE;
        }
    }
    $options{'LLDP_CAPABILITIES'} = \%option;
    $options{'isPhone'} = 'yes' if(exists $option{'telephone'});
    return \%options;
}

sub _cdp_capabilities {
    my ($value) = @_;
    my %options;
    my %option;
    foreach my $key (keys %CDP_CAPABILITIES_MAP) {
        if (unpack("N", $value) & $CDP_CAPABILITIES_MAP{$key}) {
           $option{$key} = $TRUE;
        }
    }
    $options{'CDP_CAPABILITIES'} = \%option;
    $options{'isPhone'} = 'yes' if(exists $option{'VoIP-Phone'});
    return \%options;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

