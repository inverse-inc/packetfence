package pf::Firewalld::util;

=head1 NAME

pf::Firewalld::util

=cut

=head1 DESCRIPTION

Module with util functions for firewalld

=cut

use strict;
use warnings;
use File::Basename;
use File::Copy;
use Template;
use IPC::Open3 qw(open3);
use Symbol qw(gensym);

BEGIN {
  use Exporter ();
  our ( @ISA, @EXPORT );
  @ISA = qw(Exporter);
  @EXPORT = qw(
    util_prepare_firewalld_config
    util_prepare_firewalld_config_simple
    util_get_firewalld_bin
    util_get_firewalld_cmd
    util_set_default_zone
    util_chain
    util_rich_rule
    util_direct_rule
    util_zone_set_forward
    util_zone_set_masquerade
    util_listen_ints_hash
    util_source_or_destination_validation
    util_prepare_version
    util_target
    util_prepare_priority
    util_all_ports
    util_all_services
    util_all_protocols
    util_all_helpers
    util_all_icmp_blocks
    util_all_sources
    util_all_forward_ports
    util_all_source_ports
    util_all_rules
    util_create_string_for_xml
    util_create_limit_for_xml
    util_is_firewalld_protocol
    util_is_fd_source_name
    util_firewalld_cmd
    util_firewalld_job
    util_reload_firewalld
    util_get_name_files_from_dir
    util_create_config_file
    util_getServiveState 
    is_service_available
    is_zone_available
    is_icmptypes_available
    is_ipset_type_available
    is_ipset_available
    is_helper_available
    fd_fix_file_permissions
    fd_fix_dir_permissions
  );
}

use pf::log;
use pf::util;
use pf::config qw(
    @listen_ints
);
use pf::file_paths qw(
    $firewalld_config_path_generated 
    $firewalld_config_path_default_template
    $firewalld_config_path_applied
);
use pf::util::system_protocols qw ( is_protocol_available );
use Data::Dumper;

sub util_prepare_firewalld_config {
  my $conf = shift;
  foreach my $k ( keys %{ $conf } ){
    if ( exists $conf->{$k}->{"short"} ) {
      fix_val_children($conf,$k);
    }
  }
}

sub util_prepare_firewalld_config_simple {
  my $conf = shift;
  foreach my $k ( keys %{ $conf } ){
    fix_val_children($conf,$k);
  }
}

sub fix_val_children {
  my $conf =  shift;
  my $k  =  shift;
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

sub util_zone_set_forward {
  my $zone = shift;
  my $action = shift;
  my $job = " --permanent --zone=".$zone." --".$action."-forward";
  util_firewalld_job( $job );
  util_reload_firewalld();
}

sub util_zone_set_masquerade {
  my $zone = shift;
  my $action = shift;
  my $job = " --permanent --zone=".$zone." --".$action."-masquerade";
  util_firewalld_job( $job );
  util_reload_firewalld();
}

sub util_chain {
  my $ipv   = shift;
  my $table = shift;
  my $chain = shift;
  my $action = shift;
  if ( ! defined $ipv || $ipv eq ""){
    get_logger->error( "The util_chain ipv is not defined or empty. default will be 'ipv4'." );
    $ipv = "ipv4";
  }
  if ( ! defined $table || $table eq ""){
    get_logger->error( "The util_chain table is not defined or empty. default will be 'filter'." );
    $table = "filter";
  }
  if ( ! defined $action || $action eq ""){
    get_logger->error( "The util_chain action is not defined or empty. default will be 'add'." );
    $action = "add";
  }
  get_logger->info( "The util_chain action is $action on $ipv with table $table." );
  my $job = " --permanent --direct --".$action."-chain ".$ipv." ".$table." ".$chain;
  util_firewalld_job( $job );
  util_reload_firewalld();
}

sub util_rich_rule {
  my $zone = shift;
  my $rule = shift;
  my $action = shift;
  if ( ! defined $action || $action eq "" ){
    get_logger->error( "The util_rich_rule action is not defined or empty. default will be add." );
    $action = "add";
  }
  get_logger->info( "The util_rich_rule action is \"$action\"." );
  my $job = " --permanent --zone=".$zone." --".$action."-rich-rule='".$rule."'";
  util_firewalld_job( $job );
  util_reload_firewalld();
}

sub util_direct_rule {
  my $rule = shift;
  my $action = shift;
  if ( ! defined $action || $action eq ""){
    get_logger->error( "The util_direct_rule action is not defined or empty. default will be add." );
    $action = "add";
  }
  get_logger->info( "The util_direct_rule type is \"$action\"." );
  my $job = " --permanent --direct --".$action."-rule $rule";
  util_firewalld_job( $job );
  util_reload_firewalld();
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
  $listen_ints_hash{ "block" } = 1;
  $listen_ints_hash{ "drop" } = 1;
  $listen_ints_hash{ "trusted" } = 1;
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
  my $type = "";
  my $c = shift;
  $type = shift;
  if ( defined $type && $type eq "zone" ) {
    $type = "%%";
  } else {
    $type = "";
  }
  my $b = 0;
  if ( exists( $c->{"target"} ) ) {
    my %target_option=qw(accept 0
                  reject 1
                  drop 2
                  default 3
                  continue 4
    );
    my $v = lc( $c->{"target"} );
    if ( exists( $target_option{$v} ) ) {
      get_logger->info( "Target is $v" );
      if ( $v eq "reject" ) {
        $c->{"target_xml"} = util_create_string_for_xml( "target", $type."REJECT".$type );
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
    use Data::Dumper;
    get_logger->error( "Unknown target for". print Dumper ($c)."\n==> Apply ".$type."REJECT".$type );
    $c->{"target_xml"} = util_create_string_for_xml( "target", $type."REJECT".$type );
  }
}

sub util_prepare_priority {
  my $c = shift;
  if ( exists( $c->{"priority"} ) ) {
    $c->{"priority_xml"} = util_create_string_for_xml( "priority", $c->{"priority"} );
  } else {
    $c->{"priority_xml"} = "";
  }
}

sub util_all_ports {
  my $c = shift;
  if ( exists( $c->{"ports"} ) ) {
    my @t;
    my $vl = $c->{"ports"};
    foreach my $k ( @{ $vl } ) {
      if ( exists( $k->{"type"} ) && exists( $k->{"port"} ) ) {
        if ( defined util_is_firewalld_protocol( $k->{"type"} ) ) {
          push( @t, $k );
        }
      } else {
        get_logger->error( "==> Port is removed. Needs type and port" );
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
        get_logger->error( "==> Service ($k) is removed." );
      }
    }
    $c->{"all_services"} = \@t;
  }
}

sub util_all_protocols {
  my $c = shift;
  if ( exists( $c->{"protocols"} ) ) {
    my @t;
    my $vl = $c->{"protocols"};
    foreach my $k ( @{ $vl } ) {
      my $val = $k->{ "value" };
      if ( defined is_protocol_available( $val ) ) {
        push( @t, $val );
      } else {
        get_logger->error( "==> Protocol ($val) is removed." );
      }
    }
    $c->{"all_protocols"} = \@t;
  }
}

sub util_all_helpers {
  my $c = shift;
  if ( exists( $c->{"helpers"} ) ) {
    my @t;
    my $vl = $c->{"helpers"};
    foreach my $k ( @{ $vl } ) {
      my $val = $k->{ "name" };
      if ( defined is_helper_available( $val ) ) {
        push( @t, $val );
      } else {
        get_logger->error( "==> Helper ($val) is removed." );
      }
    }
    $c->{"all_helpers"} = \@t;
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
  if ( exists( $c->{"sources"} ) && length($c->{"sources"}) > 0 ) {
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
      if ( exists( $k->{"type"} ) && exists( $k->{"port"} ) ) {
        if ( defined util_is_firewalld_protocol( $k->{"type"} ) ) {
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
  if ( exists $protos{ lc( $proto ) } ){
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
    $cmd = untaint_chain( $cmd ) ; 
    my $std_out = `$cmd`;
    my $exit_status = `echo "$?"`;
    $exit_status =~ s/\n//g;
    $std_out  =~ s/\n//g;
    if ($exit_status eq "0") {
      get_logger->info( "Command \"$cmd\" exit with success." );
      return $std_out;
    } else {
      get_logger->error( "Command \"$cmd\" exit without success. Error is: ".$std_out );
    }
  }
  return "";
}

# Firewalld action
sub util_firewalld_job {
  my $action= shift;
  my $result = util_firewalld_cmd( $action );
  if ( $result =~ "success" ){
    return 1;
  } else {
    return 0;
  }
}

sub util_set_default_zone {
  my $zone= shift;
  my $default_zone = util_firewalld_cmd( " --get-default-zone" );
  if ( $zone ne $default_zone ) {
    if ( util_firewalld_job( " --set-default-zone=$zone" ) ){
      util_firewalld_cmd( " --permanent --zone=$zone --add-masquerade" );
      util_reload_firewalld();
      get_logger->info( "Set default zone is a success" );
    } else {
      get_logger->error( "Set default zone failed" );
    }
  } else {
    get_logger->error( "The default zone is already set" );
  }
}

# need a function that reload the service
sub util_reload_firewalld {
  if ( util_firewalld_job( "--reload" ) ){
    get_logger->info( "Reload Success" );
    return 1;
  } else {
    get_logger->error( "Reload Failed" );
    return 0;
  }
}

sub util_get_name_files_from_dir {
  my $dir_name = shift;
  my @files = read_dir_recursive("$firewalld_config_path_generated/$dir_name");
  if ( scalar( @files ) > 0 ) {
    my %xml;
    foreach my $file ( @files ) {
      my $b = basename($file);
      $b =~ s/\.[^.]+$//;
      if (length($b)>2) {
        $xml{$b} = 1;
      }
    }
    if (scalar(keys(%xml))>0) {
      return \%xml;

    }
  }
  return undef;
}

sub util_create_config_file {
  my $ext   = "";
  my $conf  = shift;
  my $type  = shift;
  my $name  = shift;
  my $tname = shift;
  $ext   = shift;
  if ( ! defined $ext || $ext eq '' ) {
    $ext = ".xml";
  }
  my $sep = "";
  if ( $type ne "") {
    $sep = "/";
  }
  my $dir = $firewalld_config_path_generated."".$sep."".$type;
  pf_make_dir($dir);
  my $file = $dir."/".$name."".$ext;
  my $file_template = $firewalld_config_path_default_template."/".$tname."".$ext;
  if ( -e $file ) {
    my $bk_file = $file.".bk";
    if ( -e $bk_file ) {
      unlink $bk_file or warn "Could not unlink $file: $!";
    }
    copy( $file, $bk_file ) or die "copy failed: $!";
  }
  my $tt = Template->new(
    ABSOLUTE => 1,
  );
  $tt->process( $file_template, $conf, $file ) or die $tt->error();
  fd_fix_file_permissions($file);
}

# Services Functions
sub firewalld_services_hash {
  my $std_out = util_firewalld_cmd( "--get-services" );
  if ( $std_out ne "" ) {
    get_logger->info( "Services are: $std_out" );
    my @services = split( / /, $std_out );
    my %h;
    foreach my $val ( @services ) {
      $h{ $val } = 1;
    }
    return \%h;
  }
  my $xml_files = util_get_name_files_from_dir("services");
  if ( defined $xml_files ) {
    return $xml_files;
  }
  get_logger->error( "No Service available" );
  return undef;
}

sub is_service_available {
  my $s = shift;
  my $available_services = firewalld_services_hash();
  if ( exists $available_services->{ $s } ) {
    return $s;
  }
  get_logger->error( "Service $s does not exist." );
  return undef;
}

# Icmptypes Functions
sub firewalld_icmptypes_hash {
  my $std_out = util_firewalld_cmd( "--get-icmptypes" );
  if ( $std_out ne "" ) {
    get_logger->info("Icmptypes are: $std_out");
    my @all_c = split( / /, $std_out );
    my %h;
    foreach my $val ( @all_c ) {
      $h{ $val } = 1;
    }
    return \%h;
  }
  my $xml_files = util_get_name_files_from_dir("ipsets");
  if ( defined $xml_files ) {
    return $xml_files;
  }
  return undef;
}

sub is_icmptypes_available {
  my $s = shift;
  my $available_icmptypes = firewalld_icmptypes_hash();
  if ( defined $available_icmptypes && exists( $available_icmptypes->{$s} ) ) {
    return $s;
  }
  get_logger->error( "Icmp type $s does not exist." );
  return undef;
}

# Ipset types Functions
sub firewalld_ipset_types_hash {
  my $std_out = util_firewalld_cmd( "--get-ipset-types" );
  if ( $std_out ne "" ) {
    get_logger->info( "Ipset types are: $std_out" );
    my @all_c = split( / /, $std_out );
    my %h;
    foreach my $val ( @all_c ) {
      $h{ $val } = 1;
    }
    return \%h;
  }
  # https://github.com/firewalld/firewalld/blob/main/src/firewall/core/ipset.py#L21
  my %default_ipsets = ( "hash:ip" => 1,
                         "hash:ip,port" => 1,
                         "hash:ip,port,ip" => 1,
                         "hash:ip,port,net" => 1,
                         "hash:ip,mark" => 1,
                         "hash:net" => 1,
                         "hash:net,net" => 1,
                         "hash:net,port" => 1,
                         "hash:net,port,net" => 1,
                         "hash:net,iface" => 1,
                         "hash:mac" => 1
  );
  return \%default_ipsets;
}

sub util_getServiveState {
    my ($services, $props) = @_;
    return [] if @$services == 0;
    my @args = ((map { ('-p' => $_) } @$props), @$services);
    my $pid = open3(my $chld_in, my $chld_out, my $chld_err = gensym, 'sudo', 'systemctl', 'show', @args);
    waitpid( $pid, 0 );
    my $child_exit_status = $? >> 8;
    my $out = do {
        local $/ = undef;
        <$chld_out>
    };
    close($chld_in);
    close($chld_out);
    close($chld_err);

    my @states;
    my $state = {};
    for my $line (split '\n', $out) {
        if ($line eq '') {
            push @states, $state;
            $state = {};
            next;
        }

        my ($k, $v) = split('=', $line, 2);
        $state->{$k} = $v;
    }

    push @states, $state;
    return \@states;
}

sub is_ipset_type_available {
  my $s = shift;
  my $available_ipset_types = firewalld_ipset_types_hash();
  if ( defined $available_ipset_types &&  exists( $available_ipset_types->{ $s } ) ) {
    return $s;
  }
  get_logger->error( "Ipset type $s does not exist." );
  return undef;
}

# Ipsets Functions
sub firewalld_ipsets_hash {
  my $std_out = util_firewalld_cmd( "--get-ipsets" );
  if ( $std_out ne "" ) {
    get_logger->info( "Ipsets are: $std_out" );
    my @all_c = split( / /, $std_out );
    my %h;
    foreach my $val ( @all_c ) {
      $h{ $val } = 1;
    }
    return \%h;
  }
  my $xml_files = util_get_name_files_from_dir("ipsets");
  if ( defined $xml_files ) {
    return $xml_files;
  }
  return undef;
}

sub is_ipset_available {
  my $s = shift;
  my $available_ipsets = firewalld_ipsets_hash();
  if ( defined $available_ipsets && exists( $available_ipsets->{$s} ) ) {
    return $s;
  }
  get_logger->error("Ipsets $s does not exist.");
  return undef;
}

# Zones Functions
sub firewalld_zones_hash {
  my $std_out = util_firewalld_cmd( "--get-zones" );
  if ( $std_out ne "" ) {
    get_logger->info( "Zones are: $std_out" );
    my @zones = split( / /, $std_out );
    my %h;
    foreach my $val ( @zones ) {
      $h{ $val } = 1;
    }
    return \%h;
  }
  my $xml_files = util_get_name_files_from_dir("zones");
  if ( defined $xml_files ) {
    return $xml_files;
  }
  return undef;
}

sub is_zone_available {
  my $s = shift;
  my $available_zones = firewalld_zones_hash();
  if ( exists $available_zones->{ $s } ) {
    return $s;
  }
  get_logger->error( "Zone $s does not exist." );
  return undef;
}

# Helpers Functions
sub firewalld_helpers_hash {
  my $std_out = util_firewalld_cmd( "--get-helpers" );
  if ( $std_out ne "" ) {
    get_logger->info( "Helpers are: $std_out" );
    my @all_c = split( / /, $std_out );
    my %h;
    foreach my $val ( @all_c ) {
      $h{ $val } = 1;
    }
    return \%h;
  }
  my $xml_files = util_get_name_files_from_dir("helpers");
  if ( defined $xml_files ) {
    return $xml_files;
  }
  return undef;
}

sub is_helper_available {
  my $s = shift;
  my $available_helpers = firewalld_helpers_hash();
  if ( defined $available_helpers &&  exists( $available_helpers->{ $s } ) ) {
    return $s;
  }
  get_logger->error( "Helper $s does not exist." );
  return undef;
}

sub fd_fix_file_permissions {
    my ($file) = @_;
    safe_pf_run('sudo', 'chown', 'root:pf', $file);
}

sub fd_fix_dir_permissions {
    safe_pf_run('sudo', 'chmod', '02770', '/usr/local/pf/var/conf/firewalld');
    safe_pf_run('sudo', 'chown', 'root:pf', '-R', '/usr/local/pf/var/conf/firewalld');
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
