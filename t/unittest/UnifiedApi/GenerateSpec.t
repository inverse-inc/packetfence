#!/usr/bin/perl

=head1 NAME

GenerateSpec

=cut

=head1 DESCRIPTION

unit test for GenerateSpec

=cut

use strict;
use warnings;
#

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);

    #Module for overriding configuration paths
    use setup_test_config;
}

use pf::UnifiedApi::GenerateSpec;
use pfappserver::Form::Config::Domain;
use pfappserver::Form::Config::Profile;
use pfappserver::Form::Config::Pfdetect::dhcp;
use pfappserver::Form::Config::Pfdetect::fortianalyser;
use pfappserver::Form::Config::Pfdetect::regex;
use pfappserver::Form::Config::Pfdetect::security_onion;
use pfappserver::Form::Config::Pfdetect::snort;
use pfappserver::Form::Config::Pfdetect::suricata_md5;
use pfappserver::Form::Config::Pfdetect::suricata;
use pf::config qw($fqdn);

use Test::More tests => 4;
use Test::Deep;

#This test will running last
use Test::NoWarnings;

my $schema = pf::UnifiedApi::GenerateSpec::formHandlerToSchema( pfappserver::Form::Config::Domain->new );
is_deeply(
    $schema,
    {
        'DomainList' => {
            'type'       => 'object',
            'properties' => {
                'items' => {
                    'description' => 'List',
                    'type'        => 'array',
                    'items'       => {
                        '$ref' => '#/components/schemas/Domain'
                    }
                }
            },
            '$ref' => '#/components/schemas/Iterable'
        },
        'DomainMeta' => {
            'properties' => {
                'meta' => {
                    'type'       => 'object',
                    'properties' => {
                        'dns_servers' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'ad_server' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'registration' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'dns_name' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'bind_dn' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'workgroup' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'bind_pass' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'ntlm_cache_expiry' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'ou' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'id' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'server_name' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'ntlmv2_only' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'sticky_dc' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'ntlm_cache_source' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'status' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'ntlm_cache' => {
                            '$ref' => '#/components/schemas/Meta'
                        }
                    }
                }
            },
            'type' => 'object'
        },
        'Domain' => {
            'properties' => {
                'server_name' => {
                    'description' =>
'This server\'s name (account name) in your Active Directory. \'%h\' is a placeholder for this server hostname. In a cluster, you must use %h and ensure your hostnames are less than 14 characters. You can mix \'%h\' with a prefix or suffix (ex: \'pf-%h\') ',
                    'type'    => 'string',
                    'default' => '%h'
                },
                'ntlmv2_only' => {
                    'description' =>
'If you enabled "Send NTLMv2 Response Only. Refuse LM & NTLM" (only allow ntlm v2) in Network Security: LAN Manager authentication level',
                    'default' => undef,
                    'type'    => 'string'
                },
                'ntlm_cache_source' => {
                    'description' =>
'The source to use to connect to your Active Directory server for NTLM caching.',
                    'default' => undef,
                    'type'    => 'string'
                },
                'sticky_dc' => {
                    'type'        => 'string',
                    'default'     => '*',
                    'description' =>
'This is used to specify a sticky domain controller to connect to. If not specified, default \'*\' will be used to connect to any available domain controller'
                },
                'status' => {
                    'default'     => 'enabled',
                    'type'        => 'string',
                    'description' => 'Enabled'
                },
                'ntlm_cache' => {
                    'description' =>
                      'Should the NTLM cache be enabled for this domain?',
                    'type'    => 'string',
                    'default' => undef
                },
                'registration' => {
                    'description' =>
'If this option is enabled, the device will be able to reach the Active Directory from the registration VLAN.',
                    'default' => undef,
                    'type'    => 'string'
                },
                'ad_server' => {
                    'description' =>
'The IP address or DNS name of your Active Directory server',
                    'default' => undef,
                    'type'    => 'string'
                },
                'dns_servers' => {
                    'default'     => undef,
                    'type'        => 'string',
                    'description' =>
'The IP address(es) of the DNS server(s) for this domain. Comma delimited if multiple.'
                },
                'dns_name' => {
                    'type'        => 'string',
                    'default'     => undef,
                    'description' => 'The DNS name (FQDN) of the domain.'
                },
                'bind_dn' => {
                    'description' =>
'The username of a Domain Admin to use to join the server to the domain',
                    'type'    => 'string',
                    'default' => undef
                },
                'workgroup' => {
                    'default'     => undef,
                    'type'        => 'string',
                    'description' => 'Workgroup'
                },
                'bind_pass' => {
                    'type'        => 'string',
                    'default'     => undef,
                    'description' =>
'The password of a Domain Admin to use to join the server to the domain. Will not be stored permanently and is only used while joining the domain.'
                },
                'ou' => {
                    'description' =>
'Use a specific OU for the PacketFence account. The OU string read from top to bottom without RDNs and delimited by a \'/\'. E.g. "Computers/Servers/Unix".',
                    'type'    => 'string',
                    'default' => 'Computers'
                },
                'ntlm_cache_expiry' => {
                    'type'        => 'integer',
                    'default'     => 3600,
                    'description' =>
                      'The amount of seconds an entry should be cached.'
                },
                'id' => {
                    'description' =>
'Specify a unique identifier for your configuration.<br/>This doesn\'t have to be related to your domain',
                    'default' => undef,
                    'type'    => 'string'
                }
            },
            'type'     => 'object',
            'required' => [
                'id',
                'workgroup',
                'ad_server',
                'dns_servers',
                'server_name',
                'sticky_dc',
                'dns_name',
                'ou'
            ]
        }
    },
    "Testing the Domain schema",
);

$schema = pf::UnifiedApi::GenerateSpec::formHandlerToSchema(
    pfappserver::Form::Config::Profile->new
);
cmp_deeply(
    $schema,
    {
        'Profile' => {
            'required'   => [ 'id', 'root_module' ],
            'type'       => 'object',
            'properties' => {
                'unreg_on_acct_stop' => {
                    'default'     => 'disabled',
                    'type'        => 'string',
                    'description' =>
'This activates automatic deregistation of devices for the profile if PacketFence receives a RADIUS accounting stop.'
                },
                'redirecturl' => {
                    'default'     => undef,
                    'type'        => 'string',
                    'description' =>
'Default URL to redirect to on registration/mitigation release. This is only used if a per security event redirect URL is not defined.'
                },
                'sources' => {
                    'default' => undef,
                    'items'   => {
                        'description' => 'Source',
                        'type'        => 'string'
                    },
                    'type'        => 'array',
                    'description' => 'Sources'
                },
                'provisioners' => {
                    'description' => 'Provisioners',
                    'items'       => {
                        'type'        => 'string',
                        'description' => 'Provisioner'
                    },
                    'type'    => 'array',
                    'default' => undef
                },
                'advanced_filter' => {
                    'properties' => {
                        'op' => {
                            'type'        => 'string',
                            'description' => 'Value',
                            'default'     => 'and'
                        },
                        'values' => {
                            'default'     => undef,
                            'description' => 'Values',
                            'items'       => {
                                'description' => 'Value',
                                'type'        => 'string'
                            },
                            'type' => 'array'
                        },
                        'field' => {
                            'description' => 'Field',
                            'type'        => 'string',
                            'default'     => undef
                        },
                        'value' => {
                            'default'     => undef,
                            'description' => 'Value',
                            'type'        => 'string'
                        }
                    },
                    'description' => 'Advanced filter',
                    'type'        => 'object',
                    'default'     => {
                        'op' => 'and'
                    }
                },
                'reuse_dot1x_credentials' => {
                    'type'        => 'string',
                    'description' =>
'This option emulates SSO when someone needs to face the captive portal after a successful 802.1x connection. 802.1x credentials are reused on the portal to match an authentication and get the appropriate actions. As a security precaution, this option will only reuse 802.1x credentials if there is an authentication source matching the provided realm. This means, if users use 802.1x credentials with a domain part (username@domain, domain\\username), the domain part needs to be configured as a realm under the RADIUS section and an authentication source needs to be configured for that realm. If users do not use 802.1x credentials with a domain part, only the NULL realm will be match IF an authentication source is configured for it.',
                    'default' => undef
                },
                'show_manage_devices_on_max_nodes' => {
                    'type'        => 'string',
                    'description' => 'Show manage devices on max nodes',
                    'default'     => 'disabled'
                },
                'filter' => {
                    'description' => 'Filters',
                    'type'        => 'array',
                    'items'       => {
                        'type'        => 'object',
                        'description' => 'Filter',
                        'properties'  => {
                            'match' => {
                                'default'     => undef,
                                'type'        => 'string',
                                'description' => 'Match'
                            },
                            'type' => {
                                'default'     => undef,
                                'type'        => 'string',
                                'description' => 'Type'
                            }
                        }
                    },
                    'default' => undef
                },
                'login_attempt_limit' => {
                    'default'     => 0,
                    'description' =>
'Limit the number of login attempts. A value of 0 disables the limit.',
                    'type' => 'integer'
                },
                'sms_pin_retry_limit' => {
                    'type'        => 'integer',
                    'description' =>
'Maximum number of times a user can retry a SMS PIN before having to request another PIN. A value of 0 disables the limit.',
                    'default' => 0
                },
                'mac_auth_recompute_role_from_portal' => {
                    'type'        => 'string',
                    'description' =>
'When enabled, PacketFence will not use the role initialy computed on the portal but will use an authorized source if defined to recompute the role.',
                    'default' => 'disabled'
                },
                'self_service' => {
                    'default'     => undef,
                    'type'        => 'string',
                    'description' => 'Self service'
                },
                'billing_tiers' => {
                    'type'  => 'array',
                    'items' => {
                        'type'        => 'string',
                        'description' => 'Billing tier'
                    },
                    'description' => 'Billing tiers',
                    'default'     => undef
                },
                'default_psk_key' => {
                    'type'        => 'string',
                    'description' =>
'This is the default PSK key when you enable DPSK on this connection profile. The minimum length is eight characters.',
                    'default' => undef
                },
                'dot1x_unset_on_unmatch' => {
                    'type'        => 'string',
                    'description' =>
'When enabled, PacketFence will unset the role of the device if no authentication sources returned one.',
                    'default' => 'disabled'
                },
                'dot1x_recompute_role_from_portal' => {
                    'type'        => 'string',
                    'description' =>
'When enabled, PacketFence will not use the role initialy computed on the portal but will use the dot1x username to recompute the role.',
                    'default' => 'enabled'
                },
                'id' => {
                    'default'     => undef,
                    'type'        => 'string',
                    'description' =>
'A profile id can only contain alphanumeric characters, dashes, period and or underscores.'
                },
                'logo' => {
                    'type'        => 'string',
                    'description' => 'Logo',
                    'default'     => undef
                },
                'description' => {
                    'description' => 'Profile Description',
                    'type'        => 'string',
                    'default'     => undef
                },
                'preregistration' => {
                    'default'     => undef,
                    'description' =>
'This activates preregistration on the connection profile. Meaning, instead of applying the access to the currently connected device, it displays a local account that is created while registering. Note that activating this disables the on-site registration on this connection profile. Also, make sure the sources on the connection profile have "Create local account" enabled.',
                    'type' => 'string'
                },
                'network_logoff' => {
                    'description' =>
'This allows users to access the network logoff page (http://pf.pfdemo.org/networklogoff) in order to terminate their network access (switch their device back to unregistered)',
                    'type'    => 'string',
                    'default' => undef
                },
                'unbound_dpsk' => {
                    'description' => 'Unbound dpsk',
                    'type'        => 'string',
                    'default'     => 'disabled'
                },
                'scans' => {
                    'default'     => undef,
                    'description' => 'Scans',
                    'items'       => {
                        'type'        => 'string',
                        'description' => 'Scan'
                    },
                    'type' => 'array'
                },
                'always_use_redirecturl' => {
                    'description' =>
'Under most circumstances we can redirect the user to the URL he originally intended to visit. However, you may prefer to force the captive portal to redirect the user to the redirection URL.',
                    'type'    => 'string',
                    'default' => undef
                },
                'root_module' => {
                    'default'     => 'default_policy',
                    'description' => 'The Root Portal Module to use',
                    'type'        => 'string'
                },
                'autoregister' => {
                    'description' =>
'This activates automatic registation of devices for the profile. Devices will not be shown a captive portal and RADIUS authentication credentials will be used to register the device. This option only makes sense in the context of an 802.1x authentication.',
                    'type'    => 'string',
                    'default' => undef
                },
                'network_logoff_popup' => {
                    'type'        => 'string',
                    'description' =>
'When the "Network Logoff" feature is enabled, this will have it opened in a popup at the end of the registration process.',
                    'default' => undef
                },
                'block_interval' => {
                    'default' => {
                        'interval' => '10',
                        'unit'     => 'm'
                    },
                    'type'       => 'object',
                    'properties' => {
                        'interval' => {
                            'type'        => 'integer',
                            'description' => 'Interval',
                            'default'     => '10'
                        },
                        'unit' => {
                            'type'        => 'string',
                            'description' => 'Unit',
                            'default'     => 'm'
                        }
                    },
                    'description' =>
'The amount of time a user is blocked after reaching the defined limit for login, sms request and sms pin retry.'
                },
                'locale' => {
                    'default' => undef,
                    'type'    => 'array',
                    'items'   => {
                        'description' => 'Locale',
                        'type'        => 'string'
                    },
                    'description' => 'Locales'
                },
                'vlan_pool_technique' => {
                    'description' => 'The Vlan Pool Technique to use',
                    'type'        => 'string',
                    'default'     => 'username_hash'
                },
                'status' => {
                    'type'        => 'string',
                    'description' => 'Enable profile',
                    'default'     => 'enabled'
                },
                'filter_match_style' => {
                    'type'        => 'string',
                    'description' => 'Filter match style',
                    'default'     => 'any'
                },
                'dpsk' => {
                    'type'        => 'string',
                    'description' =>
'This enables the Dynamic PSK feature on this connection profile. It means that the RADIUS server will answer requests with specific attributes like the PSK key to use to connect on the SSID.',
                    'default' => 'disabled'
                },
                'sms_request_limit' => {
                    'default'     => 0,
                    'description' =>
'Maximum number of times a user can request a SMS PIN. A value of 0 disables the limit.',
                    'type' => 'integer'
                },
                'access_registration_when_registered' => {
                    'description' =>
'This allows already registered users to be able to re-register their device by first accessing the status page and then accessing the portal. This is useful to allow users to extend their access even though they are already registered.',
                    'type'    => 'string',
                    'default' => undef
                }
            }
        },
        'ProfileList' => {
            'type'       => 'object',
            '$ref'       => '#/components/schemas/Iterable',
            'properties' => {
                'items' => {
                    'items' => {
                        '$ref' => '#/components/schemas/Profile'
                    },
                    'type'        => 'array',
                    'description' => 'List'
                }
            }
        },
        'ProfileMeta' => {
            'properties' => {
                'meta' => {
                    'type'       => 'object',
                    'properties' => {
                        'id' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'logo' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'preregistration' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'description' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'dot1x_unset_on_unmatch' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'dot1x_recompute_role_from_portal' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'autoregister' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'root_module' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'network_logoff_popup' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'block_interval' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'locale' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'vlan_pool_technique' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'status' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'filter_match_style' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'access_registration_when_registered' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'dpsk' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'sms_request_limit' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'network_logoff' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'unbound_dpsk' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'scans' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'always_use_redirecturl' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'provisioners' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'sources' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'advanced_filter' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'unreg_on_acct_stop' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'redirecturl' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'sms_pin_retry_limit' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'mac_auth_recompute_role_from_portal' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'self_service' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'billing_tiers' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'default_psk_key' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'reuse_dot1x_credentials' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'show_manage_devices_on_max_nodes' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'filter' => {
                            '$ref' => '#/components/schemas/Meta'
                        },
                        'login_attempt_limit' => {
                            '$ref' => '#/components/schemas/Meta'
                        }
                    }
                }
            },
            'type' => 'object'
        }
    },
    "Testing the Profile schema",
);

$schema = pf::UnifiedApi::GenerateSpec::subTypesSchema(
    "/components/schemas/Pfdetect",
    pfappserver::Form::Config::Pfdetect::dhcp->new,
    pfappserver::Form::Config::Pfdetect::fortianalyser->new,
    pfappserver::Form::Config::Pfdetect::security_onion->new,
    pfappserver::Form::Config::Pfdetect::snort->new,
    pfappserver::Form::Config::Pfdetect::suricata_md5->new,
    pfappserver::Form::Config::Pfdetect::suricata->new,
    pfappserver::Form::Config::Pfdetect::regex->new,
);
cmp_deeply(
    $schema,
    {
        'oneOf' => [
            {
                '$ref' => '#/components/schemas/PfdetectSubTypeDhcp'
            },
            {
                '$ref' => '#/components/schemas/PfdetectSubTypeFortianalyser'
            },
            {
                '$ref' => '#/components/schemas/PfdetectSubTypeSecurityOnion'
            },
            {
                '$ref' => '#/components/schemas/PfdetectSubTypeSnort'
            },
            {
                '$ref' => '#/components/schemas/PfdetectSubTypeSuricataMd5'
            },
            {
                '$ref' => '#/components/schemas/PfdetectSubTypeSuricata'
            },
            {
                '$ref' => '#/components/schemas/PfdetectSubTypeRegex'
            }
        ],
        'discriminator' => {
            'mapping' => {
                'snort'         => '#/components/schemas/PfdetectSubTypeSnort',
                'regex'         => '#/components/schemas/PfdetectSubTypeRegex',
                'fortianalyser' =>
                  '#/components/schemas/PfdetectSubTypeFortianalyser',
                'suricata_md5' =>
                  '#/components/schemas/PfdetectSubTypeSuricataMd5',
                'suricata' => '#/components/schemas/PfdetectSubTypeSuricata',
                'security_onion' =>
                  '#/components/schemas/PfdetectSubTypeSecurityOnion',
                'dhcp' => '#/components/schemas/PfdetectSubTypeDhcp'
            },
            'propertyName' => 'type'
        },
        'description' =>
          'Choose one of the request bodies by discriminator (`type`). '
    },
    "Testing SubType"
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2023 Inverse inc.

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

