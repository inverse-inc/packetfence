package pf::firewalld::zones;

=head1 NAME

pf::firewalld::zones

=cut

=head1 DESCRIPTION

Module to get basic configuration about firewalld zone/interface configurations

=cut


use strict;
use warnings;

use Exporter;
use pf::log;

# need a function that is creating the xml file from the config
# need a function that check if service exist (xml, firewalld-cmd)
# need a function that add interfaces in the config file
# need a function that add services according to interface usage (see how lib/pf/iptables.pm is working)


sub is_proto {
  my $proto = shift;
  my %protos = qw( tcp 0
                   udp 1
                   sctp 2
                   dccp 3);
  if ( exists $protos{$proto} ){
    return $proto;
  }
  get_logger->error("Protocol ($proto) is an unknown protocol.");
  return undef;
}

sub is_source_name {
  my $name = shift;
  my %names = qw(address 0
                 MAC 1
                 ipset 2);
  if ( exists $names{$name} ) {
    return $name;
  }
  get_logger->error("Source $name is unknown.");
  return undef;
}

sub is_service_available {
   my $s = shift;
   my %available_services = get_all_firewalld_services(); # firewall-cmd --get-services 
   foreach $s ( $v.keys() ) {
     if ( exists $available_services{$s} ) {
       return $s;
     }
   }
   get_logger->error("Service $s does not exist.");
   return undef;
}

sub is_protocol_available {
   my $s = shift;
   my %available_protocols = get_all_linux_protocols(); # from /etc/protocols
   foreach $s ( $v.keys() ) {
     if ( exists $available_protocols{$s} ) {
       return $s;
     }
   }
   get_logger->error("Protocol $s does not exist.");
   return undef;
}

sub is_ipset_available {
   my $s = shift;
   my %available_ipsets = get_all_firewalld_ipsets(); # firewall-cmd --get-icmptypes
   foreach $s ( $v.keys() ) {
     if ( exists $available_ipsets{$s} ) {
       return $s;
     }
   }
   get_logger->error("Ipsets $s does not exist.");
   return undef;
}



# need a function that return a structured content of the config file
# Check and return string for xml file
sub create_string_for_xml {
  my $t = shift;
  my $v = shift;
  return $t.'="'.$v.'"';
}

sub create_limit_for_xml {
  my $v = shift;
  my $r = create_string_for_xml("value",$v);
  return "<limit ".$r."\>";
}

sub zone_version {
  my $v = shift;
  if ( length $v ) {
    return create_string_for_xml("version","$v");
  } else {
    return "";
  }
}

sub zone_target {
  my $v = shift;
  my %zone_target_option=qw(ACCEPT 0
                %%REJECT%% 1
                DROP 2
                default 3);
  if ( exists $zone_target_option{$v} ) {
    get_logger->info("Target zone is $v");
    return create_string_for_xml("target",$v);
  } else {
    get_logger->error("Unknown target zone. ==> Apply %%REJECT%%");
    return create_string_for_xml("target","%%REJECT%%");
  }
}

sub zone_interface {
  my $v = shift;
  if ( length $v ) {
    my %all_interfaces = get_all_interfaces();
    if ( not exists $all_interfaces{$v} ) {
      get_logger->error("Unknown interface zone. ==> Apply management interface");
      $v = get_management_interface();
    }
  } else {
    get_logger->error("Unknown interface zone. ==> Apply management interface");
    $v = get_management_interface();
  }
  return $v;
}

sub zone_sources {
  my %v = shift;
  my %t;
  foreach $s ( $v.keys() ) {
    my $s_name = $v{$s}{"name"};
    if ( is_source_name($s_name) ) {
      $t{$s}=$v{$s};
    } else {
      get_logger->error("==> Source is removed.");
    }
  }
  return $t;
}

sub zone_services {
  my %v = shift;
  my %t;
  foreach $s ( $v.keys() ) {
    if ( is_service_available($s) ) {
      $t{$s}=$v{$s};
    } else {
      get_logger->error("==> Service is removed.");
    }
  }
  return %t;
}

sub zone_ports {
  my %v = shift;
  my %t;
  foreach $s ( $v.keys() ) {
    if ( exists $v{$s}{"protocol"} && exists $v{$s}{"portid"} ) {
      if ( is_proto($v{$s}{"protocol"}) ) {
        $t{$s}=$v{$s};
      }
    } else {
      get_logger->error("==> Port is removed.");
    }
  }
  return %t;
}

sub zone_protocols {
  my %v = shift;
  my %t;
  foreach $s ( $v.keys() ) {
    if ( exists $v{$s}{"protocol"} && is_protocol_available($v{$s}{"protocol"}) ) {
      $t{$s}=$v{$s};
    } else {
      get_logger->error("==> Protocol is removed.");
    }
  }
  return %t;
}

sub zone_icmp_blocks {
  my %v = shift;
  my %t;
  foreach $s ( $v.keys() ) {
    if ( is_icmp_blocks_available($s) ) {
      $t{$s}=$v{$s};
    } else {
      get_logger->error("==> Icmp Blocks is removed.");
    }
  }
  return %t;
}


sub zone_forward_ports {
  my %v = shift;
  my %t;
  foreach $s ( $v.keys() ) {
    if ( exists $v{$s}{"protocol"} && exists $v{$s}{"portid"} ) {
      if ( is_proto($v{$s}{"protocol"}) ) {
        if ( exists $v{$s}{"to_port"} ) {
          my $to_port=$v{$s}{"to_port"};
          if ( length $to_port ) {
            $v{$s}{"to_port_xml"} = create_string_for_xml("to-port",$to_port);
          }
        }
        if ( exists $v{$s}{"to_addr"} ) {
          my $to_addr=$v{$s}{"to_addr"};
          if ( length $to_addr ) {
            $v{$s}{"to_addr_xml"} = create_string_for_xml("to-addr",$to_addr);
          }
        }
        $t{$s}=$v{$s};
      } else {
        get_logger->error("==> Forward Port is removed.");
      }
    } else {
      get_logger->error("Forward Port needs Prototype and Portid ==> Forward Port is removed.");
    }
  }
  return %t;
}

sub zone_source_ports {
  my %v = shift;
  my %t;
  foreach $s ( $v.keys() ) {
    if ( exists $v{$s}{"protocol"} && exists $v{$s}{"portid"} ) {
      if ( is_proto($v{$s}{"protocol"}) ) {
        $t{$s}=$v{$s};
      }
    } else {
      get_logger->error("==> Source Port is removed.");
    }
  }
  return %t;
}

sub zone_rules {
  my %v = shift;
  my %t;
  my $flag=0;
  foreach $r ( $v.keys() ) {
    if ( exists $v{$r}{"family"} ) {
      $v{$r}{"family_xml"} = create_string_for_xml("family",$v{$r}{"family"});
    } else {
      $v{$r}{"family_xml"} = "";
    }
    if ( exists $v{$r}{"priority"} ) {
      $v{$r}{"priority_xml"} = create_string_for_xml("priority",$v{$r}{"priority"});
    } else {
      $v{$r}{"priority_xml"} = "";
    }
    if ( exists $v{$r}{"source"} ) {
      my $s_name = $v{$r}{"source"}{"name"};
      if ( is_source_name($s_name) ) {
        if ( exists $v{$r}{"source"}{"invert"} ) {
          $v{$r}{"source"}{"invert_xml"} = create_string_for_xml("invert",$v{$r}{"source"}{"invert"});
        }
      } else {
        $flag=undef;
      }
    }
    if ( exists $v{$r}{"destination"} ) {
      if ( exists $v{$r}{"destination"}{"invert"} ) {
        $v{$r}{"destination"}{"invert_xml"} = create_string_for_xml("invert",$v{$r}{"destination"}{"invert"});
      }
    }
    if ( exists $v{$r}{"match_rules"} ) {
       my %match_rules = $v{$r}{"match_rules"};
       foreach %match_rule ( %match_rules.keys() ) {
         if ( $match_rule{"name"} eq "service" ) {
           if ( not is_service_available($match_rule{"service"}) ) {
             $flag=undef;
           }
         } elsif ( $match_rule{"name"} eq "port" ) {
           if ( exists $match_rule{"portid"} && exists $match_rule{"port_protocol"}) {
             if ( not is_proto($match_rule{"port_protocol"}) ) {
               $flag=undef;
             }
           } else {
             get_logger->error("Port rule does not exist.");
             $flag=undef;
           }
         } elsif ( $match_rule{"name"} eq "protocol" ) {
           if ( not is_proto($match_rule{"protocol"}) ) {
             $flag=undef;
           }
         } elsif ( $match_rule{"name"} eq "forward_port" ) {
           if ( exists $match_rule{"portid"} && exists $match_rule{"protocol"} ) {
             if ( is_proto($match_rule{"protocol"}) ) {
               if ( exists $match_rule{"to_port"} ) {
                 $v{$r}{"match_rules"}{"to_port_xml"} = create_string_for_xml("to-port",$v{$r}{"match_rules"}{"to_port"});
               }
               if ( exists $match_rule{"to_addr"} ) {
                 $v{$r}{"match_rules"}{"to_addr_xml"} = create_string_for_xml("to-addr",$v{$r}{"match_rules"}{"to_addr"});
               }
             } else {
               get_logger->error("Match forward port not used.");
               $flag=undef;
             }
           } else {
             get_logger->error("Match forward port rule needs a portid and a protocol");
             $flag=undef;
           }
         } elsif ( $match_rule{"name"} ne "icmp_block" &&
                   $match_rule{"name"} ne "icmp_type" &&
                   $match_rule{"name"} ne "masquerade" ) {
           print "Unknown match rule.";
           $flag=undef;
         }
       }
    }
    if ( exists $v{$r}{"log_rule"} ) {
      my %log_rule = $v{$r}{"log_rule"};
      if ( $log_rule{"name"} eq "log" ) {
        if ( exists $log_rule{"prefix"} ) {
          $v{$r}{"log_rule"}{"prefix_xml"} = create_string_for_xml("prefix",$log_rule{"prefix"});
        }
        if ( exists $log_rule{"level"} ) {
          $v{$r}{"log_rule"}{"level_xml"} = create_string_for_xml("level",$log_rule{"level"});
        }
        if ( exists $log_rule{"limit_value"} ) {
          $v{$r}{"log_rule"}{"limit_value_xml"} = create_limit_for_xml($log_rule{"limit_value"});
        }
      } elsif ( $log_rule{"name"} eq "nflog" ) {
        if ( exists $log_rule{"group"} ) {
          $v{$r}{"log_rule"}{"group_xml"} = create_string_for_xml("group",$log_rule{"group"});
        }
        if ( exists $log_rule{"prefix"} ) {
          $v{$r}{"log_rule"}{"prefix_xml"} = create_string_for_xml("prefix",$log_rule{"prefix"});
        }
        if ( exists $log_rule{"level"} ) {
          $v{$r}{"log_rule"}{"queue_size_xml"} = create_string_for_xml("queue size",$log_rule{"queue_size"});
        }
        if ( exists $log_rule{"limit_value"} ) {
          $v{$r}{"log_rule"}{"limit_value_xml"} = create_limit_for_xml($log_rule{"limit_value"});
        }
      } elsif ( $log_rule{"name"} ne "" ) {
        print "Unknown log rule.";
        $flag=undef;
      }
    }
    if ( exists $v{$r}{"audit"} ){
      $v{$r}{"audit_xml"} = create_limit_for_xml($v{$r}{"audit"});
    }
    if ( exists $v{$r}{"action"} ){
      my %action = $v{$r}{"action"};
      if ( $action{"name"} eq "accept" ) {
        if ( exists $action{"limit_value"} ) {
          $v{$r}{"action"}{"limit_value_xml"} = create_limit_for_xml($action{"limit_value"});
        }
      } elsif ( $action{"name"} eq "reject" ) {
        if ( exists $action{"type"} ) {
          $v{$r}{"action"}{"type_xml"} = create_string_for_xml("type",$action{"type"});
        }
        if ( exists $action{"limit_value"} ) {
          $v{$r}{"action"}{"limit_value_xml"} = create_limit_for_xml($action{"limit_value"});
        }
      } elsif ( $action{"name"} eq "drop" ) {
        if ( exists $action{"limit_value"} ) {
          $v{$r}{"action"}{"limit_value_xml"} = create_limit_for_xml($action{"limit_value"});
        }
      } elsif ( $action{"name"} eq "mark" ) {
        if ( exists $action{"set"} ) {
          $v{$r}{"action"}{"set_xml"} = create_string_for_xml("set",$action{"set"});
        }
        if ( exists $action{"limit_value"} ) {
          $v{$r}{"action"}{"limit_value_xml"} = create_limit_for_xml($action{"limit_value"});
        }
      } elsif ( $action{"name"} ne "" ) {
        print "Unknown action rule.";
        $flag=undef;
      }
    }
    if ( $flag ){
      $t{$r}=$v{$r};
    } else {
      print "Rule $r{"name"} is not correct and has been removed.";
    }
  }
  return %t;
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
