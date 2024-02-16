package pf::firewalld::ipsets;

=head1 NAME

pf::firewalld::ipsets

=cut

=head1 DESCRIPTION

Module to get/set basic configuration about firewalld ipsets

=cut

use strict;
use warnings;

use Exporter;
use File::Copy;
our ( @ISA, @EXPORT );

use pf::log;
use File::Slurp qw(read_file write_file);
use pf::util;
use pf::IniFiles;
use Sys::Hostname;
use pf::constants qw($TRUE $FALSE);
use pf::cluster qw($host_id);
use pf::file_paths qw(
    $firewalld_services_config_file
);
use pf::firewalld::util;

sub firewalld_ipsets_hash {
  my $fd_cmd = get_firewalld_cmd();
  if ( $fd_cmd ) {
    my $c = `$fb_cmd --get-ipset-types`;
    get_logger->info("Ipsets are: $c");
    my @cs = split(/ /, $c);
    my %h;
    foreach $val ( @cs ) {
      $h{$val}="1"; 
    }
    return %h;
  }
  return undef;
}

sub is_ipset_available {
  my $s = shift;
  my %available_ipsets = firewalld_ipsets_hash();
  if ( exists $available_ipsets{$s} ) {
    return $s;
  }
  get_logger->error("Ipsets $s does not exist.");
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
