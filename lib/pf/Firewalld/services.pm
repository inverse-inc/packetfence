package pf::Firewalld::services;

=head1 NAME

pf::Firewalld::services

=cut

=head1 DESCRIPTION

Module to get/set basic configuration about firewalld services

=cut

use strict;
use warnings;

use pf::log;
use pf::util;
use pf::Firewalld::util qw(
    util_prepare_firewalld_config
    util_get_firewalld_bin
    util_get_firewalld_cmd
    util_listen_ints_hash
    util_source_or_destination_validation
    util_prepare_version
    util_create_string_for_xml
    util_create_limit_for_xml
    util_is_firewalld_protocol
    util_is_fd_source_name
    util_firewalld_cmd
    util_firewalld_action
    util_reload_firewalld
);
use pf::config qw(
    %ConfigFirewalld
);
use pf::file_paths qw(
    $firewalld_config_path_default 
    $firewalld_config_path_default_template
    $firewalld_config_path_applied
);

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


# Vars
my $service_config_path_default="$firewalld_config_path_default/services";
my $service_config_path_applied="$firewalld_config_path_applied/services";

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
  } else {
    get_logger->info( "No Service available" );
  }
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
  my $conf = util_prepare_firewalld_config( $ConfigFirewalld{"firewalld_services"} );
  foreach my $k ( keys %{ $conf } ) {
    my $service = $conf->{ $k };
    if ( exists( $service->{"name"} ) ){
      create_service_config_file( $service );
    }
  }
}

sub create_service_config_file {
  my $conf    = shift ;
  my $service = $conf->{"name"};
  util_prepare_version( $conf );
  my $file = "$firewalld_config_path_default/services/$service.xml";
  my $file_template = "$firewalld_config_path_default_template/service.xml";
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
