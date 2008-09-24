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
  @EXPORT = qw(service_list service_ctl read_violations_conf generate_sysctl_conf
               generate_dhcpd_reg generage_dhcpd_iso);
}

use lib qw(/usr/local/pf/lib);
use pf::config;
use pf::util;
use pf::violation qw(violation_view_open_uniq);
use pf::node qw(nodes_registered_not_violators);
use pf::trigger qw(trigger_delete_all);
use pf::class qw(class_view_all class_merge);

my %flags;
$flags{'httpd'}= "-f $install_dir/conf/httpd.conf";
$flags{'pfdetect'} = "-d -p $install_dir/var/alert &";
$flags{'pfmon'} = "-d &";
$flags{'pfdhcplistener'} = "-d &";
$flags{'pfredirect'} =  "-d &";
$flags{'pfsetvlan'} = "-d &";
$flags{'dhcpd'} = " -lf $install_dir/conf/dhcpd/dhcpd.leases -cf $install_dir/conf/dhcpd.conf ".join(" ", get_dhcp_devs());
$flags{'named'} = "-u pf -c $install_dir/conf/named.conf";
$flags{'snmptrapd'} = "-n -c /usr/local/pf/conf/snmptrapd.conf -C -Lf /usr/local/pf/logs/snmptrapd.log -p /usr/local/pf/var/snmptrapd.pid -On";
$flags{'nessusd'} = "-D";

if (isenabled($Config{'trapping'}{'detection'}) && $monitor_int) {
  $flags{'snort'} = "-u pf -c $install_dir/conf/snort.conf -i ".$monitor_int." -o -N -D -l $install_dir/var";
}

sub service_ctl {
  my ($daemon, $action, $quick) = @_;
  my $logger = Log::Log4perl::get_logger('pf::pfservices');
  my $service = $Config{'services'}{$daemon};
  my $exe = basename($service);
  $logger->info("$service $action");
  CASE: {
    $action eq "start" && do {
      return(0) if ($exe=~/dhcp/ && (! ($exe=~/pfdhcplistener/)) && $Config{'network'}{'mode'}!~/^dhcp$/);	
      return(0) if ($exe=~/snort/ && !isenabled($Config{'trapping'}{'detection'}));
      return(0) if ($exe=~/pfdhcplistener/ && !isenabled($Config{'network'}{'dhcpdetector'}));
      return(0) if ($exe=~/snmptrapd/ && !isenabled($Config{'network'}{'vlan'}));
      return(0) if ($exe=~/pfsetvlan/ && !isenabled($Config{'network'}{'vlan'}));
      if ($daemon=~/(dhcpd|named|snort|httpd|snmptrapd)/ && !$quick){
         my $confname="generate_".$daemon."_conf";
         $logger->info("Generating configuration file $confname for $exe");
         ($pf::services::{$confname} or sub { print "No such sub: $_\n" })->();
      }
      if (defined($flags{$daemon})) {
        if ($daemon ne 'pfdhcplistener') {
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

      open(STDERR,">/dev/null");
      #my @debug= system('pkill','-f',$exe);
      my @debug= system('pkill',$exe);
      my $maxWait = 10;
      my $curWait = 0;
      while (($curWait < $maxWait) && (service_ctl($exe,"status") != 0)) {
        $logger->info("Waiting for $exe to stop");
        sleep(2);
        $curWait++;
      }
      if (-e $install_dir."/var/$exe.pid") {
        unlink($install_dir."/var/$exe.pid");
      }
      last CASE;
    };
    $action eq "restart" && do {
      service_ctl("pfdetect", "stop") if ($daemon eq "snort");
      service_ctl($daemon, "stop");

      service_ctl($daemon, "start");
      service_ctl("pfdetect", "start") if ($daemon eq "snort");
      last CASE;
    };
    $action eq "status" && do {
      my $pid;
      chop($pid=`pidof -x $exe`);
      $pid=0 if (!$pid);
      return($pid);
      last CASE;
    }
  }
}

#return an array of enabled services
sub service_list {
  my @finalServiceList = ();
  my $snortflag=0;
  foreach my $service (tied(%Config)->Parameters("services")) {
    if ($service eq "snort" ) {
      $snortflag=1  if (isenabled($Config{'trapping'}{'detection'}));
    } elsif ($service eq "pfdetect") {
      push @finalServiceList, $service  if (isenabled($Config{'trapping'}{'detection'}));
    } elsif ($service eq "pfredirect") {
      push @finalServiceList, $service  if ($Config{'ports'}{'listeners'});
    } elsif ($service eq "dhcpd") {
      push @finalServiceList, $service  if ($Config{'network'}{'mode'} =~ /^dhcp$/i);
    } elsif ($service eq "named") {
      push @finalServiceList, $service  if (isenabled($Config{'network'}{'named'}));
    } elsif ($service eq "snmptrapd") {
      push @finalServiceList, $service  if (isenabled($Config{'network'}{'vlan'}));
    } elsif ($service eq "pfsetvlan") {
      push @finalServiceList, $service  if (isenabled($Config{'network'}{'vlan'}));
    } else {
      push @finalServiceList, $service;
    }
  }
  #add snort last
  push @finalServiceList, "snort"  if ($snortflag);
  return @finalServiceList;
}


sub generate_dhcpd_conf {
  my %tags;
  my $logger = Log::Log4perl::get_logger('pf::services');
  $tags{'template'}           = "$install_dir/conf/templates/dhcpd.conf";
  $tags{'domain'}             = $Config{'general'}{'domain'};
  $tags{'hostname'}           = $Config{'general'}{'hostname'};
  $tags{'dnsservers'}         = $Config{'general'}{'dnsservers'};

  parse_template(\%tags, "$install_dir/conf/templates/dhcpd.conf", "$install_dir/conf/dhcpd.conf");

  my %shared_nets;
  $logger->info("generating $install_dir/conf/dhcpd.conf");
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
  open(DHCPDCONF,">>$install_dir/conf/dhcpd.conf") || $logger->logdie("Unable to append to $install_dir/conf/dhcpd.conf: $!");
  foreach my $internal_interface (get_internal_devs_phy()) {
    my $dhcp_interface = get_internal_info($internal_interface);
    print DHCPDCONF "subnet ".$dhcp_interface->base()." netmask ".$dhcp_interface->mask()." {\n  not authoritative;\n}\n";
  }
  foreach my $shared_net (keys(%shared_nets)) {
    my $printable_shared = $shared_net;
    $printable_shared =~ s/dhcp //;
    print DHCPDCONF "shared-network $printable_shared {\n";
    foreach my $key (keys(%{$shared_nets{$shared_net}})) {
      my $tmp_obj = new Net::Netmask($key);
      print DHCPDCONF "  subnet ".$tmp_obj->base()." netmask ".$tmp_obj->mask()." {\n";

      if (defined(@{$shared_nets{$shared_net}{$key}{'registered'}})) {    
        foreach my $reg (@{$shared_nets{$shared_net}{$key}{'registered'}}) {

          my $range = normalize_dhcpd_range($Config{'scope '.$reg->tag("scope")}{'range'});
          if (!$range) {
            $logger->logdie("Invalid scope range: ".$Config{'scope '.$reg->tag("scope")}{'range'});
          }
          print DHCPDCONF "    pool {\n";
          print DHCPDCONF "      # I AM A REGISTERED SCOPE\n";
          print DHCPDCONF "      deny unknown clients;\n";
          print DHCPDCONF "      allow members of \"registered\";\n";
          print DHCPDCONF "      option routers ".$Config{'scope '.$reg->tag("scope")}{'gateway'}.";\n";

          my $lease_time;
          if (defined($Config{$shared_net}{'registered_lease'})) {
            $lease_time = $Config{$shared_net}{'registered_lease'};
          } else {
            $lease_time = 7200;
          }

          print DHCPDCONF "      max-lease-time $lease_time;\n";
          print DHCPDCONF "      default-lease-time $lease_time;\n";
          print DHCPDCONF "      range $range;\n";
          print DHCPDCONF "    }\n";
        }
      }

      if (defined(@{$shared_nets{$shared_net}{$key}{'isolation'}})) {    
        foreach my $iso (@{$shared_nets{$shared_net}{$key}{'isolation'}}) {

          my $range = normalize_dhcpd_range($Config{'scope '.$iso->tag("scope")}{'range'});
          if (!$range) {
            $logger->logdie("Invalid scope range: ".$Config{'scope '.$iso->tag("scope")}{'range'});
          }

          print DHCPDCONF "    pool {\n";
          print DHCPDCONF "      # I AM AN ISOLATION SCOPE\n";
          print DHCPDCONF "      deny unknown clients;\n";
          print DHCPDCONF "      allow members of \"isolated\";\n";
          print DHCPDCONF "      option routers ".$Config{'scope '.$iso->tag("scope")}{'gateway'}.";\n";

          my $lease_time;
          if (defined($Config{$shared_net}{'isolation_lease'})) {
            $lease_time = $Config{$shared_net}{'isolation_lease'};
          } else {
            $lease_time = 120;
          }

          print DHCPDCONF "      max-lease-time $lease_time;\n";
          print DHCPDCONF "      default-lease-time $lease_time;\n";
          print DHCPDCONF "      range $range;\n";
          print DHCPDCONF "    }\n";
        }
      }

      if (defined(@{$shared_nets{$shared_net}{$key}{'unregistered'}})) {    
        foreach my $unreg (@{$shared_nets{$shared_net}{$key}{'unregistered'}}) {

          my $range = normalize_dhcpd_range($Config{'scope '.$unreg->tag("scope")}{'range'});
          if (!$range) {
            $logger->logdie("Invalid scope range: ".$Config{'scope '.$unreg->tag("scope")}{'range'});
          }

          print DHCPDCONF "    pool {\n";
          print DHCPDCONF "      # I AM AN UNREGISTERED SCOPE\n";
          print DHCPDCONF "      allow unknown clients;\n";
          print DHCPDCONF "      option routers ".$Config{'scope '.$unreg->tag("scope")}{'gateway'}.";\n";

          my $lease_time;
          if (defined($Config{$shared_net}{'unregistered_lease'})) {
            $lease_time = $Config{$shared_net}{'unregistered_lease'};
          } else {
            $lease_time = 120;
          }

          print DHCPDCONF "      max-lease-time $lease_time;\n";
          print DHCPDCONF "      default-lease-time $lease_time;\n";
          print DHCPDCONF "      range $range;\n";
          print DHCPDCONF "    }\n";
        }
      }

      print DHCPDCONF "  }\n";
    }
    print DHCPDCONF "}\n";
  }
  print DHCPDCONF "include \"$install_dir/conf/isolated.mac\";\n";
  print DHCPDCONF "include \"$install_dir/conf/registered.mac\";\n";
  #close(DHCPDCONF);

  generate_dhcpd_iso();
  generate_dhcpd_reg();
}

#open isolated.mac file
sub generate_dhcpd_iso {
  my $logger = Log::Log4perl::get_logger('pf::services');
  open(ISOMAC, ">$install_dir/conf/isolated.mac") || $logger->logdie("Unable to open $install_dir/conf/isolated.mac : $!"); 
  my @isolated = violation_view_open_uniq();
  my @isolatednodes;
  foreach my $row (@isolated) {
      my $mac = $row->{'mac'};
      my $hostname = $mac;
      $hostname =~ s/://g;
      print ISOMAC "host $hostname { hardware ethernet $mac; } subclass \"isolated\" 01:$mac;";
  }
  #close(ISOMAC);
}


#open registered.mac file
sub generate_dhcpd_reg {
  my $logger = Log::Log4perl::get_logger('pf::services');
  if (isenabled($Config{'trapping'}{'registration'})){
	my $regmac_fh;
    open(REGMAC,">$install_dir/conf/registered.mac") || $logger->logdie("Unable to open $install_dir/conf/registered.mac : $!");  
    my @registered = nodes_registered_not_violators();
    my @registerednodes;
    foreach my $row (@registered) {
      my $mac = $row->{'mac'};
      my $hostname = $mac;
      $hostname =~ s/://g;
      print REGMAC "host $hostname { hardware ethernet $mac; } subclass \"registered\" 01:$mac;";
    }
    #close(REGMAC);
  } 
}



sub generate_named_conf {
  my $logger = Log::Log4perl::get_logger('pf::services');
  my %tags;
  $tags{'template'}   = "$install_dir/conf/templates/named.conf";
  $tags{'install_dir'} = $install_dir;
  $tags{'dnsservers'}   = $Config{'general'}{'dnsservers'};
  #convert comma separated list into semo-colon separated one
  $tags{'dnsservers'} =~ s/,/; /g;
  $logger->info("generating $install_dir/conf/named.conf");
  parse_template(\%tags, "$install_dir/conf/templates/named.conf", "$install_dir/conf/named.conf");
}

sub generate_snort_conf {
  my $logger = Log::Log4perl::get_logger('pf::services');
  my %tags;
  $tags{'template'}      = "$install_dir/conf/templates/snort.conf";
  $tags{'internal-ips'}   = join(",",get_internal_ips());
  $tags{'internal-nets'} = join(",",get_internal_nets());
  $tags{'gateways'}      = join(",", get_gateways());
  $tags{'dhcp_servers'}  = $Config{'general'}{'dhcpservers'};
  $tags{'dns_servers'}   = $Config{'general'}{'dnsservers'};
  $tags{'install_dir'}   = $install_dir;
  my %violations_conf;
  tie %violations_conf, 'Config::IniFiles', ( -file => "$install_dir/conf/violations.conf" ); 
  my @rules;
  foreach my $rule (split(/\s*,\s*/, $violations_conf{'defaults'}{'snort_rules'})){  
    #append install_dir if the path doesn't start with /
	$rule="\$RULE_PATH/$rule" if ($rule!~/^\//);
	push @rules,"include $rule";
  }
  $tags{'snort_rules'} = join("\n",@rules);
  $logger->info("generating $install_dir/conf/snort.conf");
  parse_template(\%tags, "$install_dir/conf/templates/snort.conf", "$install_dir/conf/snort.conf");
}

sub generate_sysctl_conf {
  my $logger = Log::Log4perl::get_logger('pf::services');
  my %tags;
  $tags{'template'} = "$install_dir/conf/templates/sysctl.conf";
  $logger->info("generating $install_dir/conf/sysctl.conf");
  parse_template(\%tags, "$install_dir/conf/templates/sysctl.conf", "$install_dir/conf/sysctl.conf");
}

sub generate_snmptrapd_conf {
  my $logger = Log::Log4perl::get_logger('pf::services');
  my %tags;
  my %switchConfig;
  tie %switchConfig, 'Config::IniFiles', (-file => "$install_dir/conf/switches.conf");
  my @errors = @Config::IniFiles::errors;
  if (scalar(@errors)) {
      $logger->error("Error reading config file: " . join("\n", @errors));
      return 0;
  }

  #remove trailing spaces..
  foreach my $section (tied(%switchConfig)->Sections){
      foreach my $key (keys %{$switchConfig{$section}}){
          $switchConfig{$section}{$key}=~s/\s+$//;
      }
  }

  $tags{'template'} = "$install_dir/conf/templates/snmptrapd.conf";
  $tags{'communityTrap'} = $switchConfig{'default'}{'communityTrap'};
  $logger->info("generating $install_dir/conf/snmptrapd.conf");
  parse_template(\%tags, "$install_dir/conf/templates/snmptrapd.conf", "$install_dir/conf/snmptrapd.conf");
}

sub generate_httpd_conf {
  my (%tags, $httpdconf_fh, $authconf_fh);
  my $logger = Log::Log4perl::get_logger('pf::services');
  $tags{'template'}        = "$install_dir/conf/templates/httpd.conf";
  $tags{'internal-nets'}   = join(" ",get_internal_nets());
  $tags{'routed-nets'}     = join(" ",get_routed_nets());
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

  my @authaliases; 
  foreach my $authtype (split(/\s*,\s*/, $Config{'registration'}{'auth'})){ 
        next if ($authtype eq "harvard");
	push @authaliases, "  Alias /cgi-bin/register-$authtype.cgi $install_dir/cgi-bin/register.cgi";
  }
  $tags{'auth-aliases'} = join("\n", @authaliases);

  $logger->info("generating $install_dir/conf/httpd.conf");
  parse_template(\%tags, "$install_dir/conf/templates/httpd.conf", "$install_dir/conf/httpd.conf");

  # append authentication code
  #if (isenabled($Config{'trapping'}{'registration'})) {
  #  open(HTTPDCONF, ">>$install_dir/conf/httpd.conf") || die "Unable to open $install_dir/conf/httpd.conf for append: $!\n";
  #  foreach my $authtype (split(/\s*,\s*/, $Config{'registration'}{'auth'})) {
  #    my $authconf = "$install_dir/conf/templates/${authtype}.conf";
  #    if (-e $authconf) {
  #      open(AUTHCONF, $authconf) || die "Unable to open authentication config file $authconf: $!\n";
  #      while (<AUTHCONF>) {
  #        print HTTPDCONF $_;
  #      }
  #      #close(AUTHCONF);
  #    } else {
  #      pflogger("authentication file $authconf missing!",1) if ($authtype !~ /harvard/i); 
  #    }
  #  }
  #  #close(HTTPDCONF);
  #}
}

sub read_violations_conf {
  my $logger = Log::Log4perl::get_logger('pf::services');
  my %violations_conf;
  tie %violations_conf, 'Config::IniFiles', ( -file => "/usr/local/pf/conf/violations.conf" );
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
            if (!grep(/^$type$/i, @valid_trigger_types)) {
               $logger->warn("invalid trigger'$type' found at $violation");
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
  #class_cleanup();
  # 1.6.0 will not generate snort rules
  # you must supply your own file
  #generate_snort_rules(%violations);
}

#deprecated in 1.6.0
#
sub generate_snort_rules {
  my (%violations) = @_;
  my $logger = Log::Log4perl::get_logger('pf::services');
  open(RULES, "> $install_dir/conf/snort/violation.rules");
  print RULES "# This file is auto-generated from $install_dir/conf/violations.conf - do not edit!\n";
  print RULES "pass  ip \$INTERNAL_IPS any -> any any\n";
  print RULES "pass  ip \$GATEWAYS any -> any any\n";
  foreach my $violation (sort keys %violations) {
    next if (!(defined($violations{$violation}{'snortrule'})));
    if ($violation >= 1200000 && $violation < 1200100) {
      $logger->info("violation $violation out of range, skipping");
      next;
    }
    print RULES "# " if ($violations{$violation}{'disable'} =~ /^y$/i);
    print RULES $violations{$violation}{'snortrule'}."\n";
  }
  #close(RULES);
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

1
