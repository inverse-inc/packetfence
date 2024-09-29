package pf::util::system_protocols;

=head1 NAME

pf::util::system_protocols extract data from /etc/protocols

=cut

=head1 DESCRIPTION

Get hash of /etc/protocols

=cut

use strict;
use warnings;
use pf::log;

BEGIN {
  use Exporter ();
  our ( @ISA, @EXPORT );
  @ISA = qw(Exporter);
  @EXPORT = qw(
    is_protocol_available
  );
}

sub system_protocols_hash {
    my $protocols_file = "/etc/protocols";
    open( my $info, "<" , $protocols_file) or die "Not able to open $protocols_file: $!" ;
    my %protocols;
    while( my $line = <$info>)  {
      chomp $line;
      if ( not $line =~ /^#/ ) {
        my @s = split(/\s{1,}/, $line);
	my $prot_name_lower= shift( @s );
	my $prot_id        = shift( @s );
	my $prot_name_upper= shift( @s );
	my $prot_comment   = join( " ", @s );
        if ( defined $prot_name_lower ) {
          my %val = ( 'prot_id' => $prot_id, 'prot_name_upper' => $prot_name_upper , 'prot_comment' => $prot_comment );
          $protocols{ $prot_name_lower } = %val;
        }
      }
    }
    close( $info );
    return \%protocols;
}

sub is_protocol_available {
  my $s = shift;
  my $ls = lc( $s );
  my $available_protocols = system_protocols_hash();
  if ( defined $available_protocols && exists( $available_protocols->{ $ls } ) ) {
    return $s;
  }
  get_logger->error("Protocol $s does not exist.");
  return undef;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
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
