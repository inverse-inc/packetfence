#
# Copyright 2005 David LaPorte <david@davidlaporte.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

package pf::util;

use strict;
use warnings;
use File::Basename;
use FileHandle;
use POSIX();
use Net::SMTP;
use Net::MAC::Vendor;
use Log::Log4perl;
use threads;
use threads::shared;

our (%trappable_ip, %reggable_ip, %is_internal, %local_mac);

BEGIN {
  use Exporter ();
  our (@ISA, @EXPORT);
  @ISA    = qw(Exporter);
  @EXPORT = qw(valid_date valid_ip clean_mac valid_mac whitelisted_mac trappable_mac trappable_ip reggable_ip
               inrange_ip ip2gateway ip2interface ip2device isinternal pfmailer isenabled
               isdisabled getlocalmac ip2int int2ip get_all_internal_ips get_internal_nets get_routed_isolation_nets get_routed_registration_nets get_internal_ips 
               get_internal_devs get_internal_devs_phy get_external_devs get_managed_devs get_internal_macs 
               get_internal_info get_gateways get_dhcp_devs num_interfaces createpid readpid deletepid 
               parse_template mysql_date oui_to_vendor normalize_time);
}

use pf::config;

if (basename($0) eq "pfmon" && isenabled($Config{'general'}{'caching'})) {
  %trappable_ip = preload_trappable_ip();
  %reggable_ip  = preload_reggable_ip();
  %is_internal  = preload_is_internal();
  %local_mac    = preload_getlocalmac();
}

sub valid_date {
  my ($date) = @_;
  my $logger = Log::Log4perl::get_logger('pf::util');
  # kludgy but short
  if ($date !~ /^\d{4}\-((0[1-9])|(1[0-2]))\-((0[1-9])|([12][0-9])|(3[0-1]))\s+(([01][0-9])|(2[0-3]))(:[0-5][0-9]){2}$/) {
    $logger->error("invalid date $date");
    return(0);
   } else {
    return(1);
  }
}

sub valid_ip {
  my ($ip) = @_;
  my $logger = Log::Log4perl::get_logger('pf::util');
  if (!$ip || $ip !~ /^(?:\d{1,3}\.){3}\d{1,3}$/ || $ip =~ /^0\.0\.0\.0$/) {
    my $caller = (caller(1))[3] || basename($0);
    $caller =~ s/^(pf::\w+|main):://;
    $logger->error("invalid IP: $ip from $caller");
    return(0);
  } else {
    return(1);
  }
}

sub clean_mac {
  my ($mac) = @_;
  return(0) if (!$mac);
  $mac =~ s/\s//g;
  $mac = lc($mac);
  $mac =~ s/\.//g if ($mac =~ /^([0-9a-f]{4}(\.|$)){4}$/i);
  $mac =~ s/([a-f0-9]{2})(?!$)/$1:/g if ($mac =~ /^[a-f0-9]{12}$/i);
  $mac = join q {:} => map {sprintf "%02x" => hex} split m {:|\-} => $mac;
  return($mac);
}

sub valid_mac {
  my ($mac) = @_;
  my $logger = Log::Log4perl::get_logger('pf::util');
  $mac = clean_mac($mac);
  if ($mac =~ /^ff:ff:ff:ff:ff:ff$/ || $mac =~ /^00:00:00:00:00:00$/ || $mac !~ /^([0-9a-f]{2}(:|$)){6}$/i) {
    $logger->error("invalid MAC: $mac");
    return(0);
  } else {
    return(1);
  }
}

sub whitelisted_mac {
  my ($mac) = @_;
  my $logger = Log::Log4perl::get_logger('pf::util');
  return(0) if (!valid_mac($mac));
  $mac = clean_mac($mac);
  foreach my $whitelist (split(/\s*,\s*/, $Config{'trapping'}{'whitelist'})) {
    if ($mac eq clean_mac($whitelist)) {
      $logger->info("$mac is whitelisted, skipping");
      return(1);
    }
  }
  return(0);
}

sub trappable_mac {
  my ($mac) = @_;
  my $logger = Log::Log4perl::get_logger('pf::util');
  return(0) if (!$mac);
  $mac = clean_mac($mac);
  #if (!valid_mac($mac) || whitelisted_mac($mac) || $mac eq getlocalmac(ip2device(mac2ip($mac))) || $mac eq $blackholemac) {
  if (!valid_mac($mac) || whitelisted_mac($mac) || grep(/^$mac$/,get_internal_macs()) || $mac eq $blackholemac ) {
    $logger->info("$mac is not trappable, skipping");
    return(0);
  } else {
    return(1);
  }
}

sub trappable_ip {
  my ($ip) = @_;
  return(0) if (!$ip || !valid_ip($ip));
  return($trappable_ip{$ip}) if (defined($trappable_ip{$ip}));
  return inrange_ip($ip,$Config{'trapping'}{'range'});
}

sub reggable_ip {
  my ($ip) = @_;
  return(0) if (!$ip || !valid_ip($ip));
  return(1) if (!defined $Config{'registration'}{'range'} || !$Config{'registration'}{'range'});
  return($reggable_ip{$ip}) if (defined($reggable_ip{$ip}));
  return inrange_ip($ip,$Config{'registration'}{'range'});
} 


sub inrange_ip { 
  my ($ip,$network_range) = @_;
  my $logger = Log::Log4perl::get_logger('pf::util');

  if (grep(/^$ip$/, get_gateways())) {
    $logger->info("$ip is a gateway, skipping");
    return(0);
  }
  if (grep(/^$ip$/, get_internal_ips())) {
    $logger->info("$ip is a local int, skipping");
    return(0);
  }

  foreach my $range (split(/\s*,\s*/, $network_range)) {
    if ($range =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}$/) {
      my $block = new Net::Netmask($range);
      if ($block->size()>2){
        return(1) if ($block->match($ip) && $block->nth(0) ne $ip && $block->nth(-1) ne $ip);
      }else{
        return(1) if ($block->match($ip));
      }  
      #return(1) if ($block->match($ip) && $block->nth(0) ne $ip && $block->nth(-1) ne $ip);
    } elsif ($range =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})-(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/) {

      my $int_ip = ip2int($ip);
      my $start  = $1;
      my $end    = $2;

      if (!valid_ip($start) || !valid_ip($end)) {
        $logger->error("$range not valid range!");
      } else {
        my $int_start = ip2int($start);
        my $int_end   = ip2int($end);
        return (1) if ($int_ip >= $int_start && $int_ip <= $int_end); 
      }
    } elsif ($range =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3})\.(\d{1,3})-(\d{1,3})$/) {

      my $int_ip = ip2int($ip);
      my $net    = $1;
      my $start  = $2;
      my $end    = $3;

      if (!valid_ip($net.".".$start) || $end < $start || $end > 255) {
        $logger->error("$range not valid range!");
      } else {
        my $int_start = ip2int($net.".".$start);
        my $int_end   = ip2int($net.".".$end);
        return (1) if ($int_ip >= $int_start && $int_ip <= $int_end); 
      }
	} elsif ($range =~ /^(?:\d{1,3}\.){3}\d{1,3}$/) {
      return (1) if ($range=~/^$ip$/); 	
	} else {
      $logger->error("$range not valid!");
      next;
    }
  }
  $logger->debug("$ip is not in $network_range, skipping");
  return(0);
}

sub ip2gateway {
  my ($ip) = @_;
  return(0) if (!valid_ip($ip));
  foreach my $interface (@internal_nets) {
    if ($interface->match($ip)) {
      return($interface->tag("gw"));
    }
  }
  return(0);
}

sub ip2interface {
  my ($ip) = @_;
  return(0) if (!valid_ip($ip));
  foreach my $interface (@internal_nets) {
    if ($interface->match($ip)) {
      return($interface->tag("ip"));
    }
  }
  return(0);
}

sub ip2device {
  my ($ip) = @_;
  return(0) if (!valid_ip($ip));
  foreach my $interface (@internal_nets) {
    if ($interface->match($ip)) {
      return($interface->tag("int"));
    }
  }
  return(0);
}

sub isinternal {
  my ($ip) = @_;
  return(0) if (!valid_ip($ip));
  return($is_internal{$ip}) if (defined($is_internal{$ip}));
  foreach my $interface (@internal_nets) {
    if ($interface->match($ip)) {
      return(1);
    }
  }
  return(0);
}

sub pfmailer {
  my (%data) = @_;
  my $logger = Log::Log4perl::get_logger('pf::util');
  my $smtpserver = $Config{'alerting'}{'smtpserver'};
  my @to = split(/\s*,\s*/, $Config{'alerting'}{'emailaddr'});
  my $from = $Config{'alerting'}{'fromaddr'} || 'root@'.$fqdn;
  my $subject = $Config{'alerting'}{'subjectprefix'} . " " . $data{'subject'};
  my $date = POSIX::strftime("%m/%d/%y %H:%M:%S", localtime);
  my $smtp = Net::SMTP->new($smtpserver, Hello => $fqdn );

  if (defined $smtp){
    $smtp->mail($from);
    $smtp->to(@to);
    $smtp->data();
    $smtp->datasend("From: $from\n");
    $smtp->datasend("To: ".join(",",@to)."\n");
    $smtp->datasend("Subject: $subject ($date)\n");
    $smtp->datasend("\n");
    $smtp->datasend($data{'message'});
    $smtp->dataend();
    $smtp->quit;
    $logger->info("email regarding '$subject' sent to ".join(",",@to));
  }else{
    $logger->error("can not connect to SMTP server $smtpserver!");
  }
}

sub isenabled {
  my($enabled) = @_;
  if ($enabled =~ /^\s*(y|yes|true|enable|enabled)\s*$/i) {
    return(1);
  } else {
    return(0);
  }
}

sub isdisabled {
  my($disabled) = @_;
  if ($disabled =~ /^\s*(n|no|false|disable|disabled)\s*$/i) {
    return(1);
  } else {
    return(0);
  }
}

sub getlocalmac {
  my ($dev) = @_;
  return(-1) if (!$dev);
  return($local_mac{$dev}) if (defined $local_mac{$dev});
  foreach (`/sbin/ifconfig -a`){
    return(clean_mac($1)) if (/^$dev.+HWaddr\s+(\w\w:\w\w:\w\w:\w\w:\w\w:\w\w)/i);
  }
  return(0);
}

sub ip2int {
  return(unpack("N",pack("C4",split(/\./,shift))));
}

sub int2ip {
  return(join(".",unpack("C4",pack("N",shift))));
}

sub get_all_internal_ips {
  my @ips;
  foreach my $interface (@internal_nets) {
    my @tmpips = $interface->enumerate();
    pop @tmpips;
    push @ips, @tmpips;
  }
  return(@ips);
}

sub get_internal_nets {
  my @nets;
  foreach my $interface (@internal_nets) {
    push @nets, $interface->desc();
  }
  return(@nets);
}

sub get_routed_isolation_nets {
  my @nets;
  foreach my $interface (@routed_isolation_nets) {
    push @nets, $interface->desc();
  }
  return(@nets);
}

sub get_routed_registration_nets {
  my @nets;
  foreach my $interface (@routed_registration_nets) {
    push @nets, $interface->desc();
  }
  return(@nets);
}

sub get_internal_ips {
  my @ips;
  foreach my $internal (@internal_nets) {
    push @ips, $internal->tag("ip");
  }
  return(@ips);
}

sub get_internal_devs {
  my @devs;
  foreach my $internal (@internal_nets) {
    push @devs, $internal->tag("int");
  }
  return(@devs);
}

sub get_internal_devs_phy {
  my @devs;
  foreach my $internal (@internal_nets) {
    my $dev = $internal->tag("int");
    push (@devs, $dev) if ($dev !~ /:\d+$/);
  }
  return(@devs);
}

sub get_external_devs {
  my @devs;
  foreach my $interface (@external_nets) {
    push @devs, $interface->tag("int");
  }
  return(@devs);
}

sub get_managed_devs {
  my @devs;
  foreach my $interface (@managed_nets) {
    push @devs, $interface->tag("int");
  }
  return(@devs);
}

sub get_internal_macs {
  my @macs;
  my %seen;
  foreach my $internal (@internal_nets) {
   my $mac = getlocalmac($internal->tag("int"));
   push @macs, $mac if ($mac && !defined($seen{$mac}));
   $seen{$mac} = 1;
  }
  return(@macs);
}

sub get_internal_info {
  my ($device) = @_;
  foreach my $interface (@internal_nets) {
    return($interface) if ($interface->tag("int") eq $device);
  }
}

sub get_gateways {
  my @gateways;
  foreach my $interface (@internal_nets) {
    push @gateways, $interface->tag("gw");
  }
  return(@gateways);
}

sub get_dhcp_devs {
  my %dhcp_devices;
  foreach my $dhcp (tied(%Config)->GroupMembers("dhcp")) {
    if (defined($Config{$dhcp}{'device'})) {
      foreach my $dev (split(/\s*,\s*/, $Config{$dhcp}{'device'})) {
        $dhcp_devices{$dev}++;
      }
    }
  }
  return(keys(%dhcp_devices));
}


# return 0 if no interfaces
# otherwie return the number of interfaces
#
sub num_interfaces {
  return (scalar(tied(%Config)->GroupMembers("interface")));
}

sub createpid {
  my ($pname) = @_;
  my $logger = Log::Log4perl::get_logger('pf::util');
  $pname = basename($0) if (!$pname);
  my $pid = $$;
  my $pidfile = $install_dir."/var/$pname.pid";
  $logger->info("$pname starting and writing $pid to $pidfile");
  my $outfile = new FileHandle ">$pidfile";
  if (defined($outfile)) {
     print $outfile $pid;
     $outfile->close;
     return($pid);
  } else {
     $logger->error("$pname: unable to open $pidfile for writing: $!");
     return(-1);
  }
}


sub readpid {
  my ($pname) = @_;
  my $logger = Log::Log4perl::get_logger('pf::util');
  $pname = basename($0) if (!$pname);
  my $pidfile = $install_dir."/var/$pname.pid";
  my $file = new FileHandle "$pidfile";
  if (defined($file)) {
     my $pid = $file->getline() ;
     chomp($pid);
     $file->close;
     return($pid);
  } else {
     $logger->error("$pname: unable to open $pidfile for reading: $!");
     return(-1);
  }
}


sub deletepid {
   my ($pname) = @_;
   $pname = basename($0) if (!$pname);
   my $pidfile = $install_dir."/var/$pname.pid";
   unlink($pidfile) || return(-1);
   return(1);
}

sub parse_template {
  my ($tags, $template, $destination) = @_;
  my $logger = Log::Log4perl::get_logger('pf::util');
  my (@parsed);
  open(TEMPLATE, $template) || $logger->logdie("Unable to open template $template: $!");  
  while (<TEMPLATE>) {
    study $_;
    foreach my $tag (keys %{$tags}) {
      $_ =~ s/%%$tag%%/$tags->{$tag}/ig;
    }
    push @parsed, $_;
  }
  #close(TEMPLATE);
  if ($destination) {
    open(DESTINATION, ">".$destination) || $logger->logdie("Unable to open template destination $destination: $!");
    foreach my $line (@parsed) {
      print DESTINATION $line;
    }
    #close(DESTINATION);
  } else {
    return(@parsed);
  }
}

sub mysql_date {
  return(POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime));
}

sub oui_to_vendor {
  my($mac) = @_;
  my $logger = Log::Log4perl::get_logger('pf::util');
  if (scalar(keys(%${Net::MAC::Vendor::Cached})) == 0) {
    $logger->debug("loading Net::MAC::Vendor cache from $oui_file");
    Net::MAC::Vendor::load_cache("file://$oui_file");
  }
  my $oui_info = Net::MAC::Vendor::lookup($mac);
  return $$oui_info[0] || '';
}

sub preload_getlocalmac {
  my $logger = Log::Log4perl::get_logger('pf::util');
  $logger->info("preloading local mac addresses");
  my %hash;
  my @iflist=`/sbin/ifconfig -a`;
  foreach my $dev (get_internal_devs()) {
    my @line=grep(/^$dev .+HWaddr\s+\w\w:\w\w:\w\w:\w\w:\w\w:\w\w/,@iflist);
    $line[0]=~/^$dev .+HWaddr\s+(\w\w:\w\w:\w\w:\w\w:\w\w:\w\w)/;
    $hash{$dev}=clean_mac($1);
  }
  return (%hash);
}

sub preload_trappable_ip {
  my $logger = Log::Log4perl::get_logger('pf::util');
  $logger->info("preloading trappable_ip hash");
  return(preload_network_range($Config{'trapping'}{'range'}));
}

sub preload_reggable_ip {
  my $logger = Log::Log4perl::get_logger('pf::util');
  $logger->info("preloading reggable_ip hash");
  return(preload_network_range($Config{'registration'}{'range'}));
}

# Generic Preloading Network Range Function
#
sub preload_network_range {
  my ($network_range) = @_;
  my $logger = Log::Log4perl::get_logger('pf::util');
    my $caller = (caller(1))[3] || basename($0);
    $caller =~ s/^pf::\w+:://;

  #print "caller: network range = $network_range\n";
  my %cache_ip;

  foreach my $gateway (get_gateways()) {
    $cache_ip{$gateway} = 0;
  }
  foreach my $intip (get_internal_ips()) {
    $cache_ip{$intip} = 0;
  }
  foreach my $range (split(/\s*,\s*/, $network_range)) {
    if ($range =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}$/) {
      my $block = new Net::Netmask($range);
      if ($block->size()>2){
        $cache_ip{$block->nth(0)} = 0;
        $cache_ip{$block->nth(-1)} = 0;
      }
      foreach my $ip ($block->enumerate()) {
        $cache_ip{$ip} = 1 if (!defined($cache_ip{$ip}));
      }
    } elsif ($range =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})-(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/) {
      my $start = $1;
      my $end   = $2;
      if (!valid_ip($start) || !valid_ip($end)) {
        $logger->error("$range not valid range!");
      } else {
        for (my $i = ip2int($start); $i <= ip2int($end); $i++) {
          $cache_ip{int2ip($i)} = 1;
        }
      }
    } elsif ($range =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3})\.(\d{1,3})-(\d{1,3})$/) {
      my $net   = $1;
      my $start = $2;
      my $end   = $3;
      if (!valid_ip($net.".".$start) || $end < $start || $end > 255) {
        $logger->error("$range not valid range!");
      } else {
        for (my $i = $start; $ i<= $end; $i++) {
          my $ip = $net.".".$i;
          $cache_ip{$ip} = 1 if (!defined($cache_ip{$ip}));
        }
      }
	} elsif ($range =~ /^(?:\d{1,3}\.){3}\d{1,3}$/){
	  $cache_ip{$range} = 1;  
    } else {
      $logger->error("$range not valid!");
    }
  }
  $logger->info(scalar(keys(%cache_ip))." cache_ip entries cached");
  return(%cache_ip);
}

sub preload_is_internal {
  my $logger = Log::Log4perl::get_logger('pf::util');
  my %is_internal;
  $logger->info("preloading is_internal hash");
  foreach my $interface (@internal_nets) {
    foreach my $ip ($interface->enumerate()) {
      $is_internal{$ip} = 1;
    }
  }
  $logger->info(scalar(keys(%is_internal))." is_internal entries cached");
  return(%is_internal);
}

1
