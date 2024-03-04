package pf::firewalld;

=head1 NAME

pf::firewalld

=cut

=head1 DESCRIPTION

Interface to get information based on /usr/local/pf/conf/firewalld

=cut

use strict;
use warnings;
use File::Copy;
use Template;

use pf::Firewalld::util;
use pf::Firewalld::config qw ( generate_firewalld_file_config );
use pf::Firewalld::lockdown_whitelist qw ( generate_lockdown_whitelist_config );
use pf::Firewalld::helpers qw ( generate_helpers_config );
use pf::Firewalld::icmptypes qw ( generate_icmptypes_config );
use pf::Firewalld::ipsets qw ( generate_ipsets_config );
use pf::Firewalld::services qw ( generate_services_config );
use pf::Firewalld::zones qw ( generate_zones_config );
use pf::Firewalld::policies qw ( generate_policies_config );

sub generate_firewalld_configs {
  generate_firewalld_file_config();
  generate_lockdown_whitelist_config();
  generate_helpers_config();
  generate_icmptypes_config();
  generate_ipsets_config();
  generate_services_config();
  generate_zones_config();
  generate_policies_config();
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
 
  #$service   ||= "noservice";
  #$status    ||= "add";
  #$zone      ||= "eth0";
  #$permanent ||= "yes";

  if ($service ne "noservice") {
    print("provide a service");
    return 0 ;
  }

  if ( $status ne "add" && $status ne "remove") {
    print("Status $status is unknown. Should be 'add' or 'remove'");
    return 0 ;
  }

  if ( not service_is_in_default( $service ) ) {
    print("Please run generate config to create file services");
    return 0 ;
  }

  if ( $permanent ne "yes" ) {
    $p_value="";
  }

  # handle service's file
  if ( $status eq "add" ){
    service_copy_from_default_to_applied($service);
  } else {
    service_remove_from_applied( $service );
  }

  # handle service in zone
  if ( $status eq "add" ) {
    print("Service $service added from Zone $zone configuration status:");
  } else {
    print("Service $service removed from Zone $zone configuration status:");
  }
  if (firewalld_action("--zone=$zone --$status-service $service $p_value")){
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
