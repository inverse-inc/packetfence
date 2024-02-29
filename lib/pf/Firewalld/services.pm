package pf::Firewalld::services;

=head1 NAME

pf::Firewalld::services

=cut

=head1 DESCRIPTION

Module to get/set basic configuration about firewalld services

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
        firewalld_services_hash
        is_service_available
        service_in_default
        service_is_in_config
        service_copy_from_default_to_applied
        service_remove_from_applied
        generate_service_config
        create_service_config_file
    );
}

use pf::log;
use pf::util;
use pf::Firewalld::util;
use pf::config qw(
    %ConfigFirewalld
);
use pf::file_paths qw(
    $firewalld_config_path_generated
    $firewalld_config_path_default_template
    $firewalld_config_path_applied
);

# Vars
my $service_config_path_default="$firewalld_config_path_generated/services";
my $service_config_path_applied="$firewalld_config_path_applied/services";

sub service_all_includes {
  my $c = shift;
  if ( exists( $c->{"includes"} ) ) {
    my @t;
    my @vl = split( ',', $c->{"includes"} );
    foreach my $k ( @vl ) {
      if ( defined is_service_available( $k ) ) {
        push( @t, $k );
      } else {
        get_logger->error( "==> Include ($k) is removed." );
      }
    }
    $c->{"all_includes"} = \@t;
  }
}

sub service_all_destinations {
  my $conf = shift;
  if ( exists $conf->{"destinations"} ) {
    my @all_destinations;
    my $destinations = $conf->{"destinations"};
    if ( $destinations ne "" ) {
      my @all_dest = split( /,/, $destinations );
      foreach my $dest ( @all_dest ) {
        my ($key, $val ) = split( /:/, $dest );
        if ( $key eq "ipv4" || $key eq "ipv6" ) {
          if ( valid_ip_range( $val ) ) {
            my $xml_dest = $key.'="'.$val.'"';
            push( @all_destinations, $xml_dest );
          } else {
            get_logger->error( "Service destination needs to be a valid ipv4 or ipv6 address with or without mask." );
          }
        } else {
          get_logger->error( "Service destination needs to be ipv4 or ipv6." );
        }
      }
      if ( scalar(@all_destinations) > 0 ) {
        my $all_destinations_joined = join( " ", @all_destinations );
        $conf->{"all_destinations"} = \$all_destinations_joined;
      }
    } else {
      get_logger->error( "Service destination is empty." );
    }
  }
}


# Functions
sub firewalld_services_hash {
  my $std_out = util_firewalld_cmd( "--get-services" );
  if ( $std_out ne "" ) {
    get_logger->info( "Services are: $std_out" );
    my @services = split( / /, $std_out );
    my %h;
    foreach my $val ( @services ) {
      $h{ $val } = 1;
    }
    return \%h;
  }
  my $xml_files = util_get_xml_files_from_dir("services");
  if ( defined $xml_files ) {
    return $xml_files;
  }
  get_logger->error( "No Service available" );
  return undef;
}

sub is_service_available {
  my $s = shift;
  my $available_services = firewalld_services_hash();
  if ( exists $available_services->{ $s } ) {
    return $s;
  }
  get_logger->error( "Service $s does not exist." );
  return undef;
}

sub service_in_default {
  my $service = shift;
  if ( -s "$service_config_path_default/$service.xml" ) {
    get_logger->info( "Service $service Available in $service_config_path_default" );
    return 1 ;
  } else {
    get_logger->error( "Service $service Unavailable in $service_config_path_default" );
    return 0 ;
  }
}

sub service_is_in_config {
  my $service = shift;
  if ( -s "$service_config_path_applied/$service.xml" ) {
    get_logger->info( "Service $service Available in $service_config_path_applied" );
    return 1 ;
  } else {
    get_logger->error( "Service $service Unavailable in $service_config_path_applied" );
    return 0 ;
  }
}

sub service_copy_from_default_to_applied {
  my $service = shift;
  get_logger->info( "Service $service is added in Firewalld applied configuration.\n" );
  copy( "$service_config_path_default/$service.xml", "$service_config_path_applied/$service.xml" ) or die "copy failed: $!";
}

sub service_remove_from_applied {
  my $service = shift;
  get_logger->info( "Service $service is removed from Firewalld applied configuration.\n" );
  unlink( "$service_config_path_applied/$service.xml" );
}


# Generate config
sub generate_service_config {
  my $conf = $ConfigFirewalld{"firewalld_services"};
  util_prepare_firewalld_config( $conf );
  foreach my $k ( keys %{ $conf } ) {
    my $val = $conf->{ $k };
    if ( exists( $val->{"short"} ) ){
      create_service_config_file( $val, $k);
    }
  }
}

sub create_service_config_file {
  my $conf = shift ;
  my $name = shift ;
  util_prepare_version( $conf );
  util_all_ports( $conf );
  util_all_helpers( $conf );
  service_all_destinations( $conf );
  service_all_includes( $conf );
  util_create_config_file( $conf , "services", $name, "service" );
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
