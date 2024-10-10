#!/usr/bin/perl

=head1 NAME

OPTIONS

=head1 DESCRIPTION

unit test for OPTIONS

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 18;

#This test will running last
use Test::Mojo;

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $true = bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' );
my $false = bless( do { \( my $o = 0 ) }, 'JSON::PP::Boolean' );

$t->options_ok("/api/v1/config/floating_devices")
  ->status_is(200)
  ->json_is(
    {
        meta => {
            id => {
                default     => undef,
                placeholder => undef,
                required => $true,
                type     => "string",
                implied  => undef,
                pattern => {
                    message => "Mac Address",
                    regex => "[0-9A-Fa-f][0-9A-Fa-f](:[0-9A-Fa-f][0-9A-Fa-f]){5}",
                },
            },
            ip => {
                default     => undef,
                placeholder => undef,
                required => $false,
                type     => "string",
                implied  => undef,
            },
            pvid => {
                default     => undef,
                min_value   => 0,
                placeholder => undef,
                required => $true,
                type     => "integer",
                implied  => undef,
            },
            taggedVlan => {
                default     => undef,
                placeholder => undef,
                required => $false,
                implied  => undef,
                type     => "string"
            },
            trunkPort => {
                default     => undef,
                placeholder => undef,
                required => $false,
                implied  => undef,
                type     => "string"
            }
        },
        status => 200
    }
);


$t->options_ok("/api/v1/config/event_handlers")
  ->status_is(200)
  ->json_is(
    {
      meta => {
        type => {
          allowed => [
            {
              text => "dhcp",
              value => "dhcp"
            },
            {
              text => "fortianalyser",
              value => "fortianalyser"
            },
            {
              text => "nexpose",
              value => "nexpose"
            },
            {
              text => "regex",
              value => "regex"
            },
            {
              text => "security_onion",
              value => "security_onion"
            },
            {
              text => "snort",
              value => "snort"
            },
            {
              text => "suricata",
              value => "suricata"
            },
            {
              text => "suricata_md5",
              value => "suricata_md5"
            },
          ],
          allow_custom => $false,
          type => "string"
        }
      },
      status => 200
    }
);

$t->options_ok("/api/v1/config/provisionings?type=mobileconfig")
  ->status_is(200)->json_is(
    "/meta/server_certificate_path",
    {
        default       => undef,
        placeholder   => undef,
        required      => $false,
        implied  => undef,
        type => "string"
    }
  );

$t->options_ok("/api/v1/config/event_handlers?type=regex")->status_is(200)
  ->json_is(
    {
meta => {
    id => {
        default => undef,
        pattern => {
            message =>
"The id is invalid. The id can only contain alphanumeric characters, dashes, period and underscores.",
            regex => "^[a-zA-Z0-9][a-zA-Z0-9._-]*\$"
        },
        placeholder => undef,
        implied  => undef,
        required    => $true,
        type        => "string"
    },
    path => {
        default     => undef,
        placeholder => undef,
        required    => $true,
        implied  => undef,
        type        => "string"
    },
    rules => {
        default => [],
        item    => {
            default     => undef,
            placeholder => undef,
            properties  => {
                actions => {
                    default => [],
                    item    => {
                        default     => undef,
                        placeholder => undef,
                        properties  => {
                            api_method => {
                                allowed => [
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default => "pid, \$pid"
                                            }
                                        },
                                        text  => "Create new user account",
                                        value => "add_person"
                                    },
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default =>
"mac, \$mac, security_event_id , SECURITY_EVENT_ID"
                                            }
                                        },
                                        text  => "Close security event",
                                        value => "close_security_event"
                                    },
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default => "ip, \$ip"
                                            }
                                        },
                                        text  => "Deregister node by IP",
                                        value => "deregister_node_ip"
                                    },
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default =>
"mac, \$mac, username, \$username"
                                            }
                                        },
                                        text  => "Register node by MAC",
                                        value => "dynamic_register_node"
                                    },
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default => 'mac, $mac'
                                            },
                                        },
                                        text => "fingerbank_lookup",
                                        value => "fingerbank_lookup",
                                    },
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default => 'mac, $mac, ip, $ip, timeout, $timeout'
                                            },
                                        },
                                        text => "firewall_sso_call",
                                        value => "firewall_sso_call",
                                    },
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default => "mac, \$mac"
                                            }
                                        },
                                        text  => "Modify node by MAC",
                                        value => "modify_node"
                                    },
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default => "pid, \$pid"
                                            }
                                        },
                                        text  => "Modify existing user",
                                        value => "modify_person"
                                    },
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default =>
                                                  "mac, \$mac, reason, \$reason"
                                            }
                                        },
                                        text  => "Reevaluate access by MAC",
                                        value => "reevaluate_access"
                                    },
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default =>
                                                  "mac, \$mac, pid, \$pid"
                                            }
                                        },
                                        text  => "Register a new node by PID",
                                        value => "register_node"
                                    },
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default =>
                                                  "ip, \$ip, pid, \$pid"
                                            }
                                        },
                                        text  => "Register node by IP",
                                        value => "register_node_ip"
                                    },
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default => "\$mac"
                                            }
                                        },
                                        text =>
"Release all security events for node by MAC",
                                        value => "release_all_security_events"
                                    },
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default => "role, \$role"
                                            }
                                        },
                                        text  => "role_detail",
                                        value => "role_detail"
                                    },
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default =>
"\$ip, mac, \$mac, net_type, TYPE"
                                            }
                                        },
                                        text  => "Launch a scan for the device",
                                        value => "trigger_scan"
                                    },
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default =>
"mac, \$mac, tid, TYPEID, type, TYPE"
                                            }
                                        },
                                        text  => "Trigger a security event",
                                        value => "trigger_security_event"
                                    },
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default => "pid, \$pid"
                                            }
                                        },
                                        text  => "Deregister node by PID",
                                        value => "unreg_node_for_pid"
                                    },
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default =>
                                                  "mac, \$mac, ip, \$ip"
                                            }
                                        },
                                        text  => "Update ip4log by IP and MAC",
                                        value => "update_ip4log"
                                    },
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default =>
                                                  "mac, \$mac, ip, \$ip"
                                            }
                                        },
                                        text  => "Update ip6log by IP and MAC",
                                        value => "update_ip6log"
                                    },
                                    {
                                        sibling => {
                                            api_parameters => {
                                                default => "role, \$role"
                                            }
                                        },
                                        text  => "Update role configuration",
                                        value => "update_role_configuration"
                                    },
                                    {
                                        text => 'update_switch_role_network',
                                        value => 'update_switch_role_network',
                                        sibling => {
                                            api_parameters => {
                                                default => 'mac, $mac, ip, $ip',
                                            }
                                        },
                                    }
                                ],
                                implied  => undef,
                                default     => undef,
                                placeholder => undef,
                                required    => $true,
                                type        => "string",
                                allow_custom => $false,
                            },
                            api_parameters => {
                                implied  => undef,
                                default     => undef,
                                placeholder => undef,
                                required    => $true,
                                type        => "string"
                            }
                        },
                        required => $false,
                        implied  => undef,
                        type => "object"
                    },
                    placeholder => undef,
                    required => $false,
                    implied  => undef,
                    type => "array"
                },
                ip_mac_translation => {
                    default     => "enabled",
                    placeholder => undef,
                    required => $false,
                    implied  => undef,
                    type => "string",
                    allow_custom => $false,
                    allowed => [
                        {text => 'enabled', value => 'enabled'},
                        {text => 'disabled', value => 'disabled'},
                    ],
                },
                last_if_match => {
                    default     => undef,
                    placeholder => undef,
                    required => $false,
                    implied  => undef,
                    type => "string",
                    allowed => [
                        {text => 'enabled', value => 'enabled'},
                        {text => 'disabled', value => 'disabled'},
                    ],
                    allow_custom => $false,
                },
                name => {
                    default     => undef,
                    placeholder => undef,
                    required    => $true,
                    implied  => undef,
                    type        => "string"
                },
                rate_limit => {
                    default => {
                        interval => 0,
                        unit     => "s"
                    },
                    placeholder => undef,
                    properties  => {
                        interval => {
                            default     => 0,
                            min_value   => 0,
                            placeholder => undef,
                            implied  => undef,
                            required =>
                              $false,
                            type => "integer"
                        },
                        unit => {
                            allowed => [
                                {
                                    text  => "seconds",
                                    value => "s"
                                },
                                {
                                    text  => "minutes",
                                    value => "m"
                                },
                                {
                                    text  => "hours",
                                    value => "h"
                                },
                                {
                                    text  => "days",
                                    value => "D"
                                },
                                {
                                    text  => "weeks",
                                    value => "W"
                                },
                                {
                                    text  => "months",
                                    value => "M"
                                },
                                {
                                    text  => "years",
                                    value => "Y"
                                }
                            ],
                            default     => "s",
                            placeholder => undef,
                            required => $false,
                            implied  => undef,
                            type => "string",
                            allow_custom => $false,
                        }
                    },
                    required => $false,
                    implied  => undef,
                    type => "object"
                },
                regex => {
                    default     => undef,
                    placeholder => undef,
                    required    => $true,
                    implied  => undef,
                    type        => "string"
                }
            },
            required => $false,
            implied  => undef,
            type => "object"
        },
        placeholder => undef,
        required =>
          $false,
        implied  => undef,
        type => "array"
    },
    status => {
        default     => "enabled",
        allow_custom => $false,
        placeholder => undef,
        required => $false,
        type => "string",
        implied  => undef,
        allowed => [
            {text => 'enabled', value => 'enabled'},
            {text => 'disabled', value => 'disabled'},
        ],
    },
    type => {
        default     => "regex",
        placeholder => undef,
        required    => $true,
        implied  => undef,
        type        => "string"
    },
    'rate_limit' => {
        'default' => {
            'unit'     => 's',
            'interval' => 0
        },
        'properties' => {
            'interval' => {
                'placeholder' => undef,
                'implied'     => undef,
                'min_value'   => 0,
                'required'    => $false,
                'default'     => 0,
                'type'        => 'integer'
            },
            'unit' => {
                'type'    => 'string',
                'default' => 's',
                'implied' => undef,
                'allowed' => [
                    {
                        'text'  => 'seconds',
                        'value' => 's'
                    },
                    {
                        'value' => 'm',
                        'text'  => 'minutes'
                    },
                    {
                        'value' => 'h',
                        'text'  => 'hours'
                    },
                    {
                        'value' => 'D',
                        'text'  => 'days'
                    },
                    {
                        'value' => 'W',
                        'text'  => 'weeks'
                    },
                    {
                        'text'  => 'months',
                        'value' => 'M'
                    },
                    {
                        'text'  => 'years',
                        'value' => 'Y'
                    }
                ],
                'required'     => $false,
                'placeholder'  => undef,
                'allow_custom' => $false,
            }
        },
        'type'        => 'object',
        'placeholder' => undef,
        'required'    => $false,
        'implied'     => undef
      },
  },
        status => 200
    }
  );

$t->options_ok("/api/v1/config/base/general")
  ->status_is(200)
  ->json_is(
    {
        meta => {
            dhcpservers => {
                default     => undef,
                placeholder => '127.0.0.1',
                required    => $false,
                implied  => undef,
                type        => "string"
            },
            domain => {
                default     => undef,
                placeholder => 'packetfence.org',
                required    => $false,
                implied  => undef,
                type        => "string"
            },
            hostname => {
                default     => undef,
                placeholder => 'packetfence',
                required    => $false,
                implied  => undef,
                type        => "string"
            },
            timezone => {
                allowed => [
                    {
                        text => "",
                        value => ""
                    },
                    (
                        map { { text => $_, value => $_ }  }  DateTime::TimeZone->all_names()
                    )
                ],
                allow_custom => $false,
                default     => undef,
                placeholder => '',
                required    => $false,
                implied  => undef,
                type        => "string"
            },
            send_anonymous_stats => {
                allowed => [
                    (
                        map { { text => $_, value => $_ }  }  qw(enabled disabled)
                    )
                ],
                type        => "string",
                required => $false,
                implied  => undef,
                placeholder => 'enabled',
                allow_custom => $false,
                default     => undef,
            },
        },
        status => 200
    }
);

$t->options_ok("/api/v1/config/scan/test1")
  ->status_is(200);

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
