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
use pf::Firewalld::ipsets;


my $Config_path_default="/usr/local/pf/firewalld";
my $Config_path_default_template="$Config_path_default/template";
my $Config_path_applied="/usr/local/pf/var/firewalld";

sub util_prepare_firewalld_config {
  my $conf = shift;
  foreach my $k ( keys %{ $zconf } ){
    my $val = $conf->{$k};
    foreach my $k2 ( keys %{ $val } ){
      my @vals = split ( ",", $val->{$k2} );
      my @nvals;
      foreach my $v ( @vals ){
        if ( exists ( $conf->{$v} ) ){
          push( @nvals, $conf->{$k} );
        }
      }
      if ( @nvals ){
        $val->{$k2} = \@nvals;
      }
    }
  }
}

sub util_get_firewalld_bin {
  my $fbin = `which firewalld`;
  if ( $fbin =~ "/usr/bin/which: no" ){
    get_logger->error( "Firewalld has not been found on the system." );
    return undef;
  }
  return $fbin;
}

sub util_get_firewalld_cmd {
  my $fbin = `which firewalld-cmd`;
  if ( $fbin =~ "/usr/bin/which: no" ){
    get_logger->error( "Firewalld has not been found on the system." );
    return undef;
  }
  return $fbin;
}

sub util_listen_ints_hash {
  my %listen_ints;
  foreach $val ( @listen_ints ) {
    $listen_ints{$val} = 1;
  }
  return \%listen_ints;
}

sub util_source_or_destination_validation {
  my $s = shift;
  my $st = "";
  if ( $s->{"name"} eq "address" && not ( valid_ip_range( $s->{"address"} ) || valid_mac_or_ip( $s->{"address"} ) ) ){
    $st += "Address is not a valid ip or an ip range. ");
  } elsif ( $s->{"name"} eq "mac" && not valid_mac_or_ip( $s->{"mac"} ) ){
    $st += "Mac is not a valid mac. ");
  } elsif ( $s->{"name"} eq "ipset" && not is_ipset_available( $s->{"ipset"} ) ){
    $st += "Ipset is unknown. ");
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
  if ( exists $protos{$proto} ){
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
  my $firewalld_cmd = get_firewalld_cmd();
  if ( $firewalld_cmd ){
    my $std_out = `$firewalld_cmd $action`;
    my $exit_status = `echo "$?"`;
    if ($exit_status eq "0") {
      get_logger->info( "Command exit with success" );
      return $std_out;
    } else {
      get_logger->error( "Command exit without success" );
    }
  }
  return "";
}

# Firewalld action
sub util_firewalld_action {
  my $action= shift;
  my $result = util_firewalld_cmd( $action );
  if ( $result eq "success" ){
    return 1;
  } else {
    return 0;
  }
}

# need a function that reload the service
sub util_reload_firewalld {
  if ( firewalld_action( "--reload" ) ){
    get_logger->info( "Reload Success" );
    return 1;
  } else {
    get_logger->error( "Reload Failed" );
    return 0;
  }
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
