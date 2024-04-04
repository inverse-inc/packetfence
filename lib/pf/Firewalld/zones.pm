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

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        generate_zones_config
    );
}

use pf::log;
use pf::util;
use pf::Firewalld::util;
use pf::config qw(
    $management_network
    %ConfigFirewalld
);
use pf::file_paths qw(
    $firewalld_config_path_generated
    $firewalld_config_path_default_template
    $firewalld_config_path_applied
);

# need a function that return a structured content of the config file
# need a function that is creating the xml file from the config
# need a function that add interfaces in the config file
# need a function that add services according to interface usage (see how lib/pf/iptables.pm is working)
# need a function that return a structured content of the config file

# Generate config
sub generate_zones_config {
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

sub create_zone_config_file {
  my $conf = shift;
  my $name = shift;
  util_prepare_version( $conf );
  util_target( $conf, "zone" ); 
  zone_interface( $conf );
  util_all_sources( $conf );
  util_all_services( $conf );
  util_all_ports( $conf );
  util_all_protocols( $conf );
  util_all_icmp_blocks( $conf );
  util_all_forward_ports( $conf );
  util_all_source_ports( $conf );
  util_all_rules( $conf );
  util_create_config_file( $conf, "zones", $name, "zone" );
}

sub set_zone {
  my $zone = shift;
  if ( util_firewalld_action( "--permanent --zone=$zone --add-interface=$zone" ) ) {
    get_logger->info( "$zone has been applied permanently to $zone" );
  } else {
    get_logger->error( "$zone has NOT been applied to $zone" );
  }
}

# Create Config sub functions
sub zone_interface {
  my $c = shift;
  my $b = 0 ;
  if ( exists( $c->{"interface"} ) ) {
    my $v = $c->{"interface"};
    if ( length( $v ) ) {
      my $all_interfaces = util_listen_ints_hash();
      if ( defined $all_interfaces && not exists( $all_interfaces->{$v} ) ) {
        get_logger->error( "Unknown interface. ==> Apply management interface" );
        $c->{"interface"} = $management_network->{"Tint"};
      }
    }
  }
}

=head1
Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
