package pf::Firewalld::ipsets;

=head1 NAME

pf::Firewalld::ipsets

=cut

=head1 DESCRIPTION

Module to get/set basic configuration about firewalld ipsets

=cut

use strict;
use warnings;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        is_ipset_type_available
        is_ipset_available
        generate_ipset_config
        create_service_config_file
    );
}

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

# Utils
sub firewalld_ipset_types_hash {
  my $std_out = util_firewalld_cmd( "--get-ipset-types" );
  if ( $std_out ne "" ) {
    get_logger->info( "Ipset types are: $std_out" );
    my @all_c = split( / /, $std_out );
    my %h;
    foreach my $val ( @all_c ) {
      $h{ $val } = 1;
    }
    return \%h;
  }
  return undef;
}

sub is_ipset_type_available {
  my $s = shift;
  my $available_ipset_types = firewalld_ipset_types_hash();
  if ( !undef $available_ipset_types &&  exists( $available_ipset_types->{ $s } ) ) {
    return $s;
  }
  get_logger->error( "Ipset type $s does not exist." );
  return undef;
}

sub firewalld_ipsets_hash {
  my $std_out = util_firewalld_cmd( "--get-ipsets" );
  if ( $std_out ne "" ) {
    get_logger->info( "Ipsets are: $std_out" );
    my @all_c = split( / /, $std_out );
    my %h;
    foreach my $val ( @all_c ) {
      $h{ $val } = 1;
    }
    return \%h;
  }
  return undef;
}

sub is_ipset_available {
  my $s = shift;
  my $available_ipsets = firewalld_ipsets_hash();
  if ( !undef $available_ipsets && exists( $available_ipsets->{$s} ) ) {
    return $s;
  }
  get_logger->error("Ipsets $s does not exist.");
  return undef;
}

# Generate config
sub generate_ipset_config {
  my $conf = prepare_config( $ConfigFirewalld{"firewalld_ipsets"} );
  foreach my $k ( keys %{ $conf } ) {
    my $ipset = $conf->{ $k };
    if ( exists( $ipset->{"type"} ) ){
      create_service_config_file( $ipset );
    }
  }
}

sub create_service_config_file {
  my $conf = shift ;
  if ( defined is_ipset_type_available( $conf->{"type"} ) ) {
    my $ipset = $conf->{"name"};
    util_prepare_version( $conf );
    parse_template( $conf, "$firewalld_config_path_default_template/ipset.xml", "$firewalld_config_path_default/ipsets/$ipset.xml" );
  } else {
    get_logger->error( "Ipset $conf->{'name'} is not installed. Ipset type is invalid." );
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
