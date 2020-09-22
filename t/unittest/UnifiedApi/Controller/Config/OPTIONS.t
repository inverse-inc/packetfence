#!/usr/bin/perl

=head1 NAME

OPTIONS

=head1 DESCRIPTION

unit test for OPTIONS

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 18;

#This test will running last
use Test::Mojo;
use pf::dal::tenant;

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
                pattern => {
                    message => "Mac Address",
                    regex => "[0-9A-Fa-f][0-9A-Fa-f](:[0-9A-Fa-f][0-9A-Fa-f]){5}",
                },
            },
            ip => {
                default     => undef,
                placeholder => undef,
                required => $false,
                type     => "string"
            },
            pvid => {
                default     => undef,
                min_value   => 0,
                placeholder => undef,
                required => $true,
                type     => "integer"
            },
            taggedVlan => {
                default     => undef,
                placeholder => undef,
                required => $false,
                type     => "string"
            },
            trunkPort => {
                default     => undef,
                placeholder => undef,
                required => $false,
                type     => "string"
            }
        },
        status => 200
    }
);


$t->options_ok("/api/v1/config/syslog_parsers")
  ->status_is(200)
  ->json_is(
    {
      meta => {
        type => {
          allowed => [
            {
              text => "fortianalyser",
              value => "fortianalyser"
            },
            {
              text => "snort",
              value => "snort"
            },
            {
              text => "nexpose",
              value => "nexpose"
            },
            {
              text => "security_onion",
              value => "security_onion"
            },
            {
              text => "suricata_md5",
              value => "suricata_md5"
            },
            {
              text => "regex",
              value => "regex"
            },
            {
              text => "dhcp",
              value => "dhcp"
            },
            {
              text => "suricata",
              value => "suricata"
            }
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
        required_when => {
            eap_type => 25,
        },
        type => "string"
    }
  );

$t->options_ok("/api/v1/config/syslog_parsers?type=regex")->status_is(200)
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
        required    => $true,
        type        => "string"
    },
    path => {
        default     => undef,
        placeholder => undef,
        required    => $true,
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
                                    }
                                ],
                                default     => undef,
                                placeholder => undef,
                                required    => $true,
                                type        => "string",
                                allow_custom => $false,
                            },
                            api_parameters => {
                                default     => undef,
                                placeholder => undef,
                                required    => $true,
                                type        => "string"
                            }
                        },
                        required => $false,
                        type => "object"
                    },
                    placeholder => undef,
                    required => $false,
                    type => "array"
                },
                ip_mac_translation => {
                    default     => "enabled",
                    placeholder => undef,
                    required => $false,
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
                            type => "string",
                            allow_custom => $false,
                        }
                    },
                    required => $false,
                    type => "object"
                },
                regex => {
                    default     => undef,
                    placeholder => undef,
                    required    => $true,
                    type        => "string"
                }
            },
            required =>
              $false,
            type => "object"
        },
        placeholder => undef,
        required =>
          $false,
        type => "array"
    },
    status => {
        default     => "enabled",
        allow_custom => $false,
        placeholder => undef,
        required => $false,
        type => "string",
        allowed => [
            {text => 'enabled', value => 'enabled'},
            {text => 'disabled', value => 'disabled'},
        ],
    },
    type => {
        default     => "regex",
        placeholder => undef,
        required    => $true,
        type        => "string"
    },
    tenant_id => {
        default     => 1,
        placeholder => undef,
        required    => $false,
        type        => "string",
        allow_custom => $false,
        allowed => [
            map { $_->{id} != 0 ? ( { value => $_->{id}, text => $_->{name} }) : () } @{pf::dal::tenant->search->all};
        ],
    }
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
                type        => "string"
            },
            domain => {
                default     => undef,
                placeholder => 'packetfence.org',
                required    => $false,
                type        => "string"
            },
            hostname => {
                default     => undef,
                placeholder => 'packetfence',
                required    => $false,
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
                type        => "string"
            }
        },
        status => 200
    }
);

$t->options_ok("/api/v1/config/scan/test1")
  ->status_is(200);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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
