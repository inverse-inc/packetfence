package pf::Firewalld::services;

=head1 NAME

pf::Firewalld::services

=cut

=head1 DESCRIPTION

Module to get/set basic configuration about firewalld services

=cut

use strict;
use warnings;

use Exporter;
use File::Copy;
our ( @ISA, @EXPORT );

use pf::log;
use File::Slurp qw(read_file write_file);
use pf::util;
use pf::IniFiles;
use pf::Firewalld::util;
use Sys::Hostname;
use pf::constants qw($TRUE $FALSE);
use pf::cluster qw($host_id);
use pf::file_paths qw(
    $firewalld_services_config_file
);

sub firewalld_services_hash {
  my $fd_cmd = get_firewalld_cmd();
  if ( $fd_cmd ) {
    my $services = `$fd_cmd --get-services`;
    get_logger->info("Services are: $services");
    my @all_services = split / /, $services;
    my %h;
    foreach $val ( @allservices ) {
      $h{$val}="1"; 
    }
    return %h;
  }
  return undef;
}

sub is_service_available {
  my %s = shift;
  my %available_services = firewalld_services_hash();
  if ( exists $available_services{$s} ) {
    return $s;
  }
  get_logger->error("Service $s does not exist.");
  return undef;
}


# need a function that read the config file and create an xml file related to the service (use of template toolkit)
# need a function that return structured content of the config file
# need a function that check xml file integrity

# Vars
my $config_path_default="$Config_path_default/services";
my $config_path_applied="$Config_path_applied/services";

# Functions
sub service_in_default {
  my $service   = shift;
  if ( -s $config_path_default/$service.xml ) {
    print "Service $service Available in $config_path_default";
    return 1 ;
  } else {
    print "Service $service Unavailable in $config_path_default";
    return 0 ;
  }
}

sub service_is_in_config {
  my $service   = shift;
  if ( -s $config_path_applied/$service.xml ) {
    print "Service $service Available in $config_path_applied";
    return 1 ;
  } else {
    print "Service $service Unavailable in $config_path_applied";
    return 0 ;
  }
}

sub service_is_available {

}

sub service_copy_from_default_to_applied {
  print "Service $service is added in Firewalld applied configuration.\n";
  copy("$config_path_default/$service.xml", "$config_path_applied/$service.xml") or die "copy failed: $!";
}

sub service_remove_from_applied {
  print "Service $service is removed from Firewalld applied configuration.\n";
  unlink "$config_path_applied/$service.xml"
}



sub generate_zone_config {
  my $sconf = $ConfigFirewalld{"firewalld_services"};
  foreach my $k ( keys %{ $sconf } ) {
    create_service_config_file( $zconf->{ $k } );
  }
}

sub create_service_config_file {
  my $conf    = shift ;
  my $service = $conf->{"name"};
  util_prepare_version($conf);
  parse_template( $conf, "$Config_path_default_template/services.xml", "$Config_path_default/zones/$service.xml" );
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
