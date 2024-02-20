package pf::Firewalld::util;

=head1 NAME

pf::Firewalld::util

=cut

=head1 DESCRIPTION

Module with utils function for firewalld

=cut

use strict;
use warnings;

use pf::log;
use pf::util;
use pf::config qw(
    @listen_ints
);

my $Config_path_default="/usr/local/pf/firewalld";
my $Config_path_default_template="$Config_path_default/template";
my $Config_path_applied="/usr/local/pf/var/firewalld";

sub get_firewalld_bin {
  my $fbin = `which firewalld`;
  if $fbin =~ "/usr/bin/which: no" {
    get_logger->error("Firewalld has not been found on the system.");
    return undef;
  }
  return $fbin;
}

sub get_firewalld_cmd {
  my $fbin = `which firewalld-cmd`;
  if $fbin =~ "/usr/bin/which: no" {
    get_logger->error("Firewalld has not been found on the system.");
    return undef;
  }
  return $fbin;
}

sub listen_ints_hash {
  my %listen_ints;
  foreach $val ( @listen_ints ) {
    $listen_ints{$val} = 1;
  }
  return %listen_ints;
}

sub source_or_destination_validation {
  my $s = shift;
  my $st = "";
  if ( $s->{"name"} eq "address" && not ( valid_ip_range( $s->{"address"} ) || valid_mac_or_ip( $s->{"address"} ) ) ) {
    $st += "Address is not a valid ip or an ip range. ");
  } elsif ( $s->{"name"} eq "mac" && not valid_mac_or_ip( $s->{"mac"} ) ) {
    $st += "Mac is not a valid mac. ");
  } elsif ( $s->{"name"} eq "ipset" && not is_ipset_available( $s->{"ipset"} ) ) {
    $st += "Ipset is unknown. ");
  }
  return $st;
}

sub util_prepare_version {
  my $c = shift;
  if (exists $c->{"version"} ) {
    my $v = $c->{"version"};
    if ( length $v ) {
      $c->{"version_xml"} = create_string_for_xml("version","$v");
    } else {
      $c->{"version_xml"} = "";
    }
  }
}

sub create_string_for_xml {
  my $t = shift;
  my $v = shift;
  return $t.'="'.$v.'"';
}

sub create_limit_for_xml {
  my $v = shift;
  my $r = create_string_for_xml("value",$v);
  return "<limit ".$r."\>";
}

sub is_fd_protocol {
  my $proto = shift;
  my %protos = qw( tcp 0
                   udp 1
                   sctp 2
                   dccp 3);
  if ( exists $protos{$proto} ){
    return $proto;
  }
  get_logger->error("Protocol ($proto) is an unknown protocol.");
  return undef;
}

sub is_fd_source_name {
  my $name = shift;
  my %names = qw(address 0
                 mac 1
                 ipset 2);
  if ( exists $names{$name} ) {
    return $name;
  }
  get_logger->error("Source $name is unknown.");
  return undef;
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
