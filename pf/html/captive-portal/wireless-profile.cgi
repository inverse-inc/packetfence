#!/usr/bin/perl

=head1 NAME

wireless-profile.cgi 

=head1 DESCRIPTION

Generates proper XML to provision Wi-Fi settings for mobile devices.

=cut
use strict;
use warnings;

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;
use Log::Log4perl;

use pf::web;
# called last to allow redefinitions
use pf::web::custom;


my $cgi = new CGI;
$cgi->charset("UTF-8");
my $session = new CGI::Session(undef, $cgi, {Directory=>'/tmp'});

# we only support Apple iOS for now
pf::web::generate_apple_mobileconfig_provisioning_xml($cgi, $session);

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2011 Inverse inc.
    
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
