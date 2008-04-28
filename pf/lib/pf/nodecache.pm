#
# $Id: nodecache.pm,v 1.2 2005/11/17 21:34:56 dgehl Exp $
#
# Copyright 2005 David LaPorte <david@davidlaporte.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

package pf::nodecache;

use strict;
use warnings;
use File::Basename;
use Sys::Syslog;

BEGIN {
  use Exporter ();
  our (@ISA, @EXPORT);
  @ISA    = qw(Exporter);
  @EXPORT = qw();
}

use lib qw(/usr/local/pf/lib);
use pf::config;
use pf::util;
use pf::iplog;
use pf::node;

sub new {
   my ($class) = @_;
   my $self;
   
   # set the hashes shared
   my %ip2mac : shared;
   my %mac2ip : shared;
   my %gwtime : shared;
   my %arptime : shared;
   my %dhcptime : shared;   

   # use refs...
   $self->{ipmac}= \%ip2mac;
   $self->{macip}= \%mac2ip;
   $self->{arptime} = \%arptime;
   $self->{gwtime} = \%gwtime;
   $self->{dhcptime} = \%dhcptime;
   bless $self, $class;
   return $self;
}

sub new_node {
   my ($self, $mac, $ip, $lease_length) = @_;
   $self->set_mac($mac,$ip);
   $self->set_ip($mac,$ip);
   $self->set_arptime($mac);
   iplog_open($mac,$ip,$lease_length);
   node_update_lastarp($mac); 
}

sub delete_node {
   my ($self, $mac) = @_;
   delete $self->{arptime}->{$mac};
   delete $self->{gwtime}->{$mac};
   delete $self->{dhcptime}->{$mac};
   return 1 if ($self->is_gateway($mac));
   my @ips=$self->get_ips($mac);
   foreach my $ip (@ips){
     delete $self->{ipmac}->{$ip};
     iplog_close($ip);
     pflogger("node $mac ($ip) session closed",8);
   }
   delete $self->{macip}->{$mac};
}  

sub mac_exist {
  my ($self, $mac) = @_;
  return 1 if (defined $self->{macip}->{$mac});
  return 0;
}

sub ip_exist {
  my ($self, $ip) = @_;
  return 1 if (defined $self->{ipmac}->{$ip});
  return 0;
}

# set_mac: mac * $ip -> none
sub set_mac {
  my ($self, $mac, $ip) = @_;
  $self->{ipmac}->{$ip}=$mac;  
}

#
# get_mac: ip -> mac
sub get_mac {
  my ($self, $ip) = @_;
  #return $self->{ipmac}->{$ip};  
  return $self->{ipmac}->{$ip} if (defined $self->{ipmac}->{$ip});
  return 0;  
}

# return all macs
# get_mac:  none -> @mac
sub get_all_macs {
  my ($self) = @_;
  return (keys %{$self->{macip}});  
}

sub get_used_ips {
  my ($self) = @_;
  my @ips;
  foreach my $mac ($self->get_all_macs()) {
    push @ips, $self->get_ips($mac);
  }
  return @ips;
}

sub get_unused_ips {
  my ($self) = @_;
  my @used_ips = $self->get_used_ips();
  my @unused_ips;
  foreach my $ip (get_all_internal_ips()) {
    push(@unused_ips, $ip) if (scalar(grep(/^$ip$/,@used_ips)) == 0);
  }
  return @unused_ips;
}

# get first ip associated with a mac
# get_ip: mac -> ip
sub get_ip {
  my ($self, $mac) = @_;
  return $self->{macip}->{$mac}[0] if (defined $self->{macip}->{$mac});
  return 0;
}

#
# all ips associated with a mac
sub get_ips {
  my ($self, $mac) = @_;
  return @{$self->{macip}->{$mac}} if (defined $self->{macip}->{$mac});
  return ();
}

#
# num_ip: mac -> @ips
sub num_ip {
  my ($self, $mac) = @_;
  return 0 if (!$mac || !defined $self->{macip}->{$mac});
  return scalar(@{$self->{macip}->{$mac}});
}

#
#
sub set_ip {
  my ($self, $mac, $ip) = @_;
  if (defined $self->{macip}->{$mac}){
   @{$self->{macip}->{$mac}}=($ip);
  }else{
   lock ($self->{macip});
   # we need to do a ref to an array because
   #perl doesn't support shared hash{key}=array
   #  but it does support shared hash{key}=ref
   #
   my @iparray : shared = ($ip);
   $self->{macip}->{$mac}=\@iparray;
  }
}

sub add_ip {
  my ($self,$mac,$ip,$lease_length)= @_;
  return (1) if (grep(/^$ip$/,@{$self->{macip}->{$mac}})); 
  if (defined $self->{macip}->{$mac}){
    push @{$self->{macip}->{$mac}},$ip;
  }else{
   $self->setip($mac,$ip);
  }
 $self->set_mac($mac,$ip);
 $self->set_arptime($mac);
 iplog_open($mac,$ip,$lease_length);
 node_update_lastarp($mac); 
}

sub delete_ip {
 my ($self,$mac,$ip)= @_;
 my @newarray : shared;
 my $num = $self->num_ip($mac);
 for (my $i = 0; $i < $num; $i++){
   if ($self->{macip}->{$mac}[$i] ne $ip){
      push @newarray, $self->{macip}->{$mac}[$i]
   }else{
      #print "Deleting IP = $ip\n";
   }
 }
 my $oldref=$self->{macip}->{$mac};
 $self->{macip}->{$mac}= \@newarray;
 #maybe delete oldref? 
}

sub set_arptime {
  my ($self,$mac)= @_;
  $self->{arptime}->{$mac}=time() if ($self->mac_exist($mac));
}

sub get_arptime {
  my ($self,$mac)= @_;
  return -1 if (!defined $self->{arptime}->{$mac} || $self->{arptime}->{$mac} == 0);
  return time()-$self->{arptime}->{$mac};
}

sub set_gwtime {
  my ($self,$mac)= @_;
  $self->{gwtime}->{$mac}=time() if ($self->mac_exist($mac));
}

sub get_gwtime {
  my ($self,$mac)= @_;
  return -1 if (!defined $self->{gwtime}->{$mac} || $self->{gwtime}->{$mac} == 0);
  return time()-$self->{gwtime}->{$mac};
}

sub set_dhcptime {
  my ($self,$mac)= @_;
  $self->{dhcptime}->{$mac}=time() if ($self->mac_exist($mac));
}

sub get_dhcptime {
  my ($self,$mac)= @_;
  return -1 if (!defined $self->{dhcptime}->{$mac} || $self->{dhcptime}->{$mac} == 0);
  return time()-$self->{dhcptime}->{$mac};
}


sub arp_expired {
 my ($self,$mac)= @_;
 if ($self->get_arptime($mac) > $Config{'arp'}{'timeout'}){
   return 1;
 }
 return 0;
}

sub gw_expired {
 my ($self,$mac)= @_;
 if ($self->get_gwtime($mac) > $Config{'arp'}{'gw_timeout'}){
   return 1;
 }
 return 0;
}

sub dhcp_expired {
 my ($self,$mac)= @_;
 if ($self->get_dhcptime($mac) > $Config{'arp'}{'dhcp_timeout'}){
   return 1;
 }
 return 0;
}
   
   
sub is_gateway {
  my $self = shift;
  my $mac = shift;

  my @ips = $self->get_ips($mac);
  foreach my $interface (@internal_nets) {
    foreach my $ip (@ips) {
      return(1) if ($ip eq $interface->tag("gw"));
    }
  }
  return(0);
}

#
# please test me!!!
#
sub delete_expired {
   my $self = shift;
   my $timeout = shift;
   #my @gateways= @_;
   my @gateways = get_gateways();
   #
   # delete expired nodes
   #
   foreach my $mac ($self->get_all_macs){
     my $d=$self->get_dhcptime($mac);
     my $a=$self->get_arptime($mac);
     my $g=$self->get_gwtime($mac);
     my $ip=$self->get_ip($mac);
     pflogger("$mac ($ip) Timer check ($a,$g,$d)",16);
     if ($self->is_gateway($mac)){
       pflogger("skipping gateway $mac ($ip)",16);
       next;
     }

     if ($self->arp_expired($mac,$timeout)){
       my $time=$self->get_arptime($mac);
       pflogger("arp timer exceeded for $mac ($ip) [$time] - closing session ",4);
       $self->delete_node($mac);
     } elsif ($self->gw_expired($mac)) {
       pflogger("gateway timer exceeded for $mac ($ip) - probable static gateway arp entry",4);
       $self->set_gwtime($mac);
     } elsif ($self->dhcp_expired($mac)) {
       pflogger("DHCP timer exceeded for $mac ($ip) - probable static IP ",4);
       $self->set_dhcptime($mac);
     }
   }
}

# hello_macs: timeout -> @macs_to_hello
#
# please test me...
#
sub hello_macs {
   my ($self,$timeout,$interval)= @_;
   my @macs;
   
   foreach my $mac ($self->get_all_macs){
    my $age=$self->get_arptime($mac);  
    if ( ($age > ($timeout / 2) && $age < ($timeout / 2 + ($interval * 2 - 1)))  ||
                ($timeout - $age < ($interval * 2 - 1)) ) {
        push @macs,$mac;
        my $ip=$self->get_ip($mac);
        pflogger("$mac ($ip) hasn't checked in, in more then $timeout / 2 going to say hello [$age]",8);
     }
   }
   return(@macs);
}






1
