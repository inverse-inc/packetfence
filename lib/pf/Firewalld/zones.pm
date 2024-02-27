package pf::Firewalld::zones;

=head1 NAME

pf::Firewalld::zones

=cut

=head1 DESCRIPTION

Module to get basic configuration about firewalld zone/interface configurations

=cut


use strict;
use warnings;
use File::Copy;
use Template;

use pf::log;
use pf::util;
use pf::Firewalld::util qw(
    util_prepare_version
    util_target
    util_all_sources
    util_all_services
    util_all_ports
    util_all_protocols
    util_all_icmp_blocks
    util_all_forward_ports
    util_all_source_ports
    util_all_rules
    util_prepare_firewalld_config
    util_get_firewalld_bin
    util_get_firewalld_cmd
    util_listen_ints_hash
    util_firewalld_cmd
    util_firewalld_action
);
use pf::config qw(
    $management_network
    %ConfigFirewalld
);
use pf::file_paths qw(
    $firewalld_config_path_default 
    $firewalld_config_path_default_template
    $firewalld_config_path_applied
);

sub firewalld_zones_hash {
  my $std_out = util_firewalld_cmd( "--get-zones" );
  if ( $std_out ne "" ) {
    get_logger->info( "Zones are: $std_out" );
    my @zones = split( / /, $std_out );
    my %h;
    foreach my $val ( @zones ) {
      $h{ $val } = 1;
    }
    return \%h;
  }
  return undef;
}

# need a function that return a structured content of the config file
sub generate_zone_config {
  my $conf = $ConfigFirewalld{"firewalld_zones"};
  util_prepare_firewalld_config( $conf );
  my $all_interfaces = util_listen_ints_hash();
  foreach my $k ( keys %{ $conf } ) {
    if ( defined $all_interfaces && exists( $all_interfaces->{ $k } ) ) {
      if ( length( $k ) <= 17 ) {
        create_zone_config_file( $conf->{ $k }, $k );
	#set_zone( $k );
      } else {
        get_logger->error( "$k can not be bigger than 17 chars" );
      }
    }
  }
}

# need a function that is creating the xml file from the config
# need a function that add interfaces in the config file
sub create_zone_config_file {
  my $conf = shift;
  my $zone = shift;
  util_prepare_version( $conf );
  util_target( $conf ); 
  zone_interface( $conf );
  util_all_sources( $conf );
  util_all_services( $conf );
  util_all_ports( $conf );
  util_all_protocols( $conf );
  util_all_icmp_blocks( $conf );
  util_all_forward_ports( $conf );
  util_all_source_ports( $conf );
  util_all_rules( $conf );
  my $file = "$firewalld_config_path_default/zones/$zone.xml";
  my $file_template = "$firewalld_config_path_default_template/zone.xml";
  if ( -e $file ) {
    my $bk_file = $file.".bk";
    if ( -e $bk_file ) {
      unlink $bk_file or warn "Could not unlink $file: $!";
    }
    copy( $file, $bk_file ) or die "copy failed: $!";
  }
  my $tt = Template->new(
      ABSOLUTE => 1,
  );
  $tt->process( $file_template, $conf, $file ) or die $tt->error();
}

sub set_zone {
  my $zone = shift;
  if ( util_firewalld_action( "--permanent --zone=$zone --add-interface=$zone" ) ) {
    get_logger->info( "$zone has been applied permanently to $zone" );
  } else {
    get_logger->error( "$zone has NOT been applied to $zone" );
  }
}

# need a function that add services according to interface usage (see how lib/pf/iptables.pm is working)
# need a function that return a structured content of the config file
sub zone_interface {
  my $c = shift;
  my $b = 0 ;
  if ( exists( $c->{"interface"} ) ) {
    my $v = $c->{"interface"};
    if ( length( $v ) ) {
      my $all_interfaces = util_listen_ints_hash();
      if ( defined $all_interfaces && not exists( $all_interfaces->{$v} ) ) {
        $b = 1;
      }
    }
  } else {
    $b = 1;
  }
  if ( $b ==1 ){
    get_logger->error( "Unknown interface. ==> Apply management interface" );
    print ( "Unknown interface. ==> Apply management interface" );
    $c->{"interface"} = $management_network->{"Tint"};
  }
}

=head1
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
