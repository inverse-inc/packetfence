package pf::Firewalld::helpers;

=head1 NAME

pf::Firewalld::helpers

=cut

=head1 DESCRIPTION

Module to get/set basic configuration about firewalld helpers

=cut

use strict;
use warnings;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
      generate_helpers_config
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
sub generate_helpers_config {
  my $conf = $ConfigFirewalld{"firewalld_helpers"} ;
  util_prepare_firewalld_config( $conf );
  foreach my $name ( keys %{ $conf } ) {
    my $val = $conf->{ $name };
    if ( exists($val->{"short"} ) ){
      create_helper_config_file( $val, $name );
    }
  }
}

sub create_helper_config_file {
  my $conf = shift ;
  my $name = shift ;
  util_prepare_version( $conf );
  util_all_ports( $conf );
  helper_module ( $conf );
  helper_family ( $conf );
  util_create_config_file( $conf, "helpers", $name, "helper" );
}

# Create Config sub functions
sub helper_module {
  my $conf =  shift;
  my $module = $conf->{"module"};
  $conf->{"module_xml"} = "nf_conntrack_$module";
}

sub helper_family {
  my $conf = shift;
  if ( exists $conf->{"family"} ) {
    my $fam = $conf->{"family"};
    if ( $fam ne "ipv4" && $fam ne "ipv6" ) {
      get_logger->error( "Helper family $fam needs to be ipv4 or ipv6." );
    } else {
      $conf->{"family_xml"} = 'family="'.$fam.'"';
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
