package pf::Firewalld::helpers;

=head1 NAME

pf::Firewalld::helpers

=cut

=head1 DESCRIPTION

Module to get/set basic configuration about firewalld helpers

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
        is_helper_available
        generate_helper_config
        create_helper_config_file
    );
}

use pf::log;
use pf::util;
use pf::Firewalld::util qw(
    util_prepare_firewalld_config
    util_prepare_version
    util_firewalld_cmd
    util_all_ports
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
sub firewalld_helpers_hash {
  my $std_out = util_firewalld_cmd( "--get-helpers" );
  if ( $std_out ne "" ) {
    get_logger->info( "Helpers are: $std_out" );
    my @all_c = split( / /, $std_out );
    my %h;
    foreach my $val ( @all_c ) {
      $h{ $val } = 1;
    }
    return \%h;
  }
  return undef;
}

sub is_helper_available {
  my $s = shift;
  my $available_helpers = firewalld_helpers_hash();
  if ( !undef $available_helpers &&  exists( $available_helpers->{ $s } ) ) {
    return $s;
  }
  get_logger->error( "Helper $s does not exist." );
  return undef;
}

sub helper_module {
  my $conf =  shift;
  my $module = $conf->{"module"};
  $conf->{"module_xml"} = "nf_conntrack_$module";
}

sub helper_family {
  my $conf = shift;
  if ( exists $conf->{"family"} ) {
    my $fam = $conf->{"family"};
    if ( $fam ne "ipv4" || $fam ne "ipv6" ) {
      get_logger->error( "Helper family $fam needs to be ipv4 or ipv6." );
    } else {
      $conf->{"family_xml"} = 'family="'.$fam.'"';
    }
  }
}

# Generate config
sub generate_helper_config {
  my $conf = $ConfigFirewalld{"firewalld_helpers"} ;
  util_prepare_firewalld_config( $conf );
  foreach my $name ( keys %{ $conf } ) {
    my $val = $conf->{ $name };
    if ( exists($val->{"module"} ) ){
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
  my $file = "$firewalld_config_path_default/helpers/$name.xml";
  my $file_template = "$firewalld_config_path_default_template/helper.xml";
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
