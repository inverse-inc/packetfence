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
use IPTables::IPv4;
use Log::Log4perl;

BEGIN {
  use Exporter ();
  our (@ISA, @EXPORT);
  @ISA    = qw(Exporter);
  @EXPORT = qw(iptables_generate iptables_save iptables_restore iptables_mark_node iptables_unmark_node);
}

use lib qw(/usr/local/pf/lib);
use pf::config;
use pf::util;
use pf::class qw(class_view_all class_trappable);
use pf::violation qw(violation_view_open_all violation_count);
#use pf::rawip qw(freemac);  
use pf::node qw(nodes_registered);

sub zero_table {
  my ($table) = @_;
  my $logger = Log::Log4perl::get_logger('pf::iptables');
  my $bob = IPTables::IPv4::init($table);
  foreach my $chain ($bob->list_chains()) {
    $logger->info("flushing $chain chain");
    $bob->flush_entries($chain);
    $bob->set_policy($chain, 'ACCEPT');
  }
  if (! $bob->commit() ) {
   $logger->logdie("IPTables commit error: $!");
  }
}

sub iptables_generate {
  my $logger = Log::Log4perl::get_logger('pf::iptables');
  my $pre_file = $install_dir.'/conf/iptables.pre';
  my $post_file = $install_dir.'/conf/iptables.post';
  my $passthroughs;
  my @vids = class_view_all();

  zero_table("mangle");
  zero_table("nat");
  zero_table("filter");

  if (-r $pre_file) {
    iptables_restore($pre_file);
  }

  # INITIALIZE MANGLE TABLE
  # MARK ALL PACKETS WITH 0x0
  #

  my $mangle = IPTables::IPv4::init('mangle');
  $mangle->set_policy('PREROUTING', 'ACCEPT');
  $mangle->set_policy('POSTROUTING', 'ACCEPT');
  $mangle->set_policy('OUTPUT', 'ACCEPT');
  # mark all users
  if (!$mangle->append_entry('PREROUTING', {
       'jump' => 'MARK',
       'set-mark' => "0x".$unreg_mark
  } )) {
    $logger->logdie("Unable to initialize rule: $!");
  }

  # mark all registered users
  if (isenabled($Config{'trapping'}{'registration'})) {
    my @registered = nodes_registered();
    foreach my $row (@registered) {
      my  $mac = $row->{'mac'};
      if (!$mangle->append_entry('PREROUTING', {
           'mac-source' => $mac,
           'jump' => 'MARK',
           'set-mark' => "0x".$reg_mark,
           'matches' => ['mac']
      } )) {
        $logger->logdie("Unable to initialize rule: $!");
      }
    }
  }

  # mark whitelisted users
  foreach my $mac (split(/\s*,\s*/, $Config{'trapping'}{'whitelist'})) {
    if (!$mangle->append_entry('PREROUTING', {
         'mac-source' => $mac,
         'jump' => 'MARK',
         'set-mark' => "0x".$reg_mark,
         'matches' => ['mac']
    } )) {
      $logger->logdie("Unable to initialize rule: $!");
    }
  }

  # mark all open violations
  my @macarray= violation_view_open_all();
  if ($macarray[0]){
    foreach my $row (@macarray) {
      my $mac = $row->{'mac'};
      my $vid = $row->{'vid'};
      if (!$mangle->append_entry('PREROUTING', {
           'mac-source' => $mac,
           'jump' => 'MARK',
           'set-mark' => "0x".$vid,
           'matches' => ['mac']
      } )) {
        $logger->logdie("Unable to initialize rule: $!");
      }
    }
  }
  
  # mark blacklisted users
  foreach my $mac (split(/\s*,\s*/, $Config{'trapping'}{'blacklist'})) {
    if (!$mangle->append_entry('PREROUTING', {
         'mac-source' => $mac,
         'jump' => 'MARK',
         'set-mark' => "$black_mark",
         'matches' => ['mac']
    } )) {
      $logger->logdie("Unable to initialize rule: $!");
    }
  }

# INITIALIZE FILTER TABLE

  my $filter = IPTables::IPv4::init('filter');
  $filter->set_policy('INPUT','DROP');
  $filter->set_policy('FORWARD','DROP');
  $filter->set_policy('OUTPUT','ACCEPT');
  
  # open up loopback
  if (!$filter->append_entry('INPUT', {
       'in-interface' => 'lo',
       'jump' => 'ACCEPT'
  } )) {
    $logger->logdie("Unable to initialize rule: $!");
  }

  #  registration/trapping server                                                                                                                      
  internal_append_entry($filter,'INPUT',{
       'protocol' => 'tcp',
       'destination-port' => '80',  
       'jump' => 'ACCEPT'
  });

  internal_append_entry($filter,'INPUT',{
       'protocol' => 'tcp',
       'destination-port' => '443',
       'jump' => 'ACCEPT'
  });

  my @listeners = split(/\s*,\s*/, $Config{'ports'}{'listeners'});
  foreach my $listener (@listeners) {
    my $port =  getservbyname($listener, "tcp");
    internal_append_entry($filter,'INPUT',{
         'protocol' => 'tcp',
         'destination-port' => $port,
         'jump' => 'ACCEPT'
    });
  }

  # allowed established sessions from pf box
  if (!$filter->append_entry('INPUT', {
       'matches' => ['state'],
       'state' => ['RELATED','ESTABLISHED'],
       'jump' => 'ACCEPT'
  } )) {
    $logger->logdie("Unable to initialize rule: $!");
  }

  # open ports
  foreach my $openport (split(/\s*,\s*/, $Config{'ports'}{'open'})) {
    my ($port, $protocol) = split("/", $openport);
    managed_append_entry($filter,'INPUT', {
         'protocol' => $protocol,
         'destination-port' => $port,
         'jump' => 'ACCEPT'
    });
  }
  managed_append_entry($filter,'INPUT', {
         'protocol' => 'icmp',
         'icmp-type' => 8,
	      'jump' => 'ACCEPT'
  });
  managed_append_entry($filter,'INPUT', {
         'protocol' => "tcp",
         'destination-port' => $Config{'ports'}{'admin'},
         'jump' => 'ACCEPT'
  });
  managed_append_entry($filter,'INPUT', {
         'protocol' => "tcp",
         'destination-port' => 22,
         'jump' => 'ACCEPT'
  });

  if (isenabled($Config{'network'}{'named'})) {
    internal_append_entry($filter,'INPUT',{
         'protocol' => 'udp',
         'destination-port' => '53',
         'jump' => 'ACCEPT'
    });
  }

  # open dhcp if network.mode=dhcp
  if ($Config{'network'}{'mode'} =~ /dhcp/i) {
    internal_append_entry($filter,'INPUT',{
         'protocol' => 'udp',
         'destination-port' => '67',
         'jump' => 'ACCEPT'
    });
  }

  # accept already established connections
  external_append_entry($filter,'FORWARD', {
       'matches' => ['state'],
       'state' => ['RELATED','ESTABLISHED'],
       'jump' => 'ACCEPT'
  }, get_internal_devs());

  # allowed tcp ports
  foreach my $allowedport (split(/\s*,\s*/, $Config{'ports'}{'allowed'})) {
    my ($port, $protocol) = split("/", $allowedport);
    internal_append_entry($filter,'FORWARD', {
         'protocol' => $protocol,
         'destination-port' => $port,
         'jump' => 'ACCEPT'
    }, get_external_devs());

    internal_append_entry($filter,'FORWARD', {
         'protocol' => $protocol,
         'source-port' => $port,
         'jump' => 'ACCEPT'
    });
  }

  foreach my $dns (split(",", $Config{'general'}{'dnsservers'})) {
    internal_append_entry($filter,'FORWARD',{
      'protocol' => 'udp',
      'destination' => $dns,
      'destination-port' => 53,
      'jump' => 'ACCEPT'
    });
    $logger->info("adding DNS FILTER passthrough for $dns");
  }

  internal_append_entry($filter,'FORWARD',{
      'protocol' => 'udp',
      'destination-port' => 67,
      'jump' => 'ACCEPT'
  });
  $logger->info("adding DHCP FILTER passthrough");

  my $scan_server = $Config{'scan'}{'host'};
  if ($scan_server !~ /^127\.0\.0\.1$/ && $scan_server !~ /^localhost$/i) {
    internal_append_entry($filter,'FORWARD',{
      'destination' => $scan_server,
      'jump' => 'ACCEPT'
    });
    external_append_entry($filter,'FORWARD',{
      'source' => $scan_server,
      'jump' => 'ACCEPT'
    });
    $logger->info("adding Nessus FILTER passthrough for $scan_server");
  }

  # poke passthroughs
  my %passthroughs = %{$Config{'passthroughs'}} if ($Config{'trapping'}{'passthrough'} =~ /^iptables$/i);
  $passthroughs{'trapping.redirecturl'} = $Config{'trapping'}{'redirecturl'} if ($Config{'trapping'}{'redirecturl'});
  $passthroughs{'trapping.pinurl'} = $Config{'harvard'}{'pinurl'} if (grep(/^harvard$/i, split(/\s*,\s*/,$Config{'registration'}{'auth'})));
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
        internal_append_entry($filter,'FORWARD',{
             'protocol' => 'tcp',
             'destination' => $destination,
             'destination-port' => $port,
             'jump' => 'ACCEPT'
        });
        $logger->info("adding FILTER passthrough for $passthrough");
      }
    } elsif ($passthroughs{$passthrough} =~ /^(\d{1,3}.){3}\d{1,3}(\/\d+){0,1}$/) {
      internal_append_entry($filter,'FORWARD',{
          'destination' => $passthroughs{$passthrough},
          'jump' => 'ACCEPT'
      });
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
	  internal_append_entry($filter,'FORWARD',{
               'protocol' => 'tcp',
               'destination' => $destination,
               'destination-port' => $port,
               'matches' => ['mark'],                 
               'mark' => "0x".$vid,
               'jump' => 'ACCEPT'
          });
          $logger->info("adding FILTER passthrough for $destination:$port");
        }
      }
    }
  }

  my @trapvids = class_trappable();
  foreach my $row (@trapvids) {
    my $vid = $row->{'vid'};
    internal_append_entry($filter,'FORWARD',{
        'matches' => ['mark'],
        'mark' => "0x".$vid,
        'jump' => 'DROP'
    });
  }    

# INITIALIZE NAT TABLE
# MASSIVE CODE REDUNDANCY

  my $nat = IPTables::IPv4::init('nat');
  $nat->set_policy('PREROUTING','ACCEPT');
  $nat->set_policy('POSTROUTING','ACCEPT');
  $nat->set_policy('OUTPUT','ACCEPT');

  foreach my $dns (split(",", $Config{'general'}{'dnsservers'})) {
    internal_append_entry($nat,'PREROUTING',{
      'protocol' => 'udp',
      'destination' => $dns,
      'destination-port' => 53,
      'jump' => 'ACCEPT'
    });
    $logger->info("adding DNS NAT passthrough for $dns");
  }

  internal_append_entry($nat,'PREROUTING',{
      'protocol' => 'udp',
      'destination-port' => 67,
      'jump' => 'ACCEPT'
  });
  $logger->info("adding DHCP NAT passthrough");
  

  if ($scan_server !~ /^127\.0\.0\.1$/ && $scan_server !~ /^localhost$/i) {
    internal_append_entry($nat,'PREROUTING',{
      'destination' => $scan_server,
      'jump' => 'ACCEPT'
    });
    internal_append_entry($nat,'PREROUTING',{
      'source' => $scan_server,
      'jump' => 'ACCEPT'
    });
    $logger->info("adding Nessus NAT passthrough for $scan_server");
  }

  # poke passthroughs
  %passthroughs = %{$Config{'passthroughs'}} if ($Config{'trapping'}{'passthrough'} =~ /^iptables$/i);
  $passthroughs{'trapping.redirecturl'} = $Config{'trapping'}{'redirecturl'} if ($Config{'trapping'}{'redirecturl'});

  $passthroughs{'trapping.pinurl'} = $Config{'harvard'}{'pinurl'} if (grep(/^harvard$/i, split(/\s*,\s*/,$Config{'registration'}{'auth'})));

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
        internal_append_entry($nat,'PREROUTING',{
             'protocol' => 'tcp',
             'destination' => $destination,
             'destination-port' => $port,
             'jump' => 'ACCEPT'
        });
        $logger->info("adding NAT passthrough for $passthrough");
      }
    } elsif ($passthroughs{$passthrough} =~ /^(\d{1,3}.){3}\d{1,3}(\/\d+){0,1}$/) {
      internal_append_entry($nat,'PREROUTING',{
          'destination' => $passthroughs{$passthrough},
          'jump' => 'ACCEPT'
      });
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
          internal_append_entry($nat,'PREROUTING',{
                 'protocol' => 'tcp',
                 'destination' => $destination,
                 'destination-port' => $port,
                 'matches' => ['mark'],                 
                 'mark' => "0x".$vid,
                 'jump' => 'ACCEPT'
            });
          $logger->info("adding NAT passthrough for $destination:$port");
        }
      }
    }
  }

  # how we do our magic
  foreach my $redirectport (split(/\s*,\s*/, $Config{'ports'}{'redirect'})) {
    my ($port, $protocol) = split("/", $redirectport);
    if (isenabled($Config{'trapping'}{'registration'})) {
      internal_append_entry($nat,'PREROUTING',{
           'protocol' => $protocol,
           'destination-port' => $port,
           'matches' => ['mark'],
           'mark' => "0x".$unreg_mark,
           'jump' => 'REDIRECT'
      });
    }

    my @trapvids = class_trappable();

    foreach my $row (@trapvids) {
      my $vid = $row->{'vid'};
      internal_append_entry($nat,'PREROUTING',{
           'protocol' => $protocol,
           'destination-port' => $port,
           'matches' => ['mark'],
           'mark' => "0x".$vid,   
           'jump' => 'REDIRECT'
      });
    }
  }

  if (!$mangle->commit()) {
    $logger->logdie("IPTables mangle table commit error: $!");
  }
  if (!$nat->commit()) {
    $logger->logdie("IPTables nat table commit error: $!");
  }
  if (!$filter->commit()) {
    $logger->logdie("IPTables filter table commit error: $!");
  }
  if (-r $post_file) {
    iptables_restore_noflush($post_file);
  }
}

sub internal_append_entry {
  my ($obj, $type, $params, @output_interfaces) = @_;
  my $logger = Log::Log4perl::get_logger('pf::iptables');
  #foreach my $dev (get_internal_devs()){
  foreach my $internal (@internal_nets) {
    my $dev = $internal->tag("int");
    my @authorized_ips = split(/\s*,\s*/, $internal->tag("authips"));
    if (scalar(@authorized_ips) == 0) {
      push @authorized_ips, '';
    }
    foreach my $authorized_subnet (@authorized_ips) {
      if ($authorized_subnet ne '') {
        $params->{'source'} = $authorized_subnet;
      }
      $params->{'in-interface'} = $dev;
      if (scalar(@output_interfaces)) {
        foreach my $out_dev (@output_interfaces) {
          $params->{'out-interface'} = $out_dev;
          if (!$obj->append_entry($type,$params) ){
            $logger->logdie("Unable to initialize rule: $!");
          }
        }
      } else {
        if (!$obj->append_entry($type,$params) ){
          $logger->logdie("Unable to initialize rule: $!");
        }
      }
    }
  }
}

sub managed_append_entry {
  my ($obj, $type, $params, @output_interfaces) = @_;
  my $logger = Log::Log4perl::get_logger('pf::iptables');
  #foreach my $dev (get_managed_devs()){
  foreach my $managed (@managed_nets) {
    my $dev = $managed->tag("int");
    my @authorized_ips = split(/\s*,\s*/, $managed->tag("authips"));
    if (scalar(@authorized_ips) == 0) {
      push @authorized_ips, '';
    }
    foreach my $authorized_subnet (@authorized_ips) {
      if ($authorized_subnet ne '') {
        $params->{'source'} = $authorized_subnet;
      }
      $params->{'in-interface'} = $dev;
      if (scalar(@output_interfaces)) {
        foreach my $out_dev (@output_interfaces) {
          $params->{'out-interface'} = $out_dev;
          if (!$obj->append_entry($type,$params) ){
            $logger->logdie("Unable to initialize rule: $!");
          }
        }
      } else {
        if (!$obj->append_entry($type,$params) ){
          $logger->logdie("Unable to initialize rule: $!");
        }
      }
    }
  }
}

sub external_append_entry {
  my ($obj, $type, $params, @output_interfaces) = @_;
  my $logger = Log::Log4perl::get_logger('pf::iptables');
  foreach my $dev (get_external_devs()){
    $params->{'in-interface'} = $dev;
    if (scalar(@output_interfaces)) {
      foreach my $out_dev (@output_interfaces) {
        $params->{'out-interface'} = $out_dev;
        if (!$obj->append_entry($type,$params) ){
          $logger->logdie("Unable to initialize rule: $!");
        }
      }
    } else {
      if (!$obj->append_entry($type,$params) ){
        $logger->logdie("Unable to initialize rule: $!");
      }
    }
  }
}

sub iptables_mark_node {
  my ($mac, $mark) = @_;
  my $logger = Log::Log4perl::get_logger('pf::iptables');
  my $mangle = IPTables::IPv4::init('mangle');

  if (!$mangle->append_entry('PREROUTING', {
       'mac-source' => $mac,
       'jump' => 'MARK',
       'set-mark' => "0x".$mark,
       'matches' => ['mac']
  } )) {         
    $logger->error("unable to mark $mac with $mark: $!");
    return(0);
  }
  if (!$mangle->commit()) {
    $logger->error("unable to commit mark=$mark for $mac: $!");
    return(0);
  }
  return(1);
}

sub iptables_unmark_node {
  my ($mac, $mark) = @_;
  my $logger = Log::Log4perl::get_logger('pf::iptables');
  my $mangle = IPTables::IPv4::init('mangle');

  if (!$mangle->delete_entry('PREROUTING', {
       'mac-source' => $mac,
       'jump' => 'MARK',
       'set-mark' => "0x".$mark,
       'matches' => ['mac']
  } )) {         
    $logger->error("unable to unmark $mac with $mark: $!");
    return(0);
  }
  if (!$mangle->commit()) {
    $logger->error("unable to commit unmark=$mark for $mac: $!");
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
1
