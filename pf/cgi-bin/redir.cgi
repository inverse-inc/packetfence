#!/usr/bin/perl
#use Data::Dumper;
use strict;
use warnings;

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;

use lib '/usr/local/pf/lib';
use pf::config;
use pf::iplog;
use pf::util;
use pf::web;
# not SUID now!
#use pf::rawip;
use pf::node;
use pf::class;
use pf::violation;

my $cgi = new CGI;
my $session = new CGI::Session(undef, $cgi, {Directory=>'/tmp'});

my $result;
my $ip              = $cgi->remote_addr();
my $destination_url = $cgi->param("destination_url");
my $enable_menu     = $cgi->param("enable_menu");
my $mac             = ip2mac($ip);
my %tags;

# valid mac?
if (!valid_mac($mac)) {
  pflogger("$ip not resolvable, generating error page",1);
  generate_error_page($cgi, $session, "error: not found in the database");
  exit(0);
}
pflogger("$mac being redirected", 8);

# registration auth request?
if (defined($cgi->param('mode')) && $cgi->param('auth')) {
 my $type=$cgi->param('auth');
 if ($type eq "skip"){
    pflogger("User is trying to skip redirecting to release.cgi ",1);
    print $cgi->redirect("/cgi-bin/release.cgi?mode=skip&destination_url=$destination_url");    
  }else{
    pflogger("redirecting to register-$type.cgi for reg authentication ",1);
    print $cgi->redirect("/cgi-bin/register-$type.cgi?mode=register&destination_url=$destination_url");
  }
}


#check to see if node needs to be registered
#
my $unreg = node_unregistered($mac);
pflogger("TEST: node_unregistered($mac) returns $unreg", 8);
pflogger("TEST: isenabled(trapping.registration) returns " . isenabled($Config{'trapping'}{'registration'}), 8); 
if ($unreg && isenabled($Config{'trapping'}{'registration'})){
  pflogger("$mac redirected to registration page", 8);
  generate_registration_page($cgi, $session, $destination_url,$mac);
  exit(0);
} 

# check violation 
#
my $violation = violation_view_top($mac);
if ($violation){
  if ($unreg && $Config{'trapping'}{'registration'} =~ /^onviolation$/) {
    pflogger("$mac redirected to registration page", 8);
    generate_registration_page($cgi, $session, $destination_url,$mac);
    exit(0);
  }
  my $vid=$violation->{'vid'};
  my $class=class_view($vid);
  # enable button
  if ($enable_menu) {
    pflogger("enter enable_menu",1);
    generate_enabler_page($cgi, $session, $destination_url, $vid, $class->{'button_text'});
  } elsif  ($class->{'auto_enable'} eq 'Y'){
    pflogger("auth_enable =  Y",1);
    generate_redirect_page($cgi, $session, $class->{'url'}, $destination_url);
  } else {
    pflogger("no button",1);
    # no enable button 
    print $cgi->redirect($class->{'url'});
  }
} else {
  pflogger("$mac already registered or registration disabled, freeing mac",2);
  if ($Config{'network'}{'mode'} =~ /passive/i) {
    my $cmd = $install_dir."/bin/pfcmd manage freemac $mac";
    my $output = qx/$cmd/;
  }
  pflogger("freed $mac and redirecting to ".$Config{'trapping'}{'redirecturl'}, 8);
  print $cgi->redirect($Config{'trapping'}{'redirecturl'});
}
