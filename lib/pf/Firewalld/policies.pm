package pf::Firewalld::policies;

=head1 NAME

pf::Firewalld::policies

=cut

=head1 DESCRIPTION

Module to get basic configuration about firewalld policies configurations

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
        generate_policies_config
    );
}

use pf::log;
use pf::util;
use pf::Firewalld::util;
use pf::util::system_protocols;
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
# need a function that return a structured content of the config file

# Generate config
sub generate_policies_config {
  my $conf = $ConfigFirewalld{ "firewalld_policies" };
  util_prepare_firewalld_config( $conf );
  foreach my $name ( keys %{ $conf } ) {
    my $val = $conf->{ $name };
    if ( exists( $val->{"short"} ) ){
      if ( length( $name ) <= 17 ){
        create_policy_config_file( $val, $name );
        #apply_policy( $val->{"priority"}, $name );
      } else {
        get_logger->error( "$name can not be bigger than 17 chars" );
      }
    }
  }
}

sub create_policy_config_file {
  my $conf = shift;
  my $name = shift;
  util_prepare_version( $conf );
  util_target( $conf ); 
  util_prepare_priority( $conf );
  policy_ingress( $conf ); 
  policy_egress( $conf ); 
  util_all_sources( $conf );
  util_all_services( $conf );
  util_all_ports( $conf );
  util_all_protocols( $conf );
  util_all_icmp_blocks( $conf );
  util_all_forward_ports( $conf );
  util_all_source_ports( $conf );
  util_all_rules( $conf );
  util_create_config_file( $conf, "policies", $name, "policy" );
}

sub apply_policy {
  my $priority = shift;
  my $name = shift;
  my $set_priority = "";
  if ( defined $priority ){
    $set_priority = "--set-proprity $priority";
  }
  if ( util_firewalld_action( "--permanent --policy $name $set_priority" ) ) {
    if ( $set_priority ne "" ) {
      $set_priority = "with the priority $priority";
    }
    get_logger->info( "Policy named $name has been applied permanently $set_priority" );
  } else {
    get_logger->error( "Policy named $name has NOT been applied." );
  }
}

# Create Config sub functions
sub policy_egress {
  my $c = shift;
  my $b = 0 ;
  if ( exists $c->{"egress_policies"} ) {
    my @t;
    my $vl = $c->{"egress_policies"};
    my $zones_hash;
    $zones_hash = firewalld_zones_hash();
    $zones_hash->{"ANY"} = 1;
    $zones_hash->{"HOST"} = 1;
    foreach my $v ( @{ $vl } ) {
      if ( exists( $zones_hash->{ $v->{"name"} } ) ) {
        get_logger->info( "Egress policy ($v->{'name'}) is added" );
        push( @t, $v );
      } else {
        get_logger->error( "Egress Policy ($v->{'name'}) does not exist." );
      }
    }
    $c->{"all_egress_policies"} = \@t;
  }
}

sub policy_ingress {
  my $c = shift;
  my $b = 0;
  if ( exists $c->{"ingress_policies"} ) {
    my @t;
    my $vl = $c->{"ingress_policies"};
    my $zones_hash;
    $zones_hash = firewalld_zones_hash();
    $zones_hash->{"ANY"} = 1;
    $zones_hash->{"HOST"} = 1;
    foreach my $v ( @{ $vl } ) {
      if ( exists( $zones_hash->{ $v->{"name"} } ) ) {
        get_logger->info( "Ingress policy ($v->{'name'}) is added" );
        push( @t, $v );
      } else {
        get_logger->error( "Ingress Policy ($v->{'name'}) does not exist." );
      }
    }
    $c->{"all_ingress_policies"} = \@t;
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
