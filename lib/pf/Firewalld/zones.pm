package pf::Firewalld::zones;

=head1 NAME

pf::Firewalld::zones

=cut

=head1 DESCRIPTION

Module to get basic configuration about firewalld zone/interface configurations

=cut


use strict;
use warnings;

use pf::log;
use pf::Firewalld::services;
use pf::Firewalld::icmptypes;
use pf::Firewalld::ipsets;
use pf::Firewalld::util;
use pf::util::system_protocols;
use pf::config qw(
    $management_network
    %ConfigFirewalld
);


sub firewalld_zones_hash {
  my $std_out = util_firewalld_cmd( "--get-zones" );
  if ( $std_out ne "" ) {
    get_logger->info( "Zones are: $std_out" );
    my @all_services = split / /, $services;
    my %h;
    foreach $val ( @allservices ) {
      $h{$val} = 1;
    }
    return \%h;
  }
  return undef;
}

# need a function that return a structured content of the config file
sub generate_zone_config {
  my $conf = prepare_config( $ConfigFirewalld{"firewalld_zones"} );
  foreach my $k ( keys %{ $conf } ) {
    my $all_interfaces = util_listen_ints_hash();
    if ( !undef $all_interfaces && exists( $all_interfaces->{ $k } ) ) {
      if ( length( $k ) <= 17 ) {
        create_zone_config_file( $conf->{ $k }, $k );
        set_zone( $k );
      } else {
        get_logger->error( "$k can not be bigger than 17 chars" );
      }
    }
  }
}

# need a function that is creating the xml file from the config
# need a function that add interfaces in the config file
sub create_zone_config_file {
  my $conf = shift;
  my $zone = shift;
  util_prepare_version( $conf );
  zone_target( $conf ); 
  zone_interface( $conf );
  zone_sources( $conf );
  zone_services( $conf );
  zone_ports( $conf );
  zone_protocols( $conf );
  zone_icmp_blocks( $conf );
  zone_forward_ports( $conf );
  zone_source_ports( $conf );
  zone_rules( $conf );
  parse_template( $conf, "$Config_path_default_template/zone.xml", "$Config_path_default/zones/$zone.xml" );
}

sub set_zone {
  my $zone = shift;
  if ( util_firewalld_action( "--permanent --zone=$zone --add-interface=$zone" ) ) {
    get_logger->info( "$zone has been applied permanently to $zone" );
  } else {
    get_logger->error( "$zone has NOT been applied to $zone" );
  }
}

# need a function that add services according to interface usage (see how lib/pf/iptables.pm is working)
# need a function that return a structured content of the config file
sub zone_target {
  my $c = shift;
  my $b = 0;
  if ( exists( $c->{"target"} ) ) {
    my %zone_target_option=qw(accept 0
                  reject 1
                  drop 2
                  default 3);
    my $v = lc( $c->{"target"} );
    if ( exists( $zone_target_option{$v} ) ) {
      get_logger->info( "Target zone is $v" );
      if ( $v eq "reject" ) {
        $c->{"target_xml"} = util_create_string_for_xml( "target", "%%REJECT%%" );
      } else {
        $c->{"target_xml"} = util_create_string_for_xml( "target", uc( $v ) );
      }
    } else {
      $b = 1;
    }
  } else {
    $b = 1;
  }
  if ( $b ==1 ) {
    get_logger->error( "Unknown target zone. ==> Apply %%REJECT%%" );
    $c->{"target_xml"} = util_create_string_for_xml( "target", "%%REJECT%%" );
  }
}

sub zone_interface {
  my $c = shift;
  my $b = 0 ;
  if ( exists( $c->{"interface"} ) ) {
    my $v = $c->{"interface"};
    if ( length( $v ) ) {
      my $all_interfaces = util_listen_ints_hash();
      if ( !undef $all_interfaces && not exists( $all_interfaces{$v} ) ) {
        $b = 1;
      }
    }
  } else {
    $b = 1;
  }
  if ( $b ==1 ){
    get_logger->error( "Unknown interface. ==> Apply management interface" );
    $c->{"interface"} = $management_network->{"Tint"};
  }
}

sub zone_sources {
  my $c  = shift;
  my $zc = shift;
  if ( exists( $c->{"sources"} ) ) {
    my @t;
    my $vl = $c->{"sources"} ;
    foreach my $v ( @{ $vl } ) {
      my $st = util_source_or_destination_validation( $v );
      if ( $st eq "" ) {
        get_logger->info( "Source ($v->{"name"}) is added" );
	push( @t, $v} );
      } else {
        get_logger->error( "$st ==> Source ($v->{"name"}) is removed." );
      }
    }
    $c->{"all_sources"} = \@t;
  }
}

sub zone_services {
  my $c = shift;
  if ( exists( $c->{"services"} ) ) {
    my @t;
    my @vl = split( ',', $c{"services"} );
    foreach my $k ( @vl ) {
      if ( !undef is_service_available( $k ) ) {
        push( @t, $k );
      } else {
        get_logger->error( "==> Service is removed." );
      }
    }
    $c->{"all_services"} = \@t;
  }
}

sub zone_ports {
  my $c = shift;
  if ( exists( $c->{"ports"} ) ) {
    my @t;
    my $vl = $c->{"ports"};
    foreach my $k ( @{ $vl } ) {
      if ( exists( $k->{"protocol"} ) && exists( $k->{"portid"} ) ) {
        if ( !undef util_is_firewalld_protocol( $k->{"protocol"} ) ) {
          push( @t, $k );
        }
      } else {
        get_logger->error( "==> Port is removed." );
      }
    }
    $c->{"all_ports"} = \%t;
  }
}

sub zone_protocols {
  my $c = shift;
  if ( exists( $c->{"protocols"} ) ) {
    my @t;
    my @vl = split( ',', $c->{"protocols"} );
    foreach my $k ( @vl ) {
      if ( !undef is_protocol_available( $k ) ) {
        push( @t, $k );
      } else {
        get_logger->error( "==> Protocol ($k) is removed." );
      }
    }
    $c->{"all_protocols"} = \@t;
  }
}

sub zone_icmp_blocks {
  my $c = shift;
  if ( exists( $c->{"icmpblocks"} ) ) {
    my @t;
    my @vl = split( ',', $c{"icmpblocks"} );
    foreach $k ( @vl ) {
      if ( !undef is_icmptypes_available( $k ) ) {
        push(@t, $k);
      } else {
        get_logger->error( "==> Icmpblocks ($k) is removed." );
      }
    }
    $c->{"all_icmpblocks"} = \@t;
  }
}

sub zone_forward_ports {
  my $c = shift;
  if ( exists( $c->{"forwardports"} ) ) {
    my @t;
    my $vl = $c->{"forwardports"};
    foreach my $k ( @{ $vl } ) {
      if ( exists( $k->{"protocol"} ) && exists( $k->{"portid"} ) ) {
        if ( !undef util_is_firewalld_protocol( $k->{"protocol"} ) ) {
          push( @t, $k );
          if ( exists( $k->{"to_port"} ) ) {
            my $to_port = $k->{"to_port"};
            if ( length( $to_port ) ) {
              $k->{"to_port_xml"} = util_create_string_for_xml( "to-port", $to_port );
            }
          }
          if ( exists( $k->{"to_addr"} ) ) {
            my $to_addr = $k->{"to_addr"};
            if ( length( $to_addr ) ) {
              $k->{"to_addr_xml"} = util_create_string_for_xml( "to-addr", $to_addr );
            }
          }
        } else {
          get_logger->error( "==> Forward Port is removed." );
        }
      } else {
        get_logger->error( "Forward Port needs a valid Protocol type and Portid ==> Forward Port is removed." );
      }
    }
    $c->{"all_forwardports"} = \@t;
  }
}

sub zone_source_ports {
  my $c = shift;
  if ( exists( $c->{"sourceports"} ) ) {
    my @t;
    my $vl = $c->{"sourceports"};
    foreach my $k ( @{ $vl } ) {
      if ( exists( $k->{"protocol"} ) && exists( $k->{"portid"} ) ) {
        if ( !undef util_is_firewalld_protocol( $k->{"protocol"} ) ) {
          push( @t, $k );
        } else {
          get_logger->error( "==> Source Port is removed." );
        }
      } else {
        get_logger->error( "Source Port needs a valid Protocol type and Portid ==> Source Port is removed." );
      }
    }
    $c->{"all_sourceports"} = \@t;
  }
}

sub zone_rules {
  my $c = shift;
  if ( exists( $c->{"rules"} ) ) {
    my @t;
    my $vl   = $c->{"rules"};
    my $flag = 0;
    foreach my $h ( @{ $vl } ) {
      if ( exists( $h->{"family"} ) ) {
        $h->{"family_xml"} = util_create_string_for_xml( "family", $h->{"family"} );
      } else {
        $h->{"family_xml"} = "";
      }
      if ( exists( $h->{"priority"} ) ) {
        $h->{"priority_xml"} = util_create_string_for_xml( "priority", $h->{"priority"} );
      } else {
        $h->{"priority_xml"} = "";
      }
      if ( exists( $h->{"source"} ) ) {
        my $source = $h->{"source"};
        my $st = util_source_or_destination_validation( $source );
        if ( $st ne "" ) {
          $flag=undef;
          get_logger->error( "$st ==> Source ($source->{"name"}) is removed." );
        }
        if ( exists( $source->{"invert"} ) ) {
          $source->{"invert_xml"} = util_create_string_for_xml( "invert",$source->{"invert"} );
        }
      }
      if ( exists( $h->{"destination"} ) ) {
        my $dest = $h->{"destination"};
        my $st = util_source_or_destination_validation( $destination );
        if ( $st ne "" ) {
          $flag=undef;
          get_logger->error( "$st ==> Destination ($destination->{"name"}) is removed." );
        }
        if ( exists( $destination->{"invert"} ) ) {
          $destination->{"invert_xml"} = util_create_string_for_xml( "invert",$destination->{"invert"} );
        }
      }

      if ( exists( $h->{"matchrules"} ) ) {
        my $match_rules = $h->{"matchrules"};
        foreach my $h2 ( keys %{ $match_rules } ) {
          my $match_rule = $match_rules->{$h2};
          if ( $match_rule->{"name"} eq "service" ) {
            if ( !defined is_service_available( $match_rule->{"service"} ) ) {
              $flag=undef;
            }
          } elsif ( $match_rule->{"name"} eq "port" ) {
            if ( exists $match_rule->{"portid"} && exists $match_rule->{"port_protocol"} ) {
              if ( !defined util_is_firewalld_protocol( $match_rule->{"port_protocol"} ) ) {
                $flag=undef;
              }
            } else {
              get_logger->error( "Port needs a protocol and a portid." );
              $flag=undef;
            }
          } elsif ( $match_rule->{"name"} eq "protocol" ) {
           if ( !defined util_is_firewalld_protocol( $match_rule->{"protocol"} ) ) {
              $flag=undef;
            }
          } elsif ( $match_rule->{"name"} eq "forward_port" ) {
            if ( exists( $match_rule->{"portid"} ) && exists( $match_rule->{"protocol"} ) ) {
              if ( !undef util_is_firewalld_protocol($match_rule->{"protocol"} ) ) {
                if ( exists( $match_rule->{"to_port"} ) ) {
                  $match_rule->{"to_port_xml"} = util_create_string_for_xml( "to-port", $match_rule->{"to_port"} );
                }
                if ( exists( $match_rule->{"to_addr"} ) ) {
                  $match_rule->{"to_addr_xml"} = util_create_string_for_xml( "to-addr", $match_rule->{"to_addr"} );
                }
              } else {
                get_logger->error( "Match forward port not used." );
                $flag=undef;
              }
            } else {
              get_logger->error( "Match forward port rule needs a portid and a protocol" );
              $flag=undef;
            }
          } elsif ( $match_rule{"name"}-> eq "icmp_block" || $match_rule->{"name"} eq "icmp_type" ) {
            if ( !defined is_icmptypes_available( $match_rule->{"icmp_type"} ) ) {
              $flag=undef;
            }
          } elsif ( $match_rule->{"name"} ne "masquerade" ) {
            get_logger->error( "Unknown match rule." );
            $flag=undef;
          }
        }
      }
      if ( exists( $h->{"log_rule"} ) ) {
        my $log_rule = $h->{"log_rule"};
        if ( $log_rule->{"name"} eq "log" ) {
          if ( exists( $log_rule->{"prefix"} ) ) {
            $log_rule->{"prefix_xml"} = util_create_string_for_xml( "prefix", $log_rule->{"prefix"} );
          }
          if ( exists( $log_rule->{"level"} ) ) {
            $log_rule->{"level_xml"} = util_create_string_for_xml( "level", $log_rule->{"level"} );
          }
          if ( exists( $log_rule->{"limit_value"} ) ) {
            $log_rule->{"limit_value_xml"} = util_create_limit_for_xml( $log_rule->{"limit_value"} );
          }
        } elsif ( $log_rule->{"name"} eq "nflog" ) {
          if ( exists( $log_rule->{"group"} ) ) {
            $log_rule->{"group_xml"} = util_create_string_for_xml( "group", $log_rule->{"group"} );
          }
          if ( exists( $log_rule->{"prefix"} ) ) {
            $log_rule->{"prefix_xml"} = util_create_string_for_xml( "prefix", $log_rule->{"prefix"} );
          }
          if ( exists( $log_rule->{"level"} ) ) {
            $log_rule->{"queue_size_xml"} = util_create_string_for_xml( "queue size", $log_rule->{"queue_size"} );
          }
          if ( exists( $log_rule->{"limit_value"} ) ) {
            $log_rule->{"limit_value_xml"} = util_create_limit_for_xml( $log_rule->{"limit_value"} );
          }
        } else {
          get_logger->error( "Unknown log rule." );
          $flag=undef;
        }
      }
      if ( exists( $h->{"audit"} ) ){
        $h->{"audit_xml"} = util_create_limit_for_xml( $h->{"audit"} );
      }
      if ( exists( $h->{"action"} ) ){
        my $action = $h->{"action"};
        if ( $action->{"name"} eq "accept" ) {
          if ( exists( $action->{"limit_value"} ) ) {
            $action->{"limit_value_xml"} = util_create_limit_for_xml( $action->{"limit_value"} );
          }
        } elsif ( $action->{"name"} eq "reject" ) {
          if ( exists( $action->{"type"} ) ) {
            $action->{"type_xml"} = util_create_string_for_xml( "type", $action->{"type"} );
          }
          if ( exists( $action->{"limit_value"} ) ) {
            $action->{"limit_value_xml"} = util_create_limit_for_xml( $action->{"limit_value"} );
          }
        } elsif ( $action->{"name"} eq "drop" ) {
          if ( exists( $action->{"limit_value"} ) ) {
            $action->{"limit_value_xml"} = util_create_limit_for_xml( $action->{"limit_value"} );
          }
        } elsif ( $action->{"name"} eq "mark" ) {
          if ( exists( $action->{"set"} ) ) {
            $action->{"set_xml"} = util_create_string_for_xml( "set", $action->{"set"} );
          }
          if ( exists( $action->{"limit_value"} ) ) {
            $action->{"limit_value_xml"} = util_create_limit_for_xml( $action->{"limit_value"} );
          }
        } elsif ( $action->{"name"} ne "" ) {
          get_logger->error( "Unknown action rule." );
          $flag=undef;
        }
      }
      if ( defined $flag ){
        push( @t, $h );
      } else {
        get_logger->error(" Rule $h->{"name"} is not correct and has been removed." );
      }
    }
    $c->{"all_rules"} = \@t;
  }
}


=head1
Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2023 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
