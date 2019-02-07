#!/usr/bin/perl

=head1 NAME

comparator.pl

=head1 SYNOPSIS

comparator.pl <dump_file_1> <dump_file_2>

=head1 DESCRIPTION

Compares two different configuration dumps for differences

No need to use it directly, use addons/pfconfig/comparator/config-comparator.sh

=cut

use strict;
use warnings;

use Sereal::Decoder;
use Test::Deep;

my $DECODER = Sereal::Decoder->new;

my $file1 = $ARGV[0];
my $file2 = $ARGV[1];

my $data1 = read_decode($file1);
my $data2 = read_decode($file2);

###
# We remove the ignored keys here

# stored_config_files was removed
delete $data1->{'pf::config'}->{'\\@pf::config::stored_config_files'};
delete $data2->{'pf::config'}->{'\\@pf::config::stored_config_files'};

# YES an NO were removed
delete $data1->{'pf::config'}->{'$pf::config::NO'};
delete $data2->{'pf::config'}->{'$pf::config::NO'};

delete $data1->{'pf::config'}->{'$pf::config::YES'};
delete $data2->{'pf::config'}->{'$pf::config::YES'};

foreach my $ns (keys %$data1){
  my ($ok, $stack) = Test::Deep::cmp_details($data1->{$ns}, $data2->{$ns});
  if($ok) {
    print "Namespace $ns is the same ! Great success !\n";
  }
  else {
    print "Namespace $ns changed : ".Test::Deep::deep_diag($stack);
  }
}

sub read_decode {
  my ($file) = @_;
  open(my $fh1, "<", $file) 
    or die "cannot open < $file: $!";

  my $data = '';
  while (my $row = <$fh1>) {
    chomp $row;
    $data .=  "$row\n"
  }
  my $decoded_data = $DECODER->decode($data);
  return $decoded_data;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

