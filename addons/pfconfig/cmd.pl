#!/usr/bin/perl

=head1 NAME

Basic command line to interact with pfconfig

=head1 SYNOPSIS

cmd.pl reload|list|show|get

=head1 DESCRIPTION

cmd.pl gives basic commands to interact with pfconfig

=item1 reload

Reloads the configuration in pfconfig and sends the expiration signal

=item1 list

Lists the managed namespaces in pfconfig

=item1 show

Shows a namespace as viewed by pfconfig::manager

=item1 get

Shows a namespace as viewed by pfconfig::cached (does the get on the socket)

=cut

use lib '/usr/local/pf/lib';
use strict;
use warnings;

use Switch;
use pfconfig::manager;
use pfconfig::util;

my $cmd = $ARGV[0];

my $manager = pfconfig::manager->new;

switch($cmd) {
  case 'expire' {
    my $namespace = $ARGV[1];
    if(defined($namespace)){
        $manager->expire($namespace);
    }
    else{
      print STDERR "ERROR ! Namespace not defined"
    }
  }
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
    my $full_namespace = $ARGV[1];
    my ($namespace, @args) = pfconfig::util::parse_namespace($full_namespace);
    if(defined($namespace)){
      my @namespaces = $manager->list_namespaces();
      if ( grep {$_ eq $namespace} @namespaces){
        use Data::Dumper;
        print Dumper($manager->get_cache($full_namespace));
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
  case 'clear_overlay' {
    $manager->clear_overlayed_namespaces();
  }
  else {
    print STDERR "ERROR ! Unknown command.\n";
    print STDERR "Commands : \n";
    print STDERR "reload|list|show <namespace>|get <namespace>|clear_overlay \n";
    exit;
  }
};

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

