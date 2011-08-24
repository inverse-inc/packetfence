#!/usr/bin/perl
=head1 NAME

guest-selfregistration.cgi - guest self registration portal

=cut
use strict;
use warnings;

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;
use Log::Log4perl;
use Readonly;
use POSIX;

use constant INSTALL_DIR => '/usr/local/pf';
use constant SCAN_VID => 1200001;
use lib INSTALL_DIR . "/lib";
# required for dynamically loaded authentication modules
use lib INSTALL_DIR . "/conf";

use pf::class;
use pf::config;
use pf::email_activation;
use pf::sms_activation;
use pf::iplog;
use pf::node;
use pf::util;
use pf::violation;
use pf::web;
use pf::web::guest 1.10;
# called last to allow redefinitions
use pf::web::custom;

# constants
Readonly::Scalar my $GUEST_REGISTRATION => "guest-register";

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('guest-selfregistration.cgi');
Log::Log4perl::MDC->put('proc', 'guest-selfregistration.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $cgi = new CGI;
my $session = new CGI::Session(undef, $cgi, {Directory=>'/tmp'});

my $result;
my $ip              = $cgi->remote_addr();
my $destination_url = $cgi->param("destination_url");
my $enable_menu     = $cgi->param("enable_menu");
my $mac             = ip2mac($ip);
my %params;
my %info;

# pull parameters from query string
foreach my $param($cgi->url_param()) {
  $params{$param} = $cgi->url_param($param);
}
foreach my $param($cgi->param()) {
  $params{$param} = $cgi->param($param);
}

# Correct POST
if (defined($params{'mode'}) && $params{'mode'} eq $GUEST_REGISTRATION) {

    # authenticate
    my ($auth_return, $err) = pf::web::guest::validate_selfregistration($cgi, $session);

    # Registration form was properly filled
    if ($auth_return && defined($params{'by_email'})) {
      # User chose to register by email
      $logger->info("Registering guest by email");

      # Adding person (using edit in case person already exists)
      my $person_add_cmd = "$bin_dir/pfcmd 'person edit \""
        . $session->param("login")."\" "
        . "firstname=\"" . $session->param("firstname") . "\","
        . "lastname=\"" . $session->param("lastname") . "\","
        . "email=\"" . $session->param("email") . "\","
        . "telephone=\"" . $session->param("phone") . "\","
        . "notes=\"guest account\"'";
      $logger->info("Registering guest person with command: $person_add_cmd");
      pf_run("$person_add_cmd");

      # grab additional info about the node
      $info{'pid'} = $session->param("login");
      $info{'user_agent'} = $cgi->user_agent;
      $info{'category'} = "guest";

      # unreg in 10 minutes
      $info{'unregdate'} = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime( time + 10*60 ));

      # register the node
      pf::web::web_node_register($cgi, $session, $mac, $info{'pid'}, %info);

      # add more info for the activation email
      $info{'firstname'} = $session->param("firstname");
      $info{'lastname'} = $session->param("lastname");
      $info{'telephone'} = $session->param("phone");

      $info{'subject'} = $Config{'general'}{'domain'}.': Email activation required';
      
      # TODO this portion of the code should be throttled to prevent malicious intents (spamming)
      pf::email_activation::create_and_email_activation_code(
          $mac, $info{'pid'}, $info{'pid'}, $pf::email_activation::GUEST_TEMPLATE, %info
      );

      # Violation handling and redirection (accorindingly)
      my $count = violation_count($mac);
      
      if ($count == 0) {
        pf::web::generate_release_page($cgi, $session, $destination_url);
        $logger->info("registration url = $destination_url");
      }
      else {
        print $cgi->redirect("/captive-portal?destination_url=$destination_url");
        $logger->info("more violations yet to come for $mac");
      }
    }
    elsif ($auth_return && defined($params{'by_sms'})) {
      # User chose to register by SMS
      $logger->info("Registering guest by SMS " . $session->param("phone") . " @ " . $cgi->param("mobileprovider"));
      if ($session->param("phone") && $cgi->param("mobileprovider")) {
        sms_activation_create_send($mac, $session->param("phone"), $cgi->param("mobileprovider") );
        $logger->info("redirecting to mobile confirmation page");
        generate_sms_confirmation_page($cgi, $session, "/activate/sms", $destination_url, $err);
        return (0);
      }
      
      ($auth_return, $err) = (0, 1);
    }

    # Registration form was invalid, return to guest self-registration page and show error message
    if ($auth_return != 1) {
        $logger->info("Missing information for self-registration");
        pf::web::guest::generate_selfregistration_page(
            $cgi, $session, "/signup?mode=$GUEST_REGISTRATION", $destination_url, $mac, $err
        );
        exit(0);
    }
}
else {
    # wipe web fields
    $cgi->delete('firstname', 'lastname', 'email', 'phone');

    # by default, show guest registration page
    pf::web::guest::generate_selfregistration_page(
        $cgi, $session, "/signup?mode=$GUEST_REGISTRATION", $destination_url, $mac
    );
}

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2010-2011 Inverse inc.
    
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

