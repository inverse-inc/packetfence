#!/usr/bin/perl

=head1 NAME

Kafka

=head1 DESCRIPTION

unit test for Kafka

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 7;
use Test::Mojo;
use Test2::Tools::Compare qw(bag end item subset);
use pf::UnifiedApi::Controller::Config::Kafka;
use pf::util qw(listify);

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $base_url = '/api/v1/config/kafka';

$t->get_ok($base_url)
  ->status_is(200);

$t->options_ok($base_url)
    ->status_is(200)
    ->json_is(
        {
            "meta" => {
                "admin" => {
                    "default"     => undef,
                    "implied"     => undef,
                    "placeholder" => undef,
                    "properties"  => {
                        "pass" => {
                            "default"     => undef,
                            "implied"     => undef,
                            "placeholder" => "**************",
                            "required"    => 0,
                            "type"        => "string"
                        },
                        "user" => {
                            "default"     => undef,
                            "implied"     => undef,
                            "placeholder" => undef,
                            "required"    => 0,
                            "type"        => "string"
                        }
                    },
                    "required" => 0,
                    "type"     => "object"
                },
                "auths" => {
                    "default" => [],
                    "implied" => undef,
                    "item"    => {
                        "default"     => undef,
                        "implied"     => undef,
                        "placeholder" => undef,
                        "properties"  => {
                            "pass" => {
                                "default"     => undef,
                                "implied"     => undef,
                                "placeholder" => "**************",
                                "required"    => 0,
                                "type"        => "string"
                            },
                            "user" => {
                                "default"     => undef,
                                "implied"     => undef,
                                "placeholder" => undef,
                                "required"    => 0,
                                "type"        => "string"
                            }
                        },
                        "required" => 0,
                        "type"     => "object"
                    },
                    "placeholder" => undef,
                    "required"    => 0,
                    "type"        => "array"
                },
                "cluster" => {
                    "default" => [],
                    "implied" => undef,
                    "item"    => {
                        "default"     => undef,
                        "implied"     => undef,
                        "placeholder" => undef,
                        "properties"  => {
                            "name" => {
                                "default"     => undef,
                                "implied"     => undef,
                                "placeholder" => undef,
                                "required"    => 0,
                                "type"        => "string"
                            },
                            "value" => {
                                "default"     => undef,
                                "implied"     => undef,
                                "placeholder" => undef,
                                "required"    => 0,
                                "type"        => "string"
                            }
                        },
                        "required" => 0,
                        "type"     => "object"
                    },
                    "placeholder" => undef,
                    "required"    => 0,
                    "type"        => "array"
                },
                "host_configs" => {
                    "default" => [],
                    "implied" => undef,
                    "item"    => {
                        "default"     => undef,
                        "implied"     => undef,
                        "placeholder" => undef,
                        "properties"  => {
                            "config" => {
                                "default" => [],
                                "implied" => undef,
                                "item"    => {
                                    "default"     => undef,
                                    "implied"     => undef,
                                    "placeholder" => undef,
                                    "properties"  => {
                                        "name" => {
                                            "default"     => undef,
                                            "implied"     => undef,
                                            "placeholder" => undef,
                                            "required"    => 0,
                                            "type"        => "string"
                                        },
                                        "value" => {
                                            "default"     => undef,
                                            "implied"     => undef,
                                            "placeholder" => undef,
                                            "required"    => 0,
                                            "type"        => "string"
                                        }
                                    },
                                    "required" => 0,
                                    "type"     => "object"
                                },
                                "placeholder" => undef,
                                "required"    => 0,
                                "type"        => "array"
                            },
                            "host" => {
                                "default"     => undef,
                                "implied"     => undef,
                                "placeholder" => undef,
                                "required"    => 0,
                                "type"        => "string"
                            }
                        },
                        "required" => 0,
                        "type"     => "object"
                    },
                    "placeholder" => undef,
                    "required"    => 0,
                    "type"        => "array"
                },
                "iptables" => {
                    "default"     => undef,
                    "implied"     => undef,
                    "placeholder" => undef,
                    "properties"  => {
                        "clients" => {
                            "default" => [],
                            "implied" => undef,
                            "item"    => {
                                "default"     => undef,
                                "implied"     => undef,
                                "placeholder" => undef,
                                "required"    => 0,
                                "type"        => "string"
                            },
                            "placeholder" => undef,
                            "required"    => 0,
                            "type"        => "array"
                        },
                        "cluster_ips" => {
                            "default" => [],
                            "implied" => undef,
                            "item"    => {
                                "default"     => undef,
                                "implied"     => undef,
                                "placeholder" => undef,
                                "required"    => 0,
                                "type"        => "string"
                            },
                            "placeholder" => undef,
                            "required"    => 0,
                            "type"        => "array"
                        }
                    },
                    "required" => 0,
                    "type"     => "object"
                }
            },
            status => 200,
        }
);

my $config = {
   "iptables" =>  {
     "clients" =>  [],
     "cluster_ips" =>  []
   },
   "admin" =>  {
     "user" =>  "admin",
     "pass" =>  "admin-pass"
   },
   "auths" =>  [
     {
       "user" =>  "guardicore",
       "pass" =>  "guardicore-pass"
     }
   ],
   "cluster" =>  [
     {
       "name" =>  "CLUSTER_ID",
       "value" =>  ""
     }
   ],
  "host_configs" =>  [
    {
      "host" =>  "172-105-101-170.ip.linodeusercontent.com",
      "config" =>  [
        {
          "name" =>  "KAFKA_NODE_ID",
          "value" =>  "1"
        },
        {
          "name" =>  "KAFKA_ADVERTISED_LISTENERS",
          "value" =>  "INTERNAL://172.105.101.170:29092,EXTERNAL://172.105.101.170:9092"
        }
      ]
    }
  ]
};

Test2::Tools::Compare::is(
    pf::UnifiedApi::Controller::Config::Kafka::flatten_item($config),
    bag {
        item {section => "iptables", params => {clients => "", cluster_ips => ''} };
        item {section => "admin", params => {user => "admin", pass => 'admin-pass'} };
        item {section => "auth guardicore", params => { pass => 'guardicore-pass'} };
        item {section => "cluster", params => { CLUSTER_ID => ''} };
        item {section => "172-105-101-170.ip.linodeusercontent.com", params => { KAFKA_NODE_ID => '1', KAFKA_ADVERTISED_LISTENERS => 'INTERNAL://172.105.101.170:29092,EXTERNAL://172.105.101.170:9092'} };
        end();
    },
);

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

