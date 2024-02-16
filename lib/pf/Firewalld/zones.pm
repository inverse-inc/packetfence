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
use pf::firewalld::services;
use pf::firewalld::policies;
use pf::firewalld::icmptypes;
use pf::firewalld::ipsets;
use pf::firewalld::util;
use pf::util::system_protocols;
use pf::config::util;
use pf::config qw(
    %Config
    $management_network
    %ConfigFirewalld
    @listen_ints
);


# need a function that return a structured content of the config file
sub generate_zone_config {
  my %conf = prepare_config($ConfigFirewalld{"firewalld_zones"});
  foreach $k ( keys $conf ) {
    create_zone_config_file(%conf);
    set_zone($k);
  }
}

# need a function that is creating the xml file from the config
# need a function that add interfaces in the config file
sub prepare_config {
  my %zconf = shift;
  my %conf;
  foreach $k ( keys %zconf ) {
    my @v = split( " ", $k);
    if ( scalar @v == 1 ) {
      $conf{"$v[0]"} = $zconf{$k};
    } elsif ( scalar @v == 2 ) {
      my $def = $v[1];
      $def =~ s/[1-9]*$//g # remove tailed digits
      my %s;
      $s{$v[1]} = $zconf{$k};
      $conf{"$v[0]"}{$def."s"} = %s;
    } elsif ( scalar @v == 3 ) {
      my ( %s0, %s1 );
      # level1
      my $def1 = $v[1];
      $def1 =~ s/[1-9]*$//g # remove tailed digits
      $s1{$v[2]} = $zconf{$k};
      $s0{$v[1]} = %s1;
      $conf{"$v[0]"}{$def1."s"} = %s0;
    } elsif ( scalar @v == 4 ) {
      my ( %s0, %s1, %s2 );
      # level1
      my $def1 = $v[1];
      $def1 =~ s/[1-9]*$//g # remove tailed digits
      # level2
      my $def2 = $v[2];
      $def2 =~ s/[1-9]*$//g # remove tailed digits
      $s2{$v[3]} = $zconf{$k};
      $s1{$v[2]}{$def2."s"} = %s2;
      $s0{$v[1]} = %s1;
      $conf{"$v[0]"}{$def1."s"} = %s;
    } else {
      get_logger->error("$zone has an unknown configuration");
    }
  }
  return %conf;
}

sub create_zone_config_file {
  my %conf = shift;
  %conf = zone_version(%conf);
  %conf = zone_target(%conf); 
  %conf = zone_interface($conf);
  %conf = zone_sources(%conf);
  %conf = zone_services(%conf);
  %conf = zone_ports(%conf);
  %conf = zone_protocols(%conf);
  %conf = zone_icmp_blocks(%conf);
  %conf = zone_forward_ports(%conf);
  %conf = zone_source_ports(%conf);
  %conf = zone_rules(%conf);

  # Create the xml file

  # parse_template(%conf); # from pf::lib::util

  return %conf;
}

sub set_zone {
  my $zone = shift;
  my $fd_cmd = get_firewalld_cmd();
  if ( $fd_cmd ) {
    `$fd_cmd --permanent --zone=$zone --add-interface=$zone`;
    get_logger->info("$zone has been applied permanently to $zone");
  }
}

# need a function that add services according to interface usage (see how lib/pf/iptables.pm is working)
# need a function that return a structured content of the config file
sub zone_version {
  my %c = shift;
  if (exists $c{"version"} ) {
    my $v = $c{"version"};
    if ( length $v ) {
      $c{"version_xml"} = create_string_for_xml("version","$v");
    } else {
      $c{"version_xml"} = "";
    }
  }
  return %lzc;
}

sub zone_target {
  my %c = shift;
  my $b = 0;
  if ( exists $c{"target"} ) {
    my %zone_target_option=qw(accept 0
                  reject 1
                  drop 2
                  default 3);
    my $v = lc($c{"target"});
    if ( exists $zone_target_option{$v} ) {
      get_logger->info("Target zone is $v");
      $c{"target_xml"} = create_string_for_xml("target",$v);
    } else {
      $b = 1;
    }
  } else {
    $b = 1;
  }
  if ( $b ==1 ){
    get_logger->error("Unknown target zone. ==> Apply %%REJECT%%");
    $c{"target_xml"} = create_string_for_xml("target","%%REJECT%%");
  }
  return %s;
}

sub zone_interface {
  my %c = shift;
  my $b = 0 ;
  if ( exists $c{"interface"} ) {
    my $v = $c{"interface"};
    if ( length $v ) {
      my %all_interfaces = listen_ints_hash();
      if ( not exists $all_interfaces{$v} ) {
        $b = 1;
      }
    }
  } else {
    $b = 1;
  }
  if ( $b ==1 ){
    get_logger->error("Unknown interface. ==> Apply management interface");
    $c{"interface"} = $management_network->{"Tint"};
  }
  return %c;
}

sub zone_sources {
  my %c = shift;
  my %t;
  if ( exists $c{"sources"} ) {
    my %vl = $c{"sources"} ;
    foreach $k ( keys %vl ) {
      my $st = source_or_destination_validation($vl{$k});
      if ( $st eq "" ) {
        get_logger->info("Source ($k) is added");
        $t{$k}=$vl{$k};
      } else {
        get_logger->error("$st ==> Source ($k) is removed.");
      }
    }
  }
  $c{"all_sources"} = %t;
  return %c;
}

sub zone_services {
  my %c = shift;
  my @t;
  if ( exists $c{"services"} ) {
    my @vl = split(',', $c{"services"});
    foreach $k ( @vl ) {
      if ( is_service_available($k) ) {
        push(@t, $k);
      } else {
        get_logger->error("==> Service is removed.");
      }
    }
  }
  $c{"all_services"} = @t;
  return %c;
}

sub zone_ports {
  my %c = shift;
  my %t;
  if ( exists $c{"ports"} ) {
    my %vl = $c{"ports"};
    foreach $k ( keys %vl ) {
      if ( exists $vl{$k}{"protocol"} && exists $vl{$k}{"portid"} ) {
        if ( is_fd_protocol($vl{$k}{"protocol"}) ) {
          $t{$k}=$vl{$k};
        }
      } else {
        get_logger->error("==> Port is removed.");
      }
    }
  }
  $c{"all_ports"} = %t;
  return %c;
}

sub zone_protocols {
  my %c = shift;
  my @t;
  if ( exists $c{"protocols"} ) {
    my @vl = split(',', $c{"protocols"});
    foreach $k ( @vl ) {
      if ( is_protocol_available($k) ) {
        push(@t, $k);
      } else {
        get_logger->error("==> Protocol ($k) is removed.");
      }
    }
  }
  $c{"all_protocols"} = @t;
  return %c;
}

sub zone_icmp_blocks {
  my %c = shift;
  my @t;
  if ( exists $c{"icmpblocks"} ) {
    my @vl = split(',', $c{"icmpblocks"});
    foreach $k ( @vl ) {
      if ( is_icmptypes_available($k) ) {
        push(@t, $k);
      } else {
        get_logger->error("==> Icmpblocks ($k) is removed.");
      }
    }
  }
  $c{"all_icmpblocks"} = @t;
  return %c;
}

sub zone_forward_ports {
  my %c = shift;
  my %t;
  if ( exists $c{"forwardports"} ) {
    my %vl = $c{"forwardports"};
    foreach $k ( keys %vl ) {
      if ( exists $vl{$k}{"protocol"} && exists $vl{$k}{"portid"} ) {
        if ( is_fd_protocol($vl{$k}{"protocol"}) ) {
          $t{$k}=$vl{$k};
          if ( exists $t{$k}{"to_port"} ) {
            my $to_port=$t{$k}{"to_port"};
            if ( length $to_port ) {
              $t{$k}{"to_port_xml"} = create_string_for_xml("to-port",$to_port);
            }
          }
          if ( exists $t{$k}{"to_addr"} ) {
            my $to_addr=$t{$k}{"to_addr"};
            if ( length $to_addr ) {
              $t{$k}{"to_addr_xml"} = create_string_for_xml("to-addr",$to_addr);
            }
          }
        } else {
          get_logger->error("==> Forward Port is removed.");
        }
      } else {
        get_logger->error("Forward Port needs a valid Protocol type and Portid ==> Forward Port is removed.");
      }
    }
  }
  $c{"all_forwardports"} = %t;
  return %c;
}

sub zone_source_ports {
  my %c = shift;
  my %t;
  if ( exists $c{"sourceports"} ) {
    my %vl = $c{"sourceports"};
    foreach $k ( keys %vl ) {
      if ( exists $vl{$k}{"protocol"} && exists $vl{$k}{"portid"} ) {
        if ( is_fd_protocol($vl{$k}{"protocol"}) ) {
          $t{$k}=$vl{$k};
        } else {
          get_logger->error("==> Source Port is removed.");
        }
      } else {
        get_logger->error("Source Port needs a valid Protocol type and Portid ==> Source Port is removed.");
      }
    }
  }
  $c{"all_sourceports"} = %t;
  return %c;
}

sub zone_rules {
  my %c = shift;
  my %t;
  if ( exists $c{"rules"} ) {
    my %vl = $c{"rules"};
    my $b = 0;
    foreach $k ( keys %vl ) {
      my %r = $vl{$k};
      if ( exists $r{"family"} ) {
        $vl{$k}{"family_xml"} = create_string_for_xml("family",$r{"family"});
      } else {
        $vl{$k}{"family_xml"} = "";
      }
      if ( exists $r{"priority"} ) {
        $vl{$k}{"priority_xml"} = create_string_for_xml("priority",$r{"priority"});
      } else {
        $vl{$k}{"priority_xml"} = "";
      }
      if ( exists $r{"source"} ) {
        my $st = source_or_destination_validation($r{"source"});
        if ( $st ne "" ) {
          $flag=undef;
          get_logger->error("$st ==> Source ($r{"source"}{"name"}) is removed.");
        }
        if ( exists $r{"source"}{"invert"} ) {
          $vl{$k}{"source"}{"invert_xml"} = create_string_for_xml("invert",$r{"source"}{"invert"});
        }
      }
      if ( exists $r{"destination"} ) {
        my $st = source_or_destination_validation($r{"destination"});
        if ( $st ne "" ) {
          $flag=undef;
          get_logger->error("$st ==> Destination ($r{"destination"}{"name"}) is removed.");
        }
        if ( exists $r{"destination"}{"invert"} ) {
          $vl{$k}{"destination"}{"invert_xml"} = create_string_for_xml("invert",$r{"destination"}{"invert"});
        }
      }
      if ( exists $r{"service"} ) {
        if (not is_service_available($v{$r}{"service"}) ) {
          $flag=undef;
        }
        if ( exists $r{"destination"}{"invert"} ) {
          $vl{$k}{"destination"}{"invert_xml"} = create_string_for_xml("invert",$r{"destination"}{"invert"});
        }
      }
      if ( exists $r{"matchrules"} ) {
        my %match_rules = $v{$r}{"matchrules"};
        foreach $k2 ( keys %match_rules ) {
          my %match_rule = $match_rules{$k2};
          if ( $match_rule{"name"} eq "service" ) {
            if ( not is_service_available($match_rule{"service"}) ) {
              $flag=undef;
            }
          } elsif ( $match_rule{"name"} eq "port" ) {
            if ( exists $match_rule{"portid"} && exists $match_rule{"port_protocol"}) {
              if ( not is_fd_protocol($match_rule{"port_protocol"}) ) {
                $flag=undef;
              }
            } else {
              get_logger->error("Port needs a protocol and a portid.");
              $flag=undef;
            }
          } elsif ( $match_rule{"name"} eq "protocol" ) {
           if ( not is_fd_protocol($match_rule{"protocol"}) ) {
              $flag=undef;
            }
          } elsif ( $match_rule{"name"} eq "forward_port" ) {
            if ( exists $match_rule{"portid"} && exists $match_rule{"protocol"} ) {
              if ( is_fd_protocol($match_rule{"protocol"}) ) {
                if ( exists $match_rule{"to_port"} ) {
                  $vl{$k}{"matchrules"}{$k2}{"to_port_xml"} = create_string_for_xml("to-port",$match_rule{"to_port"});
                }
                if ( exists $match_rule{"to_addr"} ) {
                  $vl{$k}{"matchrules"}{$k2}{"to_addr_xml"} = create_string_for_xml("to-addr",$match_rule{"to_addr"});
                }
              } else {
                get_logger->error("Match forward port not used.");
                $flag=undef;
              }
            } else {
              get_logger->error("Match forward port rule needs a portid and a protocol");
              $flag=undef;
            }
          } elsif ( ( $match_rule{"name"} eq "icmp_block" || $match_rule{"name"} eq "icmp_type" ) {
            if ( not is_icmptypes_available($match_rule{"icmp_type"} ) {
              $flag=undef;
            }
          } elsif ( $match_rule{"name"} ne "masquerade" ) {
            get_logger->error("Unknown match rule.");
            $flag=undef;
          }
        }
      }
      if ( exists $r{"log_rule"} ) {
        my %log_rule = $r{"log_rule"};
        if ( $log_rule{"name"} eq "log" ) {
          if ( exists $log_rule{"prefix"} ) {
            $vl{$k}{"log_rule"}{"prefix_xml"} = create_string_for_xml("prefix",$log_rule{"prefix"});
          }
          if ( exists $log_rule{"level"} ) {
            $vl{$k}{"log_rule"}{"level_xml"} = create_string_for_xml("level",$log_rule{"level"});
          }
          if ( exists $log_rule{"limit_value"} ) {
            $vl{$k}{"log_rule"}{"limit_value_xml"} = create_limit_for_xml($log_rule{"limit_value"});
          }
        } elsif ( $log_rule{"name"} eq "nflog" ) {
          if ( exists $log_rule{"group"} ) {
            $vl{$k}{"log_rule"}{"group_xml"} = create_string_for_xml("group",$log_rule{"group"});
          }
          if ( exists $log_rule{"prefix"} ) {
            $vl{$k}{"log_rule"}{"prefix_xml"} = create_string_for_xml("prefix",$log_rule{"prefix"});
          }
          if ( exists $log_rule{"level"} ) {
            $vl{$k}{"log_rule"}{"queue_size_xml"} = create_string_for_xml("queue size",$log_rule{"queue_size"});
          }
          if ( exists $log_rule{"limit_value"} ) {
            $vl{$k}{"log_rule"}{"limit_value_xml"} = create_limit_for_xml($log_rule{"limit_value"});
          }
        } else {
          print "Unknown log rule.";
          $flag=undef;
        }
      }
      if ( exists $r{"audit"} ){
        $vl{$r}{"audit_xml"} = create_limit_for_xml($r{"audit"});
      }
      if ( exists $r{"action"} ){
        my %action = $r{"action"};
        if ( $action{"name"} eq "accept" ) {
          if ( exists $action{"limit_value"} ) {
            $vl{$k}{"action"}{"limit_value_xml"} = create_limit_for_xml($action{"limit_value"});
          }
        } elsif ( $action{"name"} eq "reject" ) {
          if ( exists $action{"type"} ) {
            $vl{$k}{"action"}{"type_xml"} = create_string_for_xml("type",$action{"type"});
          }
          if ( exists $action{"limit_value"} ) {
            $vl{$k}{"action"}{"limit_value_xml"} = create_limit_for_xml($action{"limit_value"});
          }
        } elsif ( $action{"name"} eq "drop" ) {
          if ( exists $action{"limit_value"} ) {
            $vl{$k}{"action"}{"limit_value_xml"} = create_limit_for_xml($action{"limit_value"});
          }
        } elsif ( $action{"name"} eq "mark" ) {
          if ( exists $action{"set"} ) {
            $vl{$k}{"action"}{"set_xml"} = create_string_for_xml("set",$action{"set"});
          }
          if ( exists $action{"limit_value"} ) {
            $vl{$k}{"action"}{"limit_value_xml"} = create_limit_for_xml($action{"limit_value"});
          }
        } elsif ( $action{"name"} ne "" ) {
          print "Unknown action rule.";
          $flag=undef;
        }
      }
      if ( $flag ){
        $t{$k}=$v{$k};
      } else {
        print "Rule $r{"name"} is not correct and has been removed.";
      }
    }
  }
  $c{"all_rules"} = %t;
  return %c;

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
