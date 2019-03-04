#!/usr/bin/perl 
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
# USA.
#
# Copyright (C) 2005-2019 Inverse inc.
#
# Authors: Inverse inc. <info@inverse.ca> 
#


use strict;
use Error qw(:try);
use POSIX;
use SF::Logger;
use SF::IPAddr;

use XML::Smart;

use lib("../");
use SOAP::Lite;

use Constants;

#Do not do this at home
use IO::Socket::SSL;
IO::Socket::SSL::set_defaults(SSL_verify_mode => "SSL_VERIFY_NONE");
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0;

                   ### Configuration Variables ###
my $config_file = "instance.conf";
                 ### End Configuration Variables ###

# Input Handling

my $prog = $0;
$prog =~ s/^.*\///;
if(@ARGV < 2){
    warn( "usage: $prog remediation sid ip\n");
    exit(INPUT_ERR);
}

my ($rem,$sid,$src_ip) = @ARGV;

my $XML = XML::Smart->new($config_file);

my %rem_config;

my $found=0;
my $net=0;

foreach my $localrem(@{$XML->{instance}->{remediation}}) {
    if($localrem->{name} =~ /^$rem$/) {
        $found=1;
	my @config = $XML->{instance}->{config}->nodes();
	foreach my $config (@config) {
            $rem_config{$config->{name}} = $config->content;
        }
    }

    $rem_config{'type'}=$localrem->{type};
}

if($found == 0) {
    sfinfo($prog,"input","$rem is not configured");
    exit(CONFIG_ERR);
}

# Do our stuff
eval {
   my $url = "https://" . $rem_config{'user'} . ":" . $rem_config{'password'} . "@" . $rem_config{'host_addr'} . ":" . $rem_config{'port'} . "/webapi";
   my $soap = new SOAP::Lite(
        uri => 'http://www.packetfence.org/PFAPI',
        proxy => $url
      );
   $soap->ssl_opts(verify_hostname => 0);
   $soap->{_transport}->{_proxy}->{ssl_opts}->{verify_hostname} = 0;

   my $date = POSIX::strftime("%m/%d-%H:%M:%S",localtime(time));

   my %event = (
       events => {
           detect => $sid,
       },
       srcip => $src_ip,
       date  => $date,
   );
   my $result = $soap->event_add(%event);

   if ($result->fault) {
      sferror($prog, "cmd_output", "violation could not be added: " . $result->faultcode . " - " . $result->faultstring . " - " . $result->faultdetail);
      exit(UNDEF);
   }
};

if ($@) {
    sferror($prog, "input", "connection to $rem_config{'host_addr'} with username $rem_config{'user'} was NOT successful: $@");
    exit(UNDEF);
}

exit(SUCCESS);
