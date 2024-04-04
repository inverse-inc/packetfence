package pf::Firewalld::icmptypes;

=head1 NAME

pf::Firewalld::icmptypes

=cut

=head1 DESCRIPTION

Module to get/set basic configuration about firewalld icmptypes

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
        generate_icmptypes_config
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

# Generate config
sub generate_icmptypes_config {
  my $conf = $ConfigFirewalld{ "firewalld_icmptypes" };
  util_prepare_firewalld_config( $conf );
  foreach my $name ( keys %{ $conf } ) {
    my $v = $conf->{ $name };
    if ( exists( $v->{"short"} ) ){
      create_icmptype_config_file( $v, $name );
    }
  }
}

sub create_icmptype_config_file {
  my $conf = shift ;
  my $name = shift ;
  util_prepare_version( $conf );
  icmptype_all_destinations( $conf );
  util_create_config_file( $conf, "icmptypes", $name, "icmptype" );
}

# Create Config sub functions
sub icmptype_all_destinations {
  my $conf = shift;
  if ( exists $conf->{"destinations"} ) {
    my @all_destinations;
    my $destinations = $conf->{"destinations"};
    if ( $destinations ne "" ) {
      my @all_dest = split( /,/, $destinations );
      foreach my $dest ( @all_dest ) {
        my ($key, $val ) = split( /:/, $dest );
        if ( $key eq "ipv4" || $key eq "ipv6" ) {
          if ( $val eq "no" || $val eq "yes" ) {
            my $xml_dest = $key.'="'.$val.'"';
            push( @all_destinations, $xml_dest );
          } else {
            get_logger->error( "Icmptype destination needs to be yes or no." );
          }
        } else {
          get_logger->error( "Icmptype destination needs to be ipv4 or ipv6." );
        }
      }
      $conf->{"all_destinations"} = \@all_destinations;
    } else {
      get_logger->error( "Icmptype destination is empty." );
    }
  }
}

=head1 AUTHOR

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
