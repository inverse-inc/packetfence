package pf::Firewalld::lockdown_whitelist;

=head1 NAME

pf::Firewalld::lockdown_whitelist

=cut

=head1 DESCRIPTION

Module to get/set basic configuration about firewalld lockdown_whitelist

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
        generate_lockdown_whitelist_config
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
sub generate_lockdown_whitelist_config {
  my $conf = $ConfigFirewalld{"firewalld_lockdown_whitelist"} ;
  if ( exists $conf->{"whitelist"} ) {
    util_prepare_firewalld_config_simple( $conf );
    create_lockdown_whitelist_config_file( $conf->{"whitelist"} );
  } else {
    get_logger->info( "No lockdown whitelist configuration");
  }
}

sub create_lockdown_whitelist_config_file {
  my $conf = shift ;
  lockdown_whitelist_all_selinuxs( $conf );
  lockdown_whitelist_all_commands( $conf );
  lockdown_whitelist_all_users( $conf );
  util_create_config_file( $conf, "", "lockdown_whitelist", "lockdown_whitelist" );
}

# Create Config sub functions
sub lockdown_whitelist_all_selinuxs {
  my $conf  = shift;
  if ( exists( $conf->{"selinuxs"} ) ) {
    my @t;
    my $vl = $conf->{"selinuxs"} ;
    foreach my $v ( @{ $vl } ) {
      if ( exists( $v->{"context"} ) ) {
        push( @t, $v );
      } else {
        get_logger->error( "==> Lockdown whitelist selinux needs a context." );
      }
    }
    $conf->{"all_selinuxs"} = \@t;
  }
}

sub lockdown_whitelist_all_commands {
  my $conf  = shift;
  if ( exists( $conf->{"commands"} ) ) {
    my @t;
    my $vl = $conf->{"commands"} ;
    foreach my $v ( @{ $vl } ) {
      if ( exists( $v->{"name"} ) ) {
        push( @t, $v );
      } else {
        get_logger->error( "==> Lockdown whitelist command needs a context." );
      }
    }
    $conf->{"all_commands"} = \@t;
  }
}

sub lockdown_whitelist_all_users {
  my $conf  = shift;
  if ( exists( $conf->{"users"} ) ) {
    my @t;
    my $vl = $conf->{"users"} ;
    foreach my $v ( @{ $vl } ) {
      if ( exists( $v->{"id"} ) || exists( $v->{"name"} ) ) {
        push( @t, $v );
      } else {
        get_logger->error( "==> Lockdown whitelist user needs a name or an id." );
      }
    }
    $conf->{"all_users"} = \@t;
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
