#
# Copyright 2005 David LaPorte <david@davidlaporte.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

package pf::iptables;

use strict;
use warnings;
use IPTables::ChainMgr;
use Log::Log4perl;

BEGIN {
  use Exporter ();
  our (@ISA, @EXPORT);
  @ISA    = qw(Exporter);
  @EXPORT = qw(iptables_generate iptables_save iptables_restore iptables_mark_node iptables_unmark_node);
}

use pf::config;
use pf::util;
use pf::class qw(class_view_all class_trappable);
use pf::violation qw(violation_view_open_all violation_count);
#use pf::rawip qw(freemac);  

sub iptables_generate {
  my $logger = Log::Log4perl::get_logger('pf::iptables');
  my $passthroughs;
  my @vids = class_view_all();
  my %tags = ('filter_rules' => '', 'mangle_rules' => '', 'nat_rules' => '');

  # mark all users
  $tags{'mangle_rules'} .= "-A PREROUTING --jump MARK --set-mark 0x$unreg_mark\n";

  # mark all registered users
  if (isenabled($Config{'trapping'}{'registration'})) {
    require pf::node;
    my @registered = pf::node::nodes_registered();
    foreach my $row (@registered) {
      my  $mac = $row->{'mac'};
      $tags{'mangle_rules'} .= "-A PREROUTING --match mac --mac-source $mac --jump MARK --set-mark 0x$reg_mark\n";
    }
  }

  # mark whitelisted users
  foreach my $mac (split(/\s*,\s*/, $Config{'trapping'}{'whitelist'})) {
    $tags{'mangle_rules'} .= "-A PREROUTING --match mac --mac-source $mac --jump MARK --set-mark 0x$reg_mark\n";
  }

  # mark all open violations
  my @macarray= violation_view_open_all();
  if ($macarray[0]){
    foreach my $row (@macarray) {
      my $mac = $row->{'mac'};
      my $vid = $row->{'vid'};
      $tags{'mangle_rules'} .= "-A PREROUTING --match mac --mac-source $mac --jump MARK --set-mark 0x$vid\n";
    }
  }
  
  # mark blacklisted users
  foreach my $mac (split(/\s*,\s*/, $Config{'trapping'}{'blacklist'})) {
    $tags{'mangle_rules'} .= "-A PREROUTING --match mac --mac-source $mac --jump MARK --set-mark $black_mark\n";
  }

# INITIALIZE FILTER TABLE

  # open up loopback
  $tags{'filter_rules'} .= "-A INPUT --in-interface lo --jump ACCEPT\n";

  # registration/trapping server
  $tags{'filter_rules'} .= internal_append_entry("-A INPUT --protocol tcp --destination-port 80 --jump ACCEPT");
  $tags{'filter_rules'} .= internal_append_entry("-A INPUT --protocol tcp --destination-port 443 --jump ACCEPT");

  my @listeners = split(/\s*,\s*/, $Config{'ports'}{'listeners'});
  foreach my $listener (@listeners) {
    my $port =  getservbyname($listener, "tcp");
    $tags{'filter_rules'} .= internal_append_entry("-A INPUT --protocol tcp --destination-port $port --jump ACCEPT");
  }

  # allowed established sessions from pf box
  $tags{'filter_rules'} .= "-A INPUT --match state --state RELATED,ESTABLISHED --jump ACCEPT\n";

  # open ports
  $tags{'filter_rules'} .= managed_append_entry("-A INPUT --protocol icmp --icmp-type 8 --jump ACCEPT");
  $tags{'filter_rules'} .= managed_append_entry("-A INPUT --protocol tcp --destination-port " . $Config{'ports'}{'admin'} . " --jump ACCEPT");
  $tags{'filter_rules'} .= managed_append_entry("-A INPUT --protocol tcp --destination-port 22 --jump ACCEPT");

  # open dhcp if network.mode=dhcp
  if ($Config{'network'}{'mode'} =~ /dhcp/i) {
    $tags{'filter_rules'} .= internal_append_entry("-A INPUT --protocol udp --destination-port 67 --jump ACCEPT");
  }

  # accept already established connections
  foreach my $out_dev (get_internal_devs()) {
    $tags{'filter_rules'} .= external_append_entry("-A FORWARD --match state --state RELEATED,ESTABLISHED --out-interface $out_dev --jump ACCEPT");
  }

  # allowed tcp ports
  foreach my $dns (split(",", $Config{'general'}{'dnsservers'})) {
    $tags{'filter_rules'} .= internal_append_entry("-A FORWARD --protocol udp --destination $dns --destination-port 53 --jump ACCEPT");
    $logger->info("adding DNS FILTER passthrough for $dns");
  }

  $tags{'filter_rules'} .= internal_append_entry("-A FORWARD --protocol udp --destination-port 67 --jump ACCEPT");
  $logger->info("adding DHCP FILTER passthrough");

  my $scan_server = $Config{'scan'}{'host'};
  if ($scan_server !~ /^127\.0\.0\.1$/ && $scan_server !~ /^localhost$/i) {
    $tags{'filter_rules'} .= internal_append_entry("-A FORWARD --destination $scan_server --jump ACCEPT");
    $tags{'filter_rules'} .= external_append_entry("-A FORWARD --source $scan_server --jump ACCEPT");
    $logger->info("adding Nessus FILTER passthrough for $scan_server");
  }

  # poke passthroughs
  my %passthroughs;
  %passthroughs = %{$Config{'passthroughs'}} if ($Config{'trapping'}{'passthrough'} =~ /^iptables$/i);
  $passthroughs{'trapping.redirecturl'} = $Config{'trapping'}{'redirecturl'} if ($Config{'trapping'}{'redirecturl'});
  foreach my $passthrough (keys %passthroughs) {
    if ($passthroughs{$passthrough} =~ /^(http|https):\/\//) {
      my $destination;
      my ($service, $host, $port, $path) = $passthroughs{$passthrough} =~ /^(\w+):\/\/(.+?)(:\d+){0,1}(\/.*){0,1}$/;
      $port =~ s/:// if $port;

      $port = 80 if (!$port && $service =~ /^http$/i);    
      $port = 443 if (!$port && $service =~ /^https$/i);
  
      my ($name, $aliases, $addrtype, $length, @addrs) = gethostbyname($host);
      if (!@addrs) {
        $logger->error("unable to resolve $host for passthrough");
        next;
      }
      foreach my $addr (@addrs) {
        $destination = join(".",unpack('C4', $addr));
        $tags{'filter_rules'} .= internal_append_entry("-A FORWARD --protocol tcp --destination $destination --destination-port $port --jump ACCEPT");
        $logger->info("adding FILTER passthrough for $passthrough");
      }
    } elsif ($passthroughs{$passthrough} =~ /^(\d{1,3}.){3}\d{1,3}(\/\d+){0,1}$/) {
      $tags{'filter_rules'} .= internal_append_entry("-A FORWARD --destination " . $passthroughs{$passthrough} . " --jump ACCEPT");
      $logger->info("adding FILTER passthrough for $passthrough");
    } else {
      $logger->error("unrecognized passthrough $passthrough");
    }
  }

  # poke holes for content URLs
  # can we collapse with above?
  if ($Config{'trapping'}{'passthrough'} eq "iptables") {
    my @contents = class_view_all();
    foreach my $content (@contents) {
      my $vid = $content->{'vid'};
      my $url = $content->{'url'};
      my $max_enable_url = $content->{'max_enable_url'};
      my $redirect_url = $content->{'redirect_url'};

      foreach my $u ($url, $max_enable_url, $redirect_url) {
        # local content or null URLs
        next if (!$u || $u =~ /^\//);
        if ($u !~ /^(http|https):\/\//) {
          $logger->error("vid $vid: unrecognized content URL: $u");
          next;
        }

        my $destination;
        my ($service, $host, $port, $path) = $u =~ /^(\w+):\/\/(.+?)(:\d+){0,1}(\/.*){0,1}$/;
  
        $port =~ s/:// if $port;

        $port = 80 if (!$port && $service =~ /^http$/i);    
        $port = 443 if (!$port && $service =~ /^https$/i);

        my ($name, $aliases, $addrtype, $length, @addrs) = gethostbyname($host);
        if (!@addrs) {
          $logger->error("unable to resolve $host for content passthrough");
          next;
        }
        foreach my $addr (@addrs) {
          $destination = join(".",unpack('C4', $addr));
          $tags{'filter_rules'} .= internal_append_entry("-A FORWARD --protocol tcp --destination $destination --destination-port $port --match mark --mark 0x$vid --jump ACCEPT");
          $logger->info("adding FILTER passthrough for $destination:$port");
        }
      }
    }
  }

  my @trapvids = class_trappable();
  foreach my $row (@trapvids) {
    my $vid = $row->{'vid'};
    $tags{'filter_rules'} .= internal_append_entry("-A FORWARD --match mark --mark 0x$vid --jump DROP");
  }    

# INITIALIZE NAT TABLE
# MASSIVE CODE REDUNDANCY

  foreach my $dns (split(",", $Config{'general'}{'dnsservers'})) {
    $tags{'nat_rules'} .= internal_append_entry("-A PREROUTING --protocol udp --destination $dns --destination-port 53 --jump ACCEPT");
    $logger->info("adding DNS NAT passthrough for $dns");
  }

  $tags{'nat_rules'} .= internal_append_entry("-A PREROUTING --protocol udp --destination-port 67 --jump ACCEPT");
  $logger->info("adding DHCP NAT passthrough");
  

  if ($scan_server !~ /^127\.0\.0\.1$/ && $scan_server !~ /^localhost$/i) {
    $tags{'nat_rules'} .= internal_append_entry("-A PREROUTING --destination $scan_server --jump ACCEPT");
    $tags{'nat_rules'} .= internal_append_entry("-A PREROUTING --source $scan_server --jump ACCEPT");
    $logger->info("adding Nessus NAT passthrough for $scan_server");
  }

  # poke passthroughs
  %passthroughs = %{$Config{'passthroughs'}} if ($Config{'trapping'}{'passthrough'} =~ /^iptables$/i);
  $passthroughs{'trapping.redirecturl'} = $Config{'trapping'}{'redirecturl'} if ($Config{'trapping'}{'redirecturl'});


  foreach my $passthrough (keys %passthroughs) {
    if ($passthroughs{$passthrough} =~ /^(http|https):\/\//) {
      my $destination;
      my ($service, $host, $port, $path) = $passthroughs{$passthrough} =~ /^(\w+):\/\/(.+?)(:\d+){0,1}(\/.*){0,1}$/;
      $port =~ s/:// if $port;

      $port = 80 if (!$port && $service =~ /^http$/i);    
      $port = 443 if (!$port && $service =~ /^https$/i);
  
      my ($name, $aliases, $addrtype, $length, @addrs) = gethostbyname($host);
      if (!@addrs) {
        $logger->error("unable to resolve $host for passthrough");
        next;
      }
      foreach my $addr (@addrs) {
        $destination = join(".",unpack('C4', $addr));
        $tags{'nat_rules'} .= internal_append_entry("-A PREROUTING --protocol tcp --destination $destination --destination-port $port --jump ACCEPT");
        $logger->info("adding NAT passthrough for $passthrough");
      }
    } elsif ($passthroughs{$passthrough} =~ /^(\d{1,3}.){3}\d{1,3}(\/\d+){0,1}$/) {
      $tags{'nat_rules'} .= internal_append_entry("-A PREROUTING --destination " . $passthroughs{$passthrough} . " --jump ACCEPT");
      $logger->info("adding NAT passthrough for $passthrough");
    } else {
      $logger->error("unrecognized passthrough $passthrough");
    }
  }

  # poke holes for content URLs
  # can we collapse with above?
  if ($Config{'trapping'}{'passthrough'} eq "iptables") {
    my @contents = class_view_all();
    foreach my $content (@contents) {
      my $vid = $content->{'vid'};
      my $url = $content->{'url'};
      my $max_enable_url = $content->{'max_enable_url'};
      my $redirect_url = $content->{'redirect_url'};

      foreach my $u ($url, $max_enable_url, $redirect_url) {
        # local content or null URLs
        next if (!$u || $u =~ /^\//);
        if ($u !~ /^(http|https):\/\//) {
          $logger->error("vid $vid: unrecognized content URL: $u");
          next;
        }

        my $destination;
        my ($service, $host, $port, $path) = $u =~ /^(\w+):\/\/(.+?)(:\d+){0,1}(\/.*){0,1}$/;
  
        $port =~ s/:// if $port;

        $port = 80 if (!$port && $service =~ /^http$/i);    
        $port = 443 if (!$port && $service =~ /^https$/i);

        my ($name, $aliases, $addrtype, $length, @addrs) = gethostbyname($host);
        if (!@addrs) {
          $logger->error("unable to resolve $host for content passthrough");
          next;
        }
        foreach my $addr (@addrs) {
          $destination = join(".",unpack('C4', $addr));
          $tags{'nat_rules'} .= internal_append_entry("-A PREROUTING --protocol tcp --destination $destination --destination-port $port --match mark --mark 0x$vid --jump ACCEPT");
          $logger->info("adding NAT passthrough for $destination:$port");
        }
      }
    }
  }

  # how we do our magic
  foreach my $redirectport (split(/\s*,\s*/, $Config{'ports'}{'redirect'})) {
    my ($port, $protocol) = split("/", $redirectport);
    if (isenabled($Config{'trapping'}{'registration'})) {
      $tags{'nat_rules'} .= internal_append_entry("-A PREROUTING --protocol $protocol --destination-port $port --match mark --mark 0x$unreg_mark --jump REDIRECT");
    }

    my @trapvids = class_trappable();

    foreach my $row (@trapvids) {
      my $vid = $row->{'vid'};
      $tags{'nat_rules'} .= internal_append_entry("-A PREROUTING --protocol $protocol --destination-port $port --match mark --mark 0x$vid --jump REDIRECT");
    }
  }
  chomp($tags{'mangle_rules'});
  chomp($tags{'filter_rules'});
  chomp($tags{'nat_rules'});
  parse_template(\%tags, "$conf_dir/templates/iptables.conf", "$conf_dir/iptables.conf");
  iptables_restore("$conf_dir/iptables.conf");
}

sub internal_append_entry {
  my ($cmd_arg) = @_;
  my $logger = Log::Log4perl::get_logger('pf::iptables');
  my $returnString = '';
  foreach my $internal (@internal_nets) {
    my $dev = $internal->tag("int");
    my @authorized_ips = split(/\s*,\s*/, $internal->tag("authips"));
    if (scalar(@authorized_ips) == 0) {
      push @authorized_ips, '';
    }
    foreach my $authorized_subnet (@authorized_ips) {
      if ($authorized_subnet ne '') {
        $cmd_arg .= " --source $authorized_subnet";
      }
      $cmd_arg .= " --in-interface $dev";
      $returnString .= "$cmd_arg\n";
    }
  }
  return $returnString;
}

sub managed_append_entry {
  my ($cmd_arg) = @_;
  my $logger = Log::Log4perl::get_logger('pf::iptables');
  my $returnString = '';
  foreach my $managed (@managed_nets) {
    my $dev = $managed->tag("int");
    my @authorized_ips = split(/\s*,\s*/, $managed->tag("authips"));
    if (scalar(@authorized_ips) == 0) {
      push @authorized_ips, '';
    }
    foreach my $authorized_subnet (@authorized_ips) {
      if ($authorized_subnet ne '') {
        $cmd_arg .= " --source $authorized_subnet";
      }
      $cmd_arg .= " --in-interface $dev";
      $returnString .= "$cmd_arg\n";
    }
  }
  return $returnString;
}

sub external_append_entry {
  my ($cmd_arg) = @_;
  my $logger = Log::Log4perl::get_logger('pf::iptables');
  my $returnString = '';
  foreach my $dev (get_external_devs()){
    $cmd_arg .= " --in-interface $dev";
    $returnString .= "$cmd_arg\n";
  }
  return $returnString;
}

sub iptables_mark_node {
  my ($mac, $mark) = @_;
  my $logger = Log::Log4perl::get_logger('pf::iptables');
  my $iptables = new IPTables::ChainMgr() || logger->logdie("unable to create IPTables::ChainMgr object");
  my $iptables_cmd = $iptables->{'_iptables'};

  if (!$iptables->run_ipt_cmd("$iptables_cmd -t mangle -A PREROUTING --match mac --mac-source $mac --jump MARK --set-mark 0x$mark")) {
    $logger->error("unable to mark $mac with $mark: $!");
    return(0);
  }
  return(1);
}

sub iptables_unmark_node {
  my ($mac, $mark) = @_;
  my $logger = Log::Log4perl::get_logger('pf::iptables');
  my $iptables = new IPTables::ChainMgr() || logger->logdie("unable to create IPTables::ChainMgr object");
  my $iptables_cmd = $iptables->{'_iptables'};

  if (!$iptables->run_ipt_cmd("$iptables_cmd -t mangle -D PREROUTING --match mac --mac-source $mac --jump MARK --set-mark 0x$mark")) {
    $logger->error("unable to unmark $mac with $mark: $!");
    return(0);
  }
  # let redir cgi do this... 
  #freemac($mac) if ($Config{'network'}{'mode'} =~ /^arp$/i && !violation_count($mac));
  return(1);
}

sub iptables_save {
  my ($save_file) = @_;
  my $logger = Log::Log4perl::get_logger('pf::iptables');
  $logger->info("saving existing iptables to ".$save_file);
  `/sbin/iptables-save -t nat > $save_file`;
  `/sbin/iptables-save -t mangle >> $save_file`;
  `/sbin/iptables-save -t filter >> $save_file`;
}

sub iptables_restore {
  my ($restore_file) = @_;
  my $logger = Log::Log4perl::get_logger('pf::iptables');
  if (-r $restore_file) {
    $logger->info("restoring iptables from ".$restore_file);
    `/sbin/iptables-restore < $restore_file`;
  }
}

sub iptables_restore_noflush {
  my ($restore_file) = @_;
  my $logger = Log::Log4perl::get_logger('pf::iptables');
  if (-r $restore_file) {
    $logger->info("restoring iptables (no flush) from ".$restore_file);
    `/sbin/iptables-restore -n < $restore_file`;
  }
}
1;
