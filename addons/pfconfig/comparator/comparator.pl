#!/usr/bin/perl

use strict;
use warnings;

use Sereal::Decoder;
use Data::Dumper;
use Test::Deep;

my $DECODER = Sereal::Decoder->new;

my $file1 = $ARGV[0];
my $file2 = $ARGV[1];

my $data1 = read_decode($file1);
my $data2 = read_decode($file2);

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


