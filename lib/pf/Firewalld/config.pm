package pf::Firewalld::config;

=head1 NAME

pf::Firewalld::config

=cut

=head1 DESCRIPTION

Module to get/set basic configuration about firewalld

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
        generate_firewalld_config
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

# Generate config
sub generate_firewalld_config {
  my $conf = $ConfigFirewalld{ "firewalld_config" };
  create_firewalld_config_file( $conf->{"config"} );
}

sub create_firewalld_config_file {
  my $conf = shift ;
  my $file = "$firewalld_config_path_default/firewalld.conf";
  my $file_template = "$firewalld_config_path_default_template/firewalld.conf";
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
