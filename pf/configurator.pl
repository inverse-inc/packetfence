#!/usr/bin/perl -w
#
# Copyright 2005 Dave Laporte <dave@laportestyle.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#


use strict;
use warnings;

use Config::IniFiles;
use Cwd;
use Net::Netmask;

die("Please install to /usr/local/pf and run this script again!\n") if (cwd() ne "/usr/local/pf");

# check if user is root
die("you must be root!\n") if ($< != 0);

my (%default_cfg,%cfg,%doc,%violation,$upgrade,$template);

tie %default_cfg, 'Config::IniFiles', ( -file => "/usr/local/pf/conf/pf.conf.defaults" ) or die "Invalid template: $!\n";
tie %doc, 'Config::IniFiles', ( -file => "/usr/local/pf/conf/documentation.conf" ) or die "Invalid docs: $!\n";
tie %violation, 'Config::IniFiles', ( -file => "/usr/local/pf/conf/violations.conf" ) or die "Invalid violations: $!\n";

# upgrade
print "Checking existing configuration...\n";
if (-e "/usr/local/pf/conf/pf.conf") {
  $upgrade=1;
  print "Existing configuration found, upgrading\n";
  tie %cfg, 'Config::IniFiles', ( -file => "/usr/local/pf/conf/pf.conf" ) or die "Unable to open existing configuration: $!";
  if (defined $cfg{'registration'}{'authentication'}){
    $cfg{'registration'}{'auth'}=$cfg{'registration'}{'authentication'};
	delete $cfg{'registration'}{'authentication'}; 
  }
  #config_upgrade();
  write_changes() if (questioner("Would you like to modify the existing configuration","n",("y","n")));

}else{
  tie %default_cfg, 'Config::IniFiles', ( -file => "/usr/local/pf/conf/pf.conf.defaults" ) or die "Unable to open default configuration file: $!\n";;
  print "No existing configuration found\n";
  tie %cfg, 'Config::IniFiles', ( -import => tied(%default_cfg) );
  tied(%cfg)->SetFileName("/usr/local/pf/conf/pf.conf");
}

# template configuration or custom?
if (questioner("Would you like to use a template configuration or custom","t",("t","c"))){
  my $type= questioner("Which template would you like:
                        1) Test mode
                        2) Registration
                        3) Detection
                        4) Registration & Detection
                        5) Registration, Detection & Scanning
                        6) Session-based Authentication
                        7) Registration, Detection and VLAN isolation
             Answer: [1|2|3|4|5|6|7]: ","",("1","2","3","4","5","6","7"));
  load_template($type);
  print "Loading Template: Warning PacketFence is going LIVE - WEAPONS HOT \n" if ($type ne 1);
  if ($type ne 1 && $type ne 2){
   print "Enabling host trapping!  Please make sure to review conf/violations.conf and disable any violations that don't fit your environment\n";
   $violation{defaults}{actions}="trap,email,log";
   tied(%violation)->WriteConfig("/usr/local/pf/conf/violations.conf") || die "Unable to commit settings: $!\n";
  }
  $template=1;
}

configuration();
write_changes();

if(questioner("Do you want me to update the DHCP fingerprints to the latest available version ?","y",("y", "n"))) {
  `/usr/local/pf/bin/pfcmd update fingerprints`;
}



# write and exit   
sub write_changes {
  my $port=$default_cfg{'ports'}{'admin'};
  $port=$cfg{'ports'}{'admin'} if (defined $cfg{'ports'}{'admin'});
  print "Please review conf/pf.conf to correct any errors or change pathing to daemons\n";
  print "After starting PF, use bin/pfcmd or the web interface (https://$cfg{'general'}{'hostname'}.$cfg{'general'}{'domain'}:$port) to administer the system\n";
  foreach my $section (tied(%cfg)->Sections) {
      next if (!exists($default_cfg{$section}));
      foreach my $key (keys(%{$cfg{$section}})) {
          next if (!exists($default_cfg{$section}{$key}));
          if ($cfg{$section}{$key}=~/$default_cfg{$section}{$key}/i){
            delete $cfg{$section}{$key};
			tied(%cfg)->DeleteParameterComment($section,$key);
          }
      }
   }
  foreach my $section (tied(%cfg)->Sections) {
    delete $cfg{$section} if (scalar(keys(%{$cfg{$section}}))==0);
  }
  # IP Bug fix
  foreach my $net (get_networkinfo()) {
    my $int = $net->{device};
    if (defined $cfg{"interface $int"}){
      my $ip = $net->{ip};
      $cfg{"interface $int"}{'ip'} = $ip;
    }
  }

  print "Committing settings...\n";
  tied(%cfg)->WriteConfig("/usr/local/pf/conf/pf.conf") || die "Unable to commit settings: $!\n";
  foreach my $path (keys(%{$cfg{services}})) {
        print "Note: Service $path does not exist\n" if (!-e $cfg{services}{$path});
  }
  print "Enjoy!\n";
  exit;
} 

sub load_template {
  $_ = shift @_;
  my %template_cfg;
  my $template_filename="/usr/local/pf/conf/templates/configurator/";
  SWITCH: {
    /1/ && do {
      $template_filename.="testmode.conf";
      last; };
    /2/ && do {
      $template_filename.="registration.conf";
      last; };
    /3/ && do {
      $template_filename.="detection.conf";
      last; };
    /4/ && do {
      $template_filename.="reg-detect.conf";
      last; };
    /5/ && do {
      $template_filename.="reg-detect-scan.conf";
      last; };
    /6/ && do {
      $template_filename.="sessionauth.conf";
      last; };
    /7/ && do {
      $template_filename.="reg-detect-vlan.conf";
      last; };
  }
  die "template $template_filename not found" if (!-e $template_filename);
  tie %template_cfg, 'Config::IniFiles', ( -file => $template_filename );
  
  foreach my $section (tied(%template_cfg)->Sections) {
      $cfg{$section} = {} if (!exists($cfg{$section}));
      foreach my $key (keys(%{$template_cfg{$section}})) {
          print "  Setting option $key to template value $template_cfg{$section}{$key} \n";
          $cfg{$section}{$key} = $template_cfg{$section}{$key};
      }
   }
}


sub config_upgrade {
    my $issues;
    #foreach my $section (tied(%default_cfg)->Sections) {
    #  $cfg{$section} = {} if (!exists($cfg{$section}));
    #  foreach my $key (keys(%{$default_cfg{$section}})) {
    #    if (!exists($cfg{$section}{$key}) && $section !~ /^(passthroughs|proxies|harvard|vlan\-int\d+)$/) {
    #      print "  Adding new option $section.$key to existing configuration\n";
    #      $cfg{$section}{$key} = $default_cfg{$section}{$key};
    #      $issues++;
    #    }
    #  }
    #}
    foreach my $section (tied(%cfg)->Sections) {
      print "  Section $section is now obsolete (you may want to delete it)\n" if (!exists($default_cfg{$section}) && $section !~ /^(passthroughs|proxies|harvard|interface)/);
      foreach my $key (keys(%{$cfg{$section}})) {
        if (!exists($default_cfg{$section}{$key})) {
          if ($section !~ /^(passthroughs|proxies|harvard|interface)/) {
            print "  Option $section.$key is now obsolete (you may want to delete it)\n";
            $issues++;
          }
        }
      }
    }
    print "  Looks good!\n" if (!$issues);
}

sub gatherer {
  my($query, $param, @choices) = @_;
  my $choices;
  my $response;
  my $default;
  $choices = join("|", @choices) if (@choices);
  my($section, $element) = split(/\./, $param);
  do {
    $default = $cfg{$section}{$element} if (defined($section) && defined($element));
    $default = '<NONE>' if (!$default);
    do {
      if (@choices < 1) {
        print "$query (default: $default [?]): ";
      } else {
        print "$query (default: $default) [$choices|?]: ";
      }
      $response = <STDIN>;
      chop $response;
      if ($response =~ /^\?$/){
	if (defined $doc{$param}){	
          print "Detail: @{$doc{$param}{description}}\n";
        }else{
          print "Sorry no further details, take a guess\n";
        }
      }
      $response = $default if (!$response);
    } while (@choices && ($response && !grep(/^$response$/, @choices)) || $response =~/^\?$/);
  } while (!confirm($response));
  $response = "" if ($response eq "<NONE>");
  if (defined($section) && defined($element)) {
    $cfg{$section} = {} if (!exists($cfg{$section}));
    $cfg{$section}{$element} = $response;
  }
  return($response);
}

sub confirm {
  my ($response) = @_;
  my $confirm;
  do {
    print "$response - ok? [y|n] ";
    $confirm = <STDIN>;
  } while ($confirm !~ /^(y|n)$/i);
  if ($confirm =~ /^y$/i) {
    return 1;
  } else {
    return 0;
  }
}

sub questioner {
  my ($query, $response, @choices) = @_;
  my $answer;
  my $choices = join("|", @choices);
  do {
    if (@choices) {
      print "$query [$choices] ";
    } else {
      print "$query: ";
    }
    $answer = <STDIN>;
    $answer =~ s/\s+//g;
  } while ($answer !~ /^($choices)$/i);
  return $answer if (!$response);
  if ($response =~ /^$answer$/i) {
    return 1;
  } else {
    return 0;
  }
}

sub configuration {
  my ($mode);
  print "\n** NOTE: The configuration can be a bit tedious.  If you get bored, you can always just edit /usr/local/pf/conf/pf.conf directly ** \n\n";
  config_general() if (!$upgrade);

  if (!$template){
    gatherer("Enable DHCP detector?","network.dhcpdetector",("enabled","disabled"));
    gatherer("Mode (passive|inline)","network.mode",("passive","inline"));
  }
  config_network($cfg{network}{mode});

  # ARP  
  if (!$template){
    print "\nARP CONFIGURATION\n";
    gatherer("What interface should I listen for ARPs on?","arp.listendevice");
  }

  # TRAPPING
  print "\nTRAPPING CONFIGURATION\n";
  gatherer("What range of addresses should be considered trappable (eg. 10.1.1.10-100,10.1.2.0/24)?","trapping.range") if (!$template);
 
  # REGISTRATION
  if (!$template){
    my $registration = gatherer("Do you wish to force registration of systems?","trapping.registration",("enabled","disabled"));
    config_registration() if ($registration =~ /^enabled$/i);
  }

  # DETECTION
  my $detection = gatherer("Do you wish to enable worm detection?","trapping.detection",("enabled","disabled")) if (!$template);
  if ($cfg{'trapping'}{'detection'} =~ /^enabled$/) {
    $cfg{'tmp'}{'monitor'} = "eth1";
    my $int = gatherer("What is my monitor interface?","tmp.monitor",get_interfaces());
    delete($cfg{'tmp'});

    if (defined $cfg{"interface $int"}{"type"}) {
      $cfg{"interface $int"}{"type"} .= ",monitor";
    } else {
      $cfg{"interface $int"}{"type"} ="monitor";
    }
	# debugging issues
	$cfg{"interface $int"}{"ip"} = $cfg{"interface $int"}{"ip"};
  }

  # ALERT 
  print "\nALERTING CONFIGURATION\n";
  gatherer("Where would you like notifications of traps, rogue DHCP servers, and other sundry goods sent?","alerting.emailaddr");
  gatherer("What should I use as my SMTP relay server?","alerting.smtpserver");

  if (!$template){
    print "\nPORTS CONFIGURATION\n";
    gatherer("Traffic on which ports should be allowed from all systems?","ports.allowed");
    gatherer("What ports should be open externally on this system?","ports.open");
    gatherer("What captive listeners should I enable in addition HTTP?","ports.listeners");
    gatherer("Traffic on which ports should be redirected and terminated locally?","ports.redirect");
    gatherer("What port should the administrative GUI run on?","ports.admin");
  }
 
  if (!$upgrade){ 
    print "\nDATABASE CONFIGURATION\n";
    gatherer("Where is my database server?","database.host");
    gatherer("What port is is listening on?","database.port");
    gatherer("What database should I use?","database.db");
    gatherer("What account should I use?","database.user");
    gatherer("What password should I use?","database.pass");
  }
}

sub config_general {
  # GENERAL
  print "GENERAL CONFIGURATION\n";
  $cfg{general}{hostname}=`cat /proc/sys/kernel/hostname`;
  chop($cfg{general}{hostname});
  $cfg{general}{domain}=`cat /proc/sys/kernel/domainname`;
  chop($cfg{general}{domain});
  $cfg{general}{domain} = '<NONE>' if ($cfg{general}{domain} eq '(none)');
  $cfg{general}{dnsservers}="";
  for (`cat /etc/resolv.conf`){
    $cfg{general}{dnsservers}.="$1," if (/nameserver (\S+)/);
  }
  chop($cfg{general}{dnsservers});
  gatherer("Domain","general.domain");
  gatherer("Hostname","general.hostname");
  gatherer("DNS Servers (comma delimited)","general.dnsservers");
  gatherer("DHCP Servers (comma delimited)","general.dhcpservers"); 
}


sub config_network {
  my ($mode) = @_;
  my (@trapping_range, $int, $ip, $mask, $tmp_net);
  # load the defaults
  foreach my $net (get_networkinfo()) {
    $int = $net->{device};
    $ip = $net->{ip};
    $mask = $net->{mask};
    $cfg{"interface $int"}{'ip'} = $ip;
    $cfg{"interface $int"}{'mask'} = $mask;
    $cfg{"interface $int"}{'type'} = "internal";
    $tmp_net = new Net::Netmask($ip, $mask);   
    push @trapping_range, $tmp_net->desc;
    $cfg{"interface $int"}{"gateway"} = $tmp_net->nth(1);
  }
  $cfg{"trapping"}{"range"} = join(",", @trapping_range);

  if ($mode =~ /inline/){
    $int = gatherer("What is my internal interface (facing the clients)?", "");
    gatherer("What is its IP address?","interface $int.ip");
    gatherer("What is its mask?","interface $int.mask");
    $cfg{"interface $int"}{"type"} = "internal";
    $int = gatherer("What is my external interface (facing the network)?","");
    gatherer("What is its IP address?","interface $int.ip");
    gatherer("What is its mask?","interface $int.mask");
    $cfg{"interface $int"}{"type"} = "managed";

    $tmp_net = new Net::Netmask($cfg{"interface $int"}{"ip"}, $cfg{"interface $int"}{"mask"});   
    $cfg{"interface $int"}{"gateway"} = $tmp_net->nth(1);

    gatherer("What is my gateway?","interface $int.gateway");
    gatherer("Enable NAT?","network.nat",("enabled","disabled"));
 } else {
    # hack to force default value
    $cfg{'tmp'}{'managed'} = "eth0";
    $int = gatherer("What is my management interface?","tmp.managed",get_interfaces());
    delete($cfg{'tmp'});

    gatherer("What is its IP address?","interface $int.ip");
    gatherer("What is its mask?","interface $int.mask");
    $cfg{"interface $int"}{"type"} = "internal,managed";

    $tmp_net = new Net::Netmask($cfg{"interface $int"}{"ip"}, $cfg{"interface $int"}{"mask"});
    $cfg{"interface $int"}{"gateway"} = $tmp_net->nth(1);

    gatherer("What is my gateway?","interface $int.gateway");
  
    print "\n** NOTE: You must manually set testing=disabled in pf.conf to allow PF to send ARPs **\n\n" if (!$template);
  }
}

sub config_registration{
    my $rc;
    print "\n** NOTE: There are several registration timers/windows to be set in pf.conf - please be sure to review them **\n\n";
    gatherer("Do you wish to have users accept an AUP?","registration.aup",("enabled","disabled"));
    my $auth = gatherer("How would you like users to authenticate at registration?","registration.auth",("local","ldap","radius","mysql"));
    if ($auth =~ /^ldap$/i) {
      if (!installed("mod_authz_ldap")) {
        if (questioner("I need to install mod_authz_ldap - is that OK?","y",("y","n"))) {
          system("/usr/sbin/up2date","mod_authz_ldap",$rc);
          die("Error installing mod_authz_ldap!\n") if ($rc);
        }
      }
    } elsif ($auth =~ /^mysql$/i) {
      if (questioner("I need to install mod_auth_mysql - is that OK?","y",("y","n"))) {
        $rc = system("/usr/sbin/up2date mod_auth_mysql");
        die("Error installing mod_auth_mysql!\n") if ($rc);
      }
    } elsif ($auth =~ /^radius$/i) {
      print "Not yet implemented! :(\n";
    }

  gatherer("Would you like violation content accessible via iptables passthroughs or apache proxy?","trapping.passthrough",("iptables","proxy"));
}


# return an array of hash with network information
#
sub get_networkinfo {
  my $mode = shift @_;
  my @ints;
  open(PROC, "/sbin/ifconfig -a|") || die "Can't open ifconfig $!\n";
  while(<PROC>) {
    if (/^(\S+)\s+Link/){
        my $int = $1;
        next if ($int eq "lo");
        $_=<PROC>;
        my %ref;
        if (/inet addr:((?:\d{1,3}\.){3}\d{1,3}).+Mask:((?:\d{1,3}\.){3}\d{1,3})/){
          %ref=( 'device' => $int, 'ip' => $1, 'mask' => $2 );
        }
        push @ints, \%ref if (%ref);
    }
  }
  return @ints;
}

sub get_interfaces {
  my @ints;
  my @ints2;
  opendir(PROC, "/proc/sys/net/ipv4/conf") || die "Unable to enumerate interfaces: $!";
  @ints = readdir(PROC);
  closedir(PROC);

  foreach my $int (@ints) {
    next if ($int eq "lo" || $int eq "all" || $int eq "default" || $int eq "." || $int eq "..");
    push @ints2, $int;
  }
  return(@ints2);
}

sub installed {
  my ($rpm) = @_;
  return(! `rpm -q $rpm` !~ /not installed/);
}
