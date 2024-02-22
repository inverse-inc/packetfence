package pf::Firewalld::icmptypes;

=head1 NAME

pf::Firewalld::icmptypes

=cut

=head1 DESCRIPTION

Module to get/set basic configuration about firewalld servics

=cut

use strict;
use warnings;

use pf::log;
use pf::util;
use pf::Firewalld::util;

sub firewalld_icmptypes_hash {
  my $std_out = util_firewalld_cmd( "--get-icmptypes" );
  if ( $std_out ne "" ) {
    get_logger->info("Icmptypes are: $std_out");
    my @all_c = split( / /, $std_out );
    my %h;
    foreach my $val ( @all_c ) {
      $h{ $val } = 1;
    }
    return \%h;
  }
  return undef;
}

sub is_icmptypes_available {
  my $s = shift;
  my $available_icmptypes = firewalld_icmptypes_hash();
  if ( !undef $available_icmptypes && exists( $available_icmptypes->{$s} ) ) {
    return $s;
  }
  get_logger->error( "Icmp type $s does not exist." );
  return undef;
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
