#!/usr/bin/perl

use lib '/usr/local/pf/lib';

use Switch;
use pfconfig::manager;

my $cmd = $ARGV[0];

my $manager = pfconfig::manager->new;

switch($cmd) {
  case 'reload' {
    $manager->expire_all(); 
  }  
  case 'list' {
    my @namespaces = $manager->list_namespaces();
    foreach my $namespace (@namespaces){
      print "$namespace\n";
    }
  }
  case 'show' {
    my $namespace = $ARGV[1];
    if(defined($namespace)){
      my @namespaces = $manager->list_namespaces();
      if ( grep {$_ eq $namespace} @namespaces){
        use Data::Dumper;
        print Dumper($manager->get_cache($namespace));
      }
      else{
        print STDERR "ERROR ! Unknown namespace.\n";
        exit;
      }
    }
    else{
      print STDERR "ERROR ! No namespace specified.\n";
      exit;
    }
  }
  case 'get' {
    my $namespace = $ARGV[1];
    if(defined($namespace)){
      use pfconfig::cached;
      use Data::Dumper;
      my $obj = pfconfig::cached->new;
      my $response = $obj->_get_from_socket($namespace, "element");
      print Dumper($response);
    }
    else{
      print STDERR "ERROR ! No namespace specified.\n";
      exit;
    }   
  }
  else {
    print STDERR "ERROR ! Unknown command.\n";
    exit;
  }
};
