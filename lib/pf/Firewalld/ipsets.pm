package pf::Firewalld::ipsets;

=head1 NAME

pf::Firewalld::ipsets

=cut

=head1 DESCRIPTION

Module to get/set basic configuration about firewalld ipsets

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
        generate_ipsets_config
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
sub generate_ipsets_config {
  my $conf = $ConfigFirewalld{ "firewalld_ipsets" };
  util_prepare_firewalld_config( $conf );
  foreach my $name ( keys %{ $conf } ) {
    my $v = $conf->{ $name };
    if ( exists( $v->{"short"} ) ){
      create_ipset_config_file( $v, $name );
    }
  }
}

sub create_ipset_config_file {
  my $conf = shift ;
  my $name = shift ;
  if ( defined is_ipset_type_available( $conf->{"type"} ) ) {
    util_prepare_version( $conf );
    util_create_config_file( $conf, "ipsets", $name, "ipset" );
  } else {
    get_logger->error( "Ipset $name is not installed. Ipset type is invalid." );
  }
}

# Create Config sub functions

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
