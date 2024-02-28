package pf::Firewalld::util;

=head1 NAME

pf::Firewalld::util

=cut

=head1 DESCRIPTION

Module with utils function for firewalld

=cut

use strict;
use warnings;

BEGIN {
  use Exporter ();
  our ( @ISA, @EXPORT );
  @ISA = qw(Exporter);
  @EXPORT = qw(
    util_prepare_firewalld_config
    util_get_firewalld_bin
    util_get_firewalld_cmd
    util_listen_ints_hash
    util_source_or_destination_validation
    util_prepare_version
    util_create_string_for_xml
    util_create_limit_for_xml
    util_is_firewalld_protocol
    util_is_fd_source_name
    util_firewalld_cmd
    util_firewalld_action
    util_reload_firewalld
    util_target
    util_all_ports
    util_all_services
    util_all_protocols
    util_all_icmp_blocks
    util_all_sources
    util_all_forward_ports
    util_all_source_ports
    util_all_rules
  );
}

use pf::log;
use pf::util;
use pf::config qw(
    @listen_ints
);
use pf::Firewalld::services qw(
    is_service_available
);
use pf::Firewalld::icmptypes qw(
    is_icmptypes_available
);
use pf::Firewalld::ipsets qw(
    is_ipset_type_available
    is_ipset_available
);
use pf::file_paths qw(
    $firewalld_config_path_default 
    $firewalld_config_path_default_template
    $firewalld_config_path_applied
);
use pf::util::system_protocols;

use Data::Dumper;

sub util_prepare_firewalld_config {
  my $conf = shift;
  foreach my $k ( keys %{ $conf } ){
    my $val = $conf->{$k};
    foreach my $k2 ( keys %{ $val } ){
      my @vals = split ( ",", $val->{$k2} );
      my @nvals;
      foreach my $v ( @vals ){
        if ( $v ne $k && exists ( $conf->{$v} ) ){
          push( @nvals, $conf->{$v} );
        }
      }
      if ( @nvals ){
        $val->{$k2} = \@nvals;
      }
    }
  }
}

sub util_get_firewalld_bin {
  my $fbin = `which firewalld`;
  if ( $fbin =~ "/usr/bin/which: no" ){
    get_logger->error( "Firewalld has not been found on the system." );
    return undef;
  }
  $fbin =~ s/\n//g;
  return $fbin;
}

sub util_get_firewalld_cmd {
  my $fbin = `which firewall-cmd`;
  if ( $fbin =~ "/usr/bin/which: no" ){
    get_logger->error( "Firewalld has not been found on the system." );
    return undef;
  }
  $fbin =~ s/\n//g;
  return $fbin;
}

sub util_listen_ints_hash {
  my %listen_ints_hash;
  my @interfaces = `basename -a /sys/class/net/*`;
  foreach my $int (@interfaces){
    $int =~ s/\n//g;
    if ( $int !~ "veth" ) {
      $listen_ints_hash{ $int } = 1;
    }
  }
  return \%listen_ints_hash;
}

sub util_source_or_destination_validation {
  my $s = shift;
  my $st = "";
  if ( $s->{"name"} eq "address" && not ( valid_ip_range( $s->{"address"} ) || valid_mac_or_ip( $s->{"address"} ) ) ){
    $st .= "Address is not a valid ip or an ip range.";
  } elsif ( $s->{"name"} eq "mac" && not valid_mac_or_ip( $s->{"mac"} ) ){
    $st .= "Mac is not a valid mac.";
  } elsif ( $s->{"name"} eq "ipset" && not is_ipset_available( $s->{"ipset"} ) ){
    $st .= "Ipset is unknown.";
  }
  return $st;
}

sub util_prepare_version {
  my $c = shift;
  if (exists $c->{"version"} ){
    my $v = $c->{"version"};
    if ( length $v ) {
      $c->{"version_xml"} = util_create_string_for_xml( "version", "$v" );
    } else {
      $c->{"version_xml"} = "";
    }
  }
}

sub util_target {
  my $c = shift;
  my $b = 0;
  if ( exists( $c->{"target"} ) ) {
    my %target_option=qw(accept 0
                  reject 1
                  drop 2
                  default 3);
    my $v = lc( $c->{"target"} );
    if ( exists( $target_option{$v} ) ) {
      get_logger->info( "Target zone is $v" );
      if ( $v eq "reject" ) {
        $c->{"target_xml"} = util_create_string_for_xml( "target", "%%REJECT%%" );
      } elsif ($v eq "default") {
        $c->{"target_xml"} = util_create_string_for_xml( "target", $v );
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
    get_logger->error( "Unknown target. ==> Apply %%REJECT%%" );
    $c->{"target_xml"} = util_create_string_for_xml( "target", "%%REJECT%%" );
  }
}

sub util_all_ports {
  my $c = shift;
  if ( exists( $c->{"ports"} ) ) {
    my @t;
    my $vl = $c->{"ports"};
    foreach my $k ( @{ $vl } ) {
      if ( exists( $k->{"protocol"} ) && exists( $k->{"portid"} ) ) {
        if ( defined util_is_firewalld_protocol( $k->{"protocol"} ) ) {
          push( @t, $k );
        }
      } else {
        get_logger->error( "==> Port is removed." );
      }
    }
    $c->{"all_ports"} = \@t;
  }
}

sub util_all_services {
  my $c = shift;
  if ( exists( $c->{"services"} ) ) {
    my @t;
    my @vl = split( ',', $c->{"services"} );
    foreach my $k ( @vl ) {
      if ( defined is_service_available( $k ) ) {
        push( @t, $k );
      } else {
        get_logger->error( "==> Service is removed." );
      }
    }
    $c->{"all_services"} = \@t;
  }
}

sub util_all_protocols {
  my $c = shift;
  if ( exists( $c->{"protocols"} ) ) {
    my @t;
    my @vl = split( ',', $c->{"protocols"} );
    foreach my $k ( @vl ) {
      if ( defined is_protocol_available( $k ) ) {
        push( @t, $k );
      } else {
        get_logger->error( "==> Protocol ($k) is removed." );
      }
    }
    $c->{"all_protocols"} = \@t;
  }
}

sub util_all_icmp_blocks {
  my $c = shift;
  if ( exists( $c->{"icmpblocks"} ) ) {
    my @t;
    my @vl = split( ',', $c->{"icmpblocks"} );
    foreach my $k ( @vl ) {
      if ( defined is_icmptypes_available( $k ) ) {
        push( @t, $k );
      } else {
        get_logger->error( "==> Icmpblocks ($k) is removed." );
      }
    }
    $c->{"all_icmpblocks"} = \@t;
  }
}

sub util_all_sources {
  my $c  = shift;
  my $zc = shift;
  if ( exists( $c->{"sources"} ) ) {
    my @t;
    my $vl = $c->{"sources"} ;
    foreach my $v ( @{ $vl } ) {
      my $st = util_source_or_destination_validation( $v );
      if ( $st eq "" ) {
        get_logger->info( "Source ($v->{'name'}) is added" );
        push( @t, $v );
      } else {
        get_logger->error( "$st ==> Source ($v->{'name'}) is removed." );
      }
    }
    $c->{"all_sources"} = \@t;
  }
}

sub util_all_forward_ports {
  my $c = shift;
  if ( exists( $c->{"forwardports"} ) ) {
    my @t;
    my $vl = $c->{"forwardports"};
    foreach my $k ( @{ $vl } ) {
      if ( exists( $k->{"protocol"} ) && exists( $k->{"portid"} ) ) {
        if ( defined util_is_firewalld_protocol( $k->{"protocol"} ) ) {
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

sub util_all_source_ports {
  my $c = shift;
  if ( exists( $c->{"sourceports"} ) ) {
    my @t;
    my $vl = $c->{"sourceports"};
    foreach my $k ( @{ $vl } ) {
      if ( exists( $k->{"protocol"} ) && exists( $k->{"portid"} ) ) {
        if ( defined util_is_firewalld_protocol( $k->{"protocol"} ) ) {
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

sub util_all_rules {
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
          get_logger->error( "$st ==> Source ($source->{'name'}) is removed." );
        }
        if ( exists( $source->{"invert"} ) ) {
          $source->{"invert_xml"} = util_create_string_for_xml( "invert",$source->{"invert"} );
        }
      }
      if ( exists( $h->{"destination"} ) ) {
        my $destination = $h->{"destination"};
        my $st = util_source_or_destination_validation( $destination );
        if ( $st ne "" ) {
          $flag=undef;
          get_logger->error( "$st ==> Destination ($destination->{'name'}) is removed." );
        }
        if ( exists( $destination->{"invert"} ) ) {
          $destination->{"invert_xml"} = util_create_string_for_xml( "invert",$destination->{"invert"} );
        }
      }
      if ( exists( $h->{"match_rules"} ) ) {
        my $match_rules = $h->{"match_rules"};
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
              if ( defined util_is_firewalld_protocol($match_rule->{"protocol"} ) ) {
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
          } elsif ( $match_rule->{"name"} eq "icmp_block" || $match_rule->{"name"} eq "icmp_type" ) {
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
        get_logger->error( "Rule $h->{'name'} is not correct and has been removed." );
      }
    }
    $c->{"all_rules"} = \@t;
  }
}

sub util_create_string_for_xml {
  my $t = shift;
  my $v = shift;
  return $t.'="'.$v.'"';
}

sub util_create_limit_for_xml {
  my $v = shift;
  my $r = util_create_string_for_xml( "value", $v );
  return "<limit ".$r."\>";
}

sub util_is_firewalld_protocol {
  my $proto = shift;
  my %protos = qw( tcp 0
                   udp 1
                   sctp 2
                   dccp 3);
  if ( exists $protos{$proto} ){
    return $proto;
  }
  get_logger->error( "Protocol ($proto) is an unknown protocol." );
  return undef;
}

sub util_is_fd_source_name {
  my $name = shift;
  my %names = qw(address 0
                 mac 1
                 ipset 2);
  if ( exists $names{$name} ){
    return $name;
  }
  get_logger->error( "Source $name is unknown." );
  return undef;
}

# Firewalld cd
sub util_firewalld_cmd {
  my $action = shift;
  my $firewalld_cmd = util_get_firewalld_cmd();
  if ( $firewalld_cmd ){
    my $cmd = $firewalld_cmd." ".$action;
    my $std_out = `$cmd`;
    my $exit_status = `echo "$?"`;
    $exit_status =~ s/\n//g;
    if ($exit_status eq "0") {
      get_logger->info( "Command exit with success" );
      $std_out  =~ s/\n//g;
      return $std_out;
    } else {
      get_logger->error( "Command exit without success" );
    }
  }
  return "";
}

# Firewalld action
sub util_firewalld_action {
  my $action= shift;
  my $result = util_firewalld_cmd( $action );
  if ( $result eq "success" ){
    return 1;
  } else {
    return 0;
  }
}

# need a function that reload the service
sub util_reload_firewalld {
  if ( firewalld_action( "--reload" ) ){
    get_logger->info( "Reload Success" );
    return 1;
  } else {
    get_logger->error( "Reload Failed" );
    return 0;
  }
}


=head1 AUTHOR

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
