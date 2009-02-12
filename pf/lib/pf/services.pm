#
# Copyright 2005 David LaPorte <david@davidlaporte.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

package pf::services;

use strict;
use warnings;
use File::Basename;
use Config::IniFiles;
use Log::Log4perl;

BEGIN {
  use Exporter ();
  our (@ISA, @EXPORT);
  @ISA    = qw(Exporter);
  @EXPORT = qw(service_list service_ctl read_violations_conf
               generate_dhcpd_reg generate_dhcpd_iso);
}

use pf::config;
use pf::util;
use pf::violation qw(violation_view_open_uniq);
use pf::node qw(nodes_registered_not_violators);
use pf::trigger qw(trigger_delete_all);
use pf::class qw(class_view_all class_merge);
use pf::SwitchFactory;

my %flags;
$flags{'httpd'}= "-f $conf_dir/httpd.conf";
$flags{'pfdetect'} = "-d -p $install_dir/var/alert &";
$flags{'pfmon'} = "-d &";
$flags{'pfdhcplistener'} = "-d &";
$flags{'pfredirect'} =  "-d &";
$flags{'pfsetvlan'} = "-d &";
$flags{'dhcpd'} = " -lf $conf_dir/dhcpd/dhcpd.leases -cf $conf_dir/dhcpd.conf ".join(" ", get_dhcp_devs());
$flags{'named'} = "-u pf -c $install_dir/conf/named.conf";
$flags{'snmptrapd'} = "-n -c $conf_dir/snmptrapd.conf -C -Lf $install_dir/logs/snmptrapd.log -p $install_dir/var/snmptrapd.pid -On";

if (isenabled($Config{'trapping'}{'detection'}) && $monitor_int) {
  $flags{'snort'} = "-u pf -c $conf_dir/snort.conf -i ".$monitor_int." -o -N -D -l $install_dir/var";
}

sub service_ctl {
  my ($daemon, $action, $quick) = @_;
  my $logger = Log::Log4perl::get_logger('pf::services');
  my $service = ($Config{'services'}{$daemon} || "$install_dir/sbin/$daemon");
  my $exe = basename($service);
  $logger->info("$service $action");
  if ($exe =~ /^(named|dhcpd|pfdhcplistener|pfmon|pfdetect|pfredirect|snort|httpd|snmptrapd|pfsetvlan)$/) {
    $exe = $1;
    CASE: {
      $action eq "start" && do {
        return(0) if ($exe=~/dhcpd/ && (($Config{'network'}{'mode'}=~/^arp$/) || (($Config{'network'}{'mode'} =~ /^vlan$/i) && (! isenabled($Config{'vlan'}{'dhcpd'})))));
        return(0) if ($exe=~/snort/ && !isenabled($Config{'trapping'}{'detection'}));
        return(0) if ($exe=~/pfdhcplistener/ && !isenabled($Config{'network'}{'dhcpdetector'}));
        return(0) if ($exe=~/snmptrapd/ && !($Config{'network'}{'mode'} =~ /vlan/i));
        return(0) if ($exe=~/pfsetvlan/ && !($Config{'network'}{'mode'} =~ /vlan/i));
        return(0) if ($exe=~/named/ && !(($Config{'network'}{'mode'} =~ /vlan/i) && (isenabled($Config{'vlan'}{'named'}))));
        if ($daemon=~/(named|dhcpd|snort|httpd|snmptrapd)/ && !$quick){
           my $confname="generate_".$daemon."_conf";
           $logger->info("Generating configuration file $confname for $exe");
           ($pf::services::{$confname} or sub { print "No such sub: $_\n" })->();
        }
        if (defined($flags{$daemon})) {
          if ($daemon ne 'pfdhcplistener') {
            if (($daemon eq 'pfsetvlan') && (! switches_conf_is_valid())) {
              $logger->error("errors in switches.conf. pfsetvlan will NOT be started");
              return 0;
            }
            $logger->info("Starting $exe with '$service $flags{$daemon}'");
            return(system("$service $flags{$daemon}"));
          } else {
            if (isenabled($Config{'network'}{'dhcpdetector'})) {
              my @devices = @listen_ints;
              push @devices, @dhcplistener_ints;
              @devices=get_dhcp_devs() if ( $Config{'network'}{'mode'} =~ /^dhcp$/i );
              foreach my $dev (@devices){
                $logger->info("Starting $exe with '$service -i $dev $flags{$daemon}'");
                system("$service -i $dev $flags{$daemon}");
              }
              return 1;
            }
          }
        }
        last CASE;
      };
      $action eq "stop" && do {
        open(STDERR,'>', "/dev/null");
        #my @debug= system('pkill','-f',$exe);
        $logger->info("Stopping $exe with 'pkill $exe'");
        eval {
          `pkill $exe`;
        };
        if ($@) {
          $logger->logdie("Can't stop $exe with 'pkill $exe': $@");
          return;
        }
        #$logger->info("pkill shows " . join(@debug));
        my $maxWait = 10;
        my $curWait = 0;
        while (($curWait < $maxWait) && (service_ctl($exe,"status") != 0)) {
          $logger->info("Waiting for $exe to stop");
          sleep(2);
          $curWait++;
        }
        if (-e $install_dir."/var/$exe.pid") {
          $logger->info("Removing $install_dir/var/$exe.pid");
          unlink($install_dir."/var/$exe.pid");
        }
        last CASE;
      };
      $action eq "restart" && do {
        service_ctl("pfdetect", "stop") if ($daemon eq "snort");
        service_ctl($daemon, "stop");

        `$install_dir/bin/pfcmd service $exe start`;
        `$install_dir/bin/pfcmd service pfdetect start` if ($daemon eq "snort");
        last CASE;
      };
      $action eq "status" && do {
        my $pid;
        chop($pid=`pidof -x $exe`);
        $pid=0 if (!$pid);
        $logger->info("pidof -x $exe returned $pid");
        return($pid);
        last CASE;
      }
    }
  } else {
    $logger->logdie("unknown service $exe!");
  }
}

#return an array of enabled services
sub service_list {
  my @services = @_;
  my @finalServiceList = ();
  my $snortflag=0;
  foreach my $service (@services) {
    if ($service eq "snort" ) {
      $snortflag=1  if (isenabled($Config{'trapping'}{'detection'}));
    } elsif ($service eq "pfdetect") {
      push @finalServiceList, $service  if (isenabled($Config{'trapping'}{'detection'}));
    } elsif ($service eq "pfredirect") {
      push @finalServiceList, $service  if ($Config{'ports'}{'listeners'});
    } elsif ($service eq "dhcpd") {
      push @finalServiceList, $service  if (($Config{'network'}{'mode'} =~ /^dhcp$/i) || (($Config{'network'}{'mode'} =~ /^vlan$/i) && (isenabled($Config{'vlan'}{'dhcpd'}))));
    } elsif ($service eq "snmptrapd") {
      push @finalServiceList, $service  if ($Config{'network'}{'mode'} =~ /vlan/i);
    } elsif ($service eq "named") {
      push @finalServiceList, $service  if (($Config{'network'}{'mode'} =~ /vlan/i) && (isenabled($Config{'vlan'}{'named'})));
    } elsif ($service eq "pfsetvlan") {
      push @finalServiceList, $service  if ($Config{'network'}{'mode'} =~ /vlan/i);
    } else {
      push @finalServiceList, $service;
    }
  }
  #add snort last
  push @finalServiceList, "snort"  if ($snortflag);
  return @finalServiceList;
}

sub generate_named_conf {
  my $logger = Log::Log4perl::get_logger('pf::services');
  require Net::Netmask;
  import Net::Netmask;
  my %tags;
  $tags{'template'}   = "$conf_dir/templates/named_vlan.conf";
  $tags{'install_dir'} = $install_dir;

  $tags{'registration_clients'} = "";
  foreach my $net (get_routed_registration_nets()) {
    $tags{'registration_clients'} .= $net . "; ";
  }
  $tags{'isolation_clients'} = "";
  foreach my $net (get_routed_isolation_nets()) {
    $tags{'isolation_clients'} .= $net . "; ";
  }
  parse_template(\%tags, "$conf_dir/templates/named_vlan.conf", "$install_dir/conf/named.conf");

  my %tags_isolation;
  $tags_isolation{'template'}   = "$conf_dir/templates/named-isolation.ca";
  $tags_isolation{'hostname'} = $Config{'general'}{'hostname'};
  $tags_isolation{'incharge'} = "pf." . $Config{'general'}{'hostname'} . "." . $Config{'general'}{'domain'};
  parse_template(\%tags_isolation, "$conf_dir/templates/named-isolation.ca", "$install_dir/conf/named/named-isolation.ca");

  my %tags_registration;
  $tags_registration{'template'}   = "$conf_dir/templates/named-registration.ca";
  $tags_registration{'hostname'} = $Config{'general'}{'hostname'};
  $tags_registration{'incharge'} = "pf." . $Config{'general'}{'hostname'} . "." . $Config{'general'}{'domain'};
  parse_template(\%tags_registration, "$conf_dir/templates/named-registration.ca", "$install_dir/conf/named/named-registration.ca");
}

sub generate_dhcpd_vlan_conf {
  my $logger = Log::Log4perl::get_logger('pf::services');
  my %tags;
  $tags{'template'} = "$conf_dir/templates/dhcpd_vlan.conf";
  $tags{'networks'} = '';

  my %network_conf;
  tie %network_conf, 'Config::IniFiles', ( -file => "$conf_dir/networks.conf", -allowempty => 1);
  my @errors = @Config::IniFiles::errors;
  if (scalar(@errors)) {
    $logger->error("Error reading networks.conf: " . join("\n", @errors) . "\n")
;
    return 0;
  }
  foreach my $section (tied(%network_conf)->Sections){
    $tags{'networks'} .= <<EOT;
subnet $section netmask $network_conf{$section}{'netmask'} {
  option routers $network_conf{$section}{'gateway'};
  option subnet-mask $network_conf{$section}{'netmask'};
  option domain-name "$network_conf{$section}{'domain-name'}";
  option domain-name-servers $network_conf{$section}{'dns'};
  range $network_conf{$section}{'dhcp_start'} $network_conf{$section}{'dhcp_end'};
  default-lease-time $network_conf{$section}{'dhcp_default_lease_time'};
  max-lease-time $network_conf{$section}{'dhcp_max_lease_time'};
}

EOT
    foreach my $key (keys %{$network_conf{$section}}){
      $network_conf{$section}{$key}=~s/\s+$//;
    }
  }


  parse_template(\%tags, "$conf_dir/templates/dhcpd_vlan.conf", "$conf_dir/dhcpd.conf");
}

sub generate_dhcpd_conf {
  if ($Config{'network'}{'mode'} =~ /vlan/i) {
    generate_dhcpd_vlan_conf();
    return;
  }
  my %tags;
  my $logger = Log::Log4perl::get_logger('pf::services');
  $tags{'template'}           = "$conf_dir/templates/dhcpd.conf";
  $tags{'domain'}             = $Config{'general'}{'domain'};
  $tags{'hostname'}           = $Config{'general'}{'hostname'};
  $tags{'dnsservers'}         = $Config{'general'}{'dnsservers'};

  parse_template(\%tags, "$conf_dir/templates/dhcpd.conf", "$conf_dir/dhcpd.conf");

  my %shared_nets;
  $logger->info("generating $conf_dir/dhcpd.conf");
  foreach my $dhcp (tied(%Config)->GroupMembers("dhcp")) {
    my @registered_scopes;
    my @unregistered_scopes;
    my @isolation_scopes;

    if (defined($Config{$dhcp}{'registered_scopes'})) {
      @registered_scopes = split(/\s*,\s*/, $Config{$dhcp}{'registered_scopes'});
    }
    if (defined($Config{$dhcp}{'unregistered_scopes'})) {
      @unregistered_scopes = split(/\s+/, $Config{$dhcp}{'unregistered_scopes'});
    }
    if (defined($Config{$dhcp}{'isolation_scopes'})) {
      @isolation_scopes = split(/\s+/, $Config{$dhcp}{'isolation_scopes'});
    }

    foreach my $registered_scope (@registered_scopes) {
      my $reg_obj = new Net::Netmask($Config{'scope '.$registered_scope}{'network'});
      $reg_obj->tag("scope", $registered_scope);
      foreach my $shared_net (keys(%shared_nets)) {
        if ($shared_net ne $dhcp && defined($shared_nets{$shared_net}{$reg_obj->desc()})) {
          $logger->logdie("Network ".$reg_obj->desc()." is defined in another shared-network!\n");
        }
      }
      push(@{$shared_nets{$dhcp}{$reg_obj->desc()}{'registered'}}, $reg_obj);
    }
    foreach my $isolation_scope (@isolation_scopes) {
      my $iso_obj = new Net::Netmask($Config{'scope '.$isolation_scope}{'network'});
      $iso_obj->tag("scope", $isolation_scope);
      foreach my $shared_net (keys(%shared_nets)) {
        if ($shared_net ne $dhcp && defined($shared_nets{$shared_net}{$iso_obj->desc()})) {
          $logger->logdie("Network ".$iso_obj->desc()." is defined in another shared-network!\n");
        }
      }
      push(@{$shared_nets{$dhcp}{$iso_obj->desc()}{'isolation'}}, $iso_obj);
    }
    foreach my $unregistered_scope (@unregistered_scopes) {
      my $unreg_obj = new Net::Netmask($Config{'scope '.$unregistered_scope}{'network'});
      $unreg_obj->tag("scope", $unregistered_scope);
      foreach my $shared_net (keys(%shared_nets)) {
        if ($shared_net ne $dhcp && defined($shared_nets{$shared_net}{$unreg_obj->desc()})) {
          $logger->logdie("Network ".$unreg_obj->desc()." is defined in another shared-network!\n");
        }
      }
      push(@{$shared_nets{$dhcp}{$unreg_obj->desc()}{'unregistered'}}, $unreg_obj);
     }
  }

  #open dhcpd.conf file
  my $dhcpdconf_fh;
  open($dhcpdconf_fh,'>>', "$conf_dir/dhcpd.conf") || $logger->logdie("Unable to append to $conf_dir/dhcpd.conf: $!");
  foreach my $internal_interface (get_internal_devs_phy()) {
    my $dhcp_interface = get_internal_info($internal_interface);
    print {$dhcpdconf_fh} "subnet ".$dhcp_interface->base()." netmask ".$dhcp_interface->mask()." {\n  not authoritative;\n}\n";
  }
  foreach my $shared_net (keys(%shared_nets)) {
    my $printable_shared = $shared_net;
    $printable_shared =~ s/dhcp //;
    print {$dhcpdconf_fh} "shared-network $printable_shared {\n";
    foreach my $key (keys(%{$shared_nets{$shared_net}})) {
      my $tmp_obj = new Net::Netmask($key);
      print {$dhcpdconf_fh} "  subnet ".$tmp_obj->base()." netmask ".$tmp_obj->mask()." {\n";

      if (defined(@{$shared_nets{$shared_net}{$key}{'registered'}})) {    
        foreach my $reg (@{$shared_nets{$shared_net}{$key}{'registered'}}) {

          my $range = normalize_dhcpd_range($Config{'scope '.$reg->tag("scope")}{'range'});
          if (!$range) {
            $logger->logdie("Invalid scope range: ".$Config{'scope '.$reg->tag("scope")}{'range'});
          }
          print {$dhcpdconf_fh} "    pool {\n";
          print {$dhcpdconf_fh} "      # I AM A REGISTERED SCOPE\n";
          print {$dhcpdconf_fh} "      deny unknown clients;\n";
          print {$dhcpdconf_fh} "      allow members of \"registered\";\n";
          print {$dhcpdconf_fh} "      option routers ".$Config{'scope '.$reg->tag("scope")}{'gateway'}.";\n";

          my $lease_time;
          if (defined($Config{$shared_net}{'registered_lease'})) {
            $lease_time = $Config{$shared_net}{'registered_lease'};
          } else {
            $lease_time = 7200;
          }

          print {$dhcpdconf_fh} "      max-lease-time $lease_time;\n";
          print {$dhcpdconf_fh} "      default-lease-time $lease_time;\n";
          print {$dhcpdconf_fh} "      range $range;\n";
          print {$dhcpdconf_fh} "    }\n";
        }
      }

      if (defined(@{$shared_nets{$shared_net}{$key}{'isolation'}})) {    
        foreach my $iso (@{$shared_nets{$shared_net}{$key}{'isolation'}}) {

          my $range = normalize_dhcpd_range($Config{'scope '.$iso->tag("scope")}{'range'});
          if (!$range) {
            $logger->logdie("Invalid scope range: ".$Config{'scope '.$iso->tag("scope")}{'range'});
          }

          print {$dhcpdconf_fh} "    pool {\n";
          print {$dhcpdconf_fh} "      # I AM AN ISOLATION SCOPE\n";
          print {$dhcpdconf_fh} "      deny unknown clients;\n";
          print {$dhcpdconf_fh} "      allow members of \"isolated\";\n";
          print {$dhcpdconf_fh} "      option routers ".$Config{'scope '.$iso->tag("scope")}{'gateway'}.";\n";

          my $lease_time;
          if (defined($Config{$shared_net}{'isolation_lease'})) {
            $lease_time = $Config{$shared_net}{'isolation_lease'};
          } else {
            $lease_time = 120;
          }

          print {$dhcpdconf_fh} "      max-lease-time $lease_time;\n";
          print {$dhcpdconf_fh} "      default-lease-time $lease_time;\n";
          print {$dhcpdconf_fh} "      range $range;\n";
          print {$dhcpdconf_fh} "    }\n";
        }
      }

      if (defined(@{$shared_nets{$shared_net}{$key}{'unregistered'}})) {    
        foreach my $unreg (@{$shared_nets{$shared_net}{$key}{'unregistered'}}) {

          my $range = normalize_dhcpd_range($Config{'scope '.$unreg->tag("scope")}{'range'});
          if (!$range) {
            $logger->logdie("Invalid scope range: ".$Config{'scope '.$unreg->tag("scope")}{'range'});
          }

          print {$dhcpdconf_fh} "    pool {\n";
          print {$dhcpdconf_fh} "      # I AM AN UNREGISTERED SCOPE\n";
          print {$dhcpdconf_fh} "      allow unknown clients;\n";
          print {$dhcpdconf_fh} "      option routers ".$Config{'scope '.$unreg->tag("scope")}{'gateway'}.";\n";

          my $lease_time;
          if (defined($Config{$shared_net}{'unregistered_lease'})) {
            $lease_time = $Config{$shared_net}{'unregistered_lease'};
          } else {
            $lease_time = 120;
          }

          print {$dhcpdconf_fh} "      max-lease-time $lease_time;\n";
          print {$dhcpdconf_fh} "      default-lease-time $lease_time;\n";
          print {$dhcpdconf_fh} "      range $range;\n";
          print {$dhcpdconf_fh} "    }\n";
        }
      }

      print {$dhcpdconf_fh} "  }\n";
    }
    print {$dhcpdconf_fh} "}\n";
  }
  print {$dhcpdconf_fh} "include \"$conf_dir/isolated.mac\";\n";
  print {$dhcpdconf_fh} "include \"$conf_dir/registered.mac\";\n";
  #close(DHCPDCONF);

  generate_dhcpd_iso();
  generate_dhcpd_reg();
}

#open isolated.mac file
sub generate_dhcpd_iso {
  my $logger = Log::Log4perl::get_logger('pf::services');
  my $isomac_fh;
  open($isomac_fh, '>', "$conf_dir/isolated.mac") || $logger->logdie("Unable to open $conf_dir/isolated.mac : $!"); 
  my @isolated = violation_view_open_uniq();
  my @isolatednodes;
  foreach my $row (@isolated) {
      my $mac = $row->{'mac'};
      my $hostname = $mac;
      $hostname =~ s/://g;
      print {$isomac_fh} "host $hostname { hardware ethernet $mac; } subclass \"isolated\" 01:$mac;";
  }
  #close(ISOMAC);
}


#open registered.mac file
sub generate_dhcpd_reg {
  my $logger = Log::Log4perl::get_logger('pf::services');
  if (isenabled($Config{'trapping'}{'registration'})){
    my $regmac_fh;
    open($regmac_fh, '>', "$conf_dir/registered.mac") || $logger->logdie("Unable to open $conf_dir/registered.mac : $!");  
    my @registered = nodes_registered_not_violators();
    my @registerednodes;
    foreach my $row (@registered) {
      my $mac = $row->{'mac'};
      my $hostname = $mac;
      $hostname =~ s/://g;
      print {$regmac_fh} "host $hostname { hardware ethernet $mac; } subclass \"registered\" 01:$mac;";
    }
    #close(REGMAC);
  } 
}



sub generate_snort_conf {
  my $logger = Log::Log4perl::get_logger('pf::services');
  my %tags;
  $tags{'template'}      = "$conf_dir/templates/snort.conf";
  $tags{'internal-ips'}   = join(",",get_internal_ips());
  $tags{'internal-nets'} = join(",",get_internal_nets());
  $tags{'gateways'}      = join(",", get_gateways());
  $tags{'dhcp_servers'}  = $Config{'general'}{'dhcpservers'};
  $tags{'dns_servers'}   = $Config{'general'}{'dnsservers'};
  $tags{'install_dir'}   = $install_dir;
  my %violations_conf;
  tie %violations_conf, 'Config::IniFiles', ( -file => "$conf_dir/violations.conf" ); 
  my @rules;
  foreach my $rule (split(/\s*,\s*/, $violations_conf{'defaults'}{'snort_rules'})){  
    #append install_dir if the path doesn't start with /
	$rule="\$RULE_PATH/$rule" if ($rule!~/^\//);
	push @rules,"include $rule";
  }
  $tags{'snort_rules'} = join("\n",@rules);
  $logger->info("generating $conf_dir/snort.conf");
  parse_template(\%tags, "$conf_dir/templates/snort.conf", "$conf_dir/snort.conf");
}

sub generate_snmptrapd_conf {
  my $logger = Log::Log4perl::get_logger('pf::services');
  my %tags;
  $tags{'authLines'} = '';
  $tags{'userLines'} = '';
  my %SNMPv3Users;
  my %SNMPCommunities;
  my $switchFactory = new pf::SwitchFactory(-configFile => "$conf_dir/switches.conf");
  my %switchConfig = %{$switchFactory->{_config}};
  foreach my $key (sort keys %switchConfig) {
    if ($key ne 'default') {
      my $switch = $switchFactory->instantiate($key);
      if ($switch->{_SNMPVersionTrap} eq '3') {
        $SNMPv3Users{$switch->{_SNMPUserNameTrap}} = '-e ' . $switch->{_SNMPEngineID} . ' ' . $switch->{_SNMPAuthProtocolTrap} . ' ' . $switch->{_SNMPAuthPasswordTrap} . ' ' . $switch->{_SNMPPrivProtocolTrap} . ' ' . $switch->{_SNMPPrivPasswordTrap};
      } else {
        $SNMPCommunities{$switch->{_SNMPCommunityTrap}} = 1;
      }
    }
  }
  foreach my $userName (sort keys %SNMPv3Users) {
    $tags{'userLines'} .= "createUser $userName " . $SNMPv3Users{$userName} . "\n";
    $tags{'authLines'} .= "authUser log $userName priv\n";
  }
  foreach my $community (sort keys %SNMPCommunities) {
    $tags{'authLines'} .= "authCommunity log $community\n";
  }
  $tags{'template'} = "$conf_dir/templates/snmptrapd.conf";
  $logger->info("generating $conf_dir/snmptrapd.conf");
  parse_template(\%tags, "$conf_dir/templates/snmptrapd.conf", "$conf_dir/snmptrapd.conf");
}

sub generate_httpd_conf {
  my (%tags, $httpdconf_fh, $authconf_fh);
  my $logger = Log::Log4perl::get_logger('pf::services');
  $tags{'template'}        = "$conf_dir/templates/httpd.conf";
  $tags{'internal-nets'}   = join(" ",get_internal_nets());
  $tags{'routed-nets'}     = join(" ",get_routed_isolation_nets()) . " " . join(" ", get_routed_registration_nets());
  $tags{'hostname'}        = $Config{'general'}{'hostname'};
  $tags{'domain'}          = $Config{'general'}{'domain'};
  $tags{'admin_port'}      = $Config{'ports'}{'admin'};
  $tags{'install_dir'}     = $install_dir;

  my @proxies;
  my %proxy_configs = %{$Config{'proxies'}};
  foreach my $proxy (keys %proxy_configs) {
    if ($proxy =~ /^\//) {
      if ($proxy !~ /^\/(content|admin|redirect|cgi-bin)/) {
        push @proxies, "ProxyPassReverse $proxy $proxy_configs{$proxy}";
        push @proxies, "ProxyPass $proxy $proxy_configs{$proxy}";
        $logger->warn("proxy $proxy is not relative - add path to apache rewrite exclude list!");
      } else {
        $logger->warn("proxy $proxy conflicts with PF paths!");
        next;
      }
    } else {
      push @proxies, "ProxyPassReverse /proxies/".$proxy." ".$proxy_configs{$proxy};
      push @proxies, "ProxyPass /proxies/".$proxy." ".$proxy_configs{$proxy};
    }
  }
  $tags{'proxies'} = join("\n", @proxies);

  my @contentproxies;
  if ($Config{'trapping'}{'passthrough'} eq "proxy") {
    my @proxies = class_view_all();
    foreach my $row (@proxies) {
      my $url = $row->{'url'};
      my $vid = $row->{'vid'};
      next  if ((! defined($url)) || ($url =~ /^\//));
      if ($url !~ /^(http|https):\/\//) {
        $logger->warn("vid ".$vid.": unrecognized content URL: ".$url);
        next;
      }
      if ($url =~ /^((http|https):\/\/.+)\/$/) {
        push @contentproxies, "ProxyPass		/content/$vid/ $url";
        push @contentproxies, "ProxyPassReverse	/content/$vid/ $url";
        push @contentproxies, "ProxyHTMLURLMap		$1 /content/$vid";
      } else {
        $url =~ /^((http|https):\/\/.+)\//;
        push @contentproxies, "ProxyPass		/content/$vid/ $1/";
        push @contentproxies, "ProxyPassReverse	/content/$vid/ $1/";
        push @contentproxies, "ProxyHTMLURLMap		$url /content/$vid";
      }
      push @contentproxies, "ProxyPass		/content/$vid $url";
      push @contentproxies, "<Location /content/$vid>";
      push @contentproxies, "  SetOutputFilter	proxy-html";
      push @contentproxies, "  ProxyHTMLDoctype	HTML";
      push @contentproxies, "  ProxyHTMLURLMap	/ /content/$vid/";
      push @contentproxies, "  ProxyHTMLURLMap	/content/$vid /content/$vid";
      push @contentproxies, "  RequestHeader	unset	Accept-Encoding";
      push @contentproxies, "</Location>";
    }
  }
  $tags{'content-proxies'} = join("\n", @contentproxies);

  $logger->info("generating $conf_dir/httpd.conf");
  parse_template(\%tags, "$conf_dir/templates/httpd.conf", "$conf_dir/httpd.conf");

}

sub switches_conf_is_valid {
  my $logger = Log::Log4perl::get_logger('pf::services');
  my %switches_conf;
  tie %switches_conf, 'Config::IniFiles', ( -file => "$conf_dir/switches.conf" );
  my @errors = @Config::IniFiles::errors;
  if (scalar(@errors)) {
    $logger->error("Error reading switches.conf: " . join("\n", @errors) . "\n");
    return 0;
  }
  foreach my $section (tied(%switches_conf)->Sections){
    foreach my $key (keys %{$switches_conf{$section}}){
      $switches_conf{$section}{$key}=~s/\s+$//;
    }
  }
  foreach my $section (keys %switches_conf) {
    if ($section ne 'default') {
      # check type
      my $type = "pf::SNMP::" . ($switches_conf{$section}{'type'} || $switches_conf{'default'}{'type'});
      eval "require $type;";
      if ($@) {
        $logger->error("Unknown switch type: $type for switch $section: $@");
        return 0;
      }
      # check IP
      if ($section ne $switches_conf{$section}{'ip'}) {
        $logger->error("switch IP and switch section do not match for $section!");
        return 0;
      }
      if (! valid_ip($switches_conf{$section}{'ip'})) {
        $logger->error("switch IP is invalid for $section");
        return 0;
      }
      # check SNMP version
      my $SNMPVersion = ($switches_conf{$section}{'SNMPVersion'} || $switches_conf{$section}{'version'} || $switches_conf{'default'}{'SNMPVersion'} || $switches_conf{'default'}{'version'});
      if (! ($SNMPVersion =~ /^1|2c|3$/)) {
        $logger->error("switch SNMP version is invalid for $section");
        return 0;
      }
      my $SNMPVersionTrap = ($switches_conf{$section}{'SNMPVersionTrap'} || $switches_conf{'default'}{'SNMPVersionTrap'});
      if (! ($SNMPVersionTrap =~ /^1|2c|3$/)) {
        $logger->error("switch SNMP trap version is invalid for $section");
        return 0;
      }
      # check uplink
      my $uplink = $switches_conf{$section}{'uplink'} || $switches_conf{'default'}{'uplink'};
      if ((! defined($uplink)) || (($uplink ne 'dynamic') && (! ($uplink =~ /(\d+,)*\d+/)))) {
        $logger->error("switch uplink (" . (defined($uplink) ? $uplink : 'undefined') . ") is invalid for $section");
        return 0;
      }
      # check mode
      my @valid_switch_modes = ('testing', 'ignore', 'production', 'registration', 'discovery');
      my $mode = $switches_conf{$section}{'mode'} || $switches_conf{'default'}{'mode'};
      if (! grep({ lc($_) eq lc($mode) } @valid_switch_modes)) {
        $logger->error("switch mode ($mode) is invalid for $section");
        return 0;
      }
    }
  }
  return 1;
}

sub read_violations_conf {
  my $logger = Log::Log4perl::get_logger('pf::services');
  my %violations_conf;
  tie %violations_conf, 'Config::IniFiles', ( -file => "$conf_dir/violations.conf" );
  my %violations = class_set_defaults(%violations_conf);
  
  #clear all triggers at startup
  trigger_delete_all();  
  foreach my $violation (keys %violations) {
    # parse triggers if they exist
    my @triggers;
    if (defined $violations{$violation}{'trigger'}){
        foreach my $trigger (split(/\s*,\s*/,$violations{$violation}{'trigger'})){
            my ($type,$tid)=split(/::/,$trigger);
            $type=lc($type);
            if (!grep({ lc($_) eq lc($type) } @valid_trigger_types)) {
               $logger->warn("invalid trigger '$type' found at $violation");
               next;
            } 
            if ($tid=~/(\d+)-(\d+)/){
              push @triggers,[$1,$2,$type];
            }else{
              push @triggers,[$tid,$tid,$type];
            }
        }
     }
     #print Dumper(@triggers);
     class_merge($violation,$violations{$violation}{'desc'},$violations{$violation}{'auto_enable'},
                $violations{$violation}{'max_enable'},$violations{$violation}{'grace'},$violations{$violation}{'priority'},
                $violations{$violation}{'url'},$violations{$violation}{'max_enable_url'},$violations{$violation}{'redirect_url'},
                $violations{$violation}{'button_text'},$violations{$violation}{'disable'},$violations{$violation}{'actions'},
                \@triggers); 
  }
}

sub class_set_defaults {
  my %violations_conf = @_;
  my %violations = %violations_conf;

  foreach my $violation (keys %violations_conf) {
    foreach my $default (keys %{$violations_conf{'defaults'}}) {
      if (!defined($violations{$violation}{$default})) {
        $violations{$violation}{$default} = $violations{'defaults'}{$default};
      }
    }
  }
  delete($violations{'defaults'});
  return(%violations);
}

sub normalize_dhcpd_range {
  my ($range) = @_;
  if ($range =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s*-\s*(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/) {
    $range =~ s/\s*\-\s*/ /;
    return($range);
  } elsif ($range =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3})\.(\d{1,3})\s*-\s*(\d{1,3})$/) {
    my $net    = $1;
    my $start  = $2;      
    my $end    = $3;
    return("$net.$start $net.$end");
  } elsif ($range =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/) {
    return("$range $range");
  } else {
    return;
  }   
}

1;
