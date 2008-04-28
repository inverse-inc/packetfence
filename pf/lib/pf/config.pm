#
# $Id: config.pm,v 1.5 2005/11/30 21:41:09 kevmcs Exp $
#
# Copyright 2005 David LaPorte <david@davidlaporte.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

package pf::config;

use strict;
use warnings;
use Config::IniFiles;
use Net::Netmask;
use Date::Parse;

our ($install_dir, %Default_Config, %Config, $verbosity, $facility, $priority, @listen_ints, @internal_nets, @routed_nets,
     $blackholemac, @managed_nets, @external_nets, @dhcplistener_ints, $isolation_int, $registration_int, $monitor_int, $unreg_mark, $reg_mark, $black_mark, $portscan_sid, 
     $default_config_file, $config_file, $dhcp_fingerprints_file, $default_pid, $fqdn, $oui_url, $dhcp_fingerprints_url,
     $oui_file, @valid_trigger_types, $thread);

BEGIN {
  use Exporter ();
  our (@ISA, @EXPORT);
  @ISA    = qw(Exporter);
  @EXPORT = qw($install_dir %Default_Config %Config $verbosity $facility $priority @listen_ints @internal_nets @routed_nets
               $blackholemac @managed_nets @external_nets @dhcplistener_ints $isolation_int $registration_int $monitor_int $unreg_mark $reg_mark $black_mark $portscan_sid
               $default_config_file $config_file $dhcp_fingerprints_file $default_pid $fqdn $oui_url $dhcp_fingerprints_url
               $oui_file @valid_trigger_types $thread)
}

# these files contain the node and person lookup functions
# they can be customized to your environment
#push @INC, "/usr/local/pf/bin";
#require "lookup_node.pl";
#require "lookup_person.pl";

$thread=0;

$install_dir = "/usr/local/pf";
$config_file = $install_dir."/conf/pf.conf";
$default_config_file = $install_dir."/conf/pf.conf.defaults";
$dhcp_fingerprints_file = $install_dir."/conf/dhcp_fingerprints.conf";
$oui_file = $install_dir."/conf/oui.txt";

$oui_url = 'http://standards.ieee.org/regauth/oui/oui.txt';
$dhcp_fingerprints_url = 'http://www.packetfence.org/dhcp_fingerprints.conf';

@valid_trigger_types = ("scan","detect","internal","os");

$portscan_sid = 1200003;
$default_pid = 1;

# to shut up strict warnings
$ENV{PATH} = '/sbin:/bin:/usr/bin:/usr/sbin';

# Ip mash marks
$unreg_mark = "0";
$reg_mark   = "1";
$black_mark = "2";

# this is broken NIC on Dave's desk - it better be unique!
$blackholemac = "00:60:8c:83:d7:34";

# read & load in configuration file
if (-e $default_config_file){
  tie %Config, 'Config::IniFiles', ( -file => $config_file, -import => Config::IniFiles->new( -file => $default_config_file ) );
} else {
  tie %Config, 'Config::IniFiles', ( -file => $config_file);
}
my @errors = @Config::IniFiles::errors;
if (scalar(@errors)) {
 die join("\n",@errors)."\n";
}

#remove trailing spaces..
foreach my $section (tied(%Config)->Sections){
  foreach my $key (keys %{$Config{$section}}){
    $Config{$section}{$key}=~s/\s+$//;
  }
} 

#normalize time
#tie %documentation, 'Config::IniFiles', ( -file => $install_dir."/conf/documentation.conf" );
#foreach my $section (sort tied(%documentation)->Sections) {
#   my($group,$item) = split(/\./, $section);
#   my $type = $documentation{$section}{'type'};
#   $Config{$group}{$item}=normalize_time($Config{$group}{$item}) if ($type eq "time");
#}

#normalize time
foreach my $val ("expire.iplog","expire.locationlog","expire.node","arp.interval","arp.gw_timeout","arp.timeout","arp.dhcp_timeout","arp.heartbeat",
                 "trapping.redirtimer","registration.skip_window","registration.skip_reminder","registration.expire_window",
                 "registration.expire_session"){
  my($group,$item) = split(/\./, $val);
  $Config{$group}{$item} = normalize_time($Config{$group}{$item});
}
foreach my $val ("registration.skip_deadline","registration.expire_deadline") {
  my($group,$item) = split(/\./, $val);
  $Config{$group}{$item} = str2time($Config{$group}{$item});
}

$verbosity = $Config{'logging'}{'verbosity'};
$facility  = $Config{'logging'}{'facility'};
$priority  = $Config{'logging'}{'priority'};

$fqdn = $Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'};

foreach my $routedSubnet (tied(%Config)->GroupMembers("routedsubnet")) {
  my $routed_obj;

  my $mask    = $Config{$routedSubnet}{'mask'};
  my $gateway = $Config{$routedSubnet}{'gateway'};
  my $type    = $Config{$routedSubnet}{'type'};
  my $network = $Config{$routedSubnet}{'network'};

  if (defined($network) && defined($mask)) {
    $routed_obj = new Net::Netmask($network, $mask);
    $routed_obj->tag("gw", $gateway);
  }
  push @routed_nets, $routed_obj;
}

foreach my $interface (tied(%Config)->GroupMembers("interface")) {
  my $int_obj;
  my $int = $interface;
  $int =~ s/interface //;

  my $ip      = $Config{$interface}{'ip'};
  my $mask    = $Config{$interface}{'mask'};
  my $gateway = $Config{$interface}{'gateway'};
  my $type    = $Config{$interface}{'type'};

  if (defined($ip) && defined($mask)) {
    $ip=~s/ //g; $mask=~s/ //g;
    $int_obj = new Net::Netmask($ip, $mask);
    $int_obj->tag("gw", $gateway);
    $int_obj->tag("ip", $ip);
    $int_obj->tag("int", $int);
  }
  foreach my $type (split(/\s*,\s*/, $type)) {
    if ($type eq "internal") {
      push @internal_nets, $int_obj;
      push @listen_ints, $int if ($int !~ /:\d+$/);
    } elsif ($type eq "managed") {
      push @managed_nets, $int_obj;
    } elsif ($type eq "external") {
      push @external_nets, $int_obj;
    } elsif ($type eq "monitor") {
      $monitor_int = $int;
    } elsif ($type eq "isolation") {
      $isolation_int = $int;
    } elsif ($type eq "registration") {
      $registration_int = $int;
    } elsif ($type eq "dhcplistener") {
      push @dhcplistener_ints, $int;
    }
  }
}

@listen_ints = split(/\s*,\s*/,$Config{'arp'}{'listendevice'}) if (defined $Config{'arp'}{'listendevice'});

sub normalize_time {
  my ($date) = @_;
  if ($date =~ /^\d+$/) {
    return($date);
  } else {
    my ($num, $modifier) = $date =~ /^(\d+)([smhdwy])$/i;
    $modifier = lc ($modifier);
    if ($modifier eq "s") {
      return($num);
    } elsif ($modifier eq "m") {
      return($num * 60);
    } elsif ($modifier eq "h") {
      return($num * 3600);
    } elsif ($modifier eq "d") {
      return($num * 86400);
    } elsif ($modifier eq "w") {
      return($num * 604800);
    } elsif ($modifier eq "y") {
      return($num * 31449600);
    } else {
      return(0);
    }
  }
}

1
