package pf::firewalld;

=head1 NAME

pf::firewalld

=cut

=head1 DESCRIPTION

Interface to get information based on /usr/local/pf/conf/firewalld

=cut

use strict;
use warnings;

use pf::firewalld::services;
use File::Copy;

my $path_bin=`which firewalld-cmd`;
my $path_services_default=`which firewalld-cmd`;
my $config_path_default="/usr/local/pf/firewalld/services";
my $config_path_applied="/usr/local/pf/var/firewalld/services";

# Firewalld action
sub firewalld_action {
  my $action= shift;
  my $result=`$path_bin $action`;
  if ($result eq "success") {
    return 1;
  } else {
    return 0;
  }
}

# need a function that reload the service
sub reload_firewalld {
  if (firewalld_action("--reload")) {
    print "Reload Success";
    return 1;
  } else {
    print "Reload Failed";
    return 0;
  }
}

# need a function that return information like a wrapper of firewalld-cmd
# need a function that return services from a zone
# need a function that check integrity for zones and services

# need a function that add/remove a service into/from a zone
sub service_to_zone {
  my $service   = shift;
  my $status    = shift;
  my $zone      = shift;
  my $permanent = shift;
  my $p_value   = "--permanent";

  $service   ||= "noservice";
  $status    ||= "add";
  $zone      ||= "eth0";
  $permanent ||= "yes";

  if ($service ne "noservice") {
    print "provide a service"
    return 0 ;
  }

  if ( $status ne "add" && $status ne "remove") {
    print "Status $status is unknown. Should be 'add' or 'remove'";
    return 0 ;
  }

  if ! ( service_is_in_default($service) ) {
    print "Please run generate config to create file services";
    return 0 ;
  }

  if ($permanent ne "yes") {
    $p_value="";
  }

  # handle service's file
  if ( $status eq "add" ){
    service_copy_from_default_to_applied($service);
  } else {
    service_remove_from_applied($service};
  }

  # handle service in zone
  if ( $status eq "add" ) {
    print "Service $service added from Zone $zone configuration status:"
  } else {
    print "Service $service removed from Zone $zone configuration status:"
  }
  if (firewalld_action("--zone=$zone --$status-service $service $permanent_val")){
    return reload_firewalld();
  } else {
    return 1 ;
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
