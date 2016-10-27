#!/usr/bin/perl

=head1 NAME

mse-subscibe.pl

=cut

=head1 DESCRIPTION

mse-subscribe.pl is a script that help to create a notification on Cisco MSE

=head1 SYNOPSIS

mse-subscribe.pl [options]

 Options:
   -h --help               This help
   -u --username           The api username
   -p --password           The api password
   -s --url                The URL of the cisco MSE api (http://192.168.0.1:8083)
   -t --target-ip          The IP Address where you want to send the notification
   -k --target-port        The target port where you want to send the notification
   -w --url-path           The URL path where to send the notification (/mse/)
   -z --zone               The Zone where you want to trigger the event (Campus>Building>Level>Zone)
   -n --notification-name  The name of the notification (Must be unique on the Cisco MSE)

=cut

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;

use Net::Cisco::MSE::REST;

our $USER;
our $PASSWORD;
our $URL;
our $TIP;
our $TPORT;
our $URLPATH;
our $ZONE;
our $help;
our $NOTIFNAME;

GetOptions(
    "username|u=s"          => \$USER,
    "password|p=s"          => \$PASSWORD,
    "url|u=s"               => \$URL,
    "target-ip|t=s"         => \$TIP,
    "target-port|k=s"       => \$TPORT,
    "url-path|w=s"          => \$URLPATH,
    "zone|z=s"              => \$ZONE,
    "notification-name|n=s" => \$NOTIFNAME,
    "help|h"                => \$help,
) or podusage(2);

pod2usage(1) if $help;
die "Missing a parameters\n" if !$USER or !$PASSWORD or !$URL or !$TIP or !$TPORT or !$URLPATH or !$ZONE or !$NOTIFNAME;

my $rest = Net::Cisco::MSE::REST->new(
    url => $URL,
    user => $USER,
    pass => $PASSWORD
);

my $notif = {"NotificationSubscription"=> {
   "name"=> $NOTIFNAME,
   "notificationType"=> "EVENT_DRIVEN",
   "dataFormat"=> "JSON",
   "subscribedEvents"=>    [
            {
         "type"=> "ContainmentEventTrigger",
         "eventEntity"=> "WIRELESS_CLIENTS",
         "boundary"=> "INSIDE",
         "zoneHierarchy" => $ZONE,
         "zoneTimeout" => 10,
      },
      {
         "type"=> "ContainmentEventTrigger",
         "eventEntity"=> "WIRELESS_CLIENTS",
         "boundary"=> "OUTSIDE",
         "zoneHierarchy" => $ZONE,
         "zoneTimeout" => 10,
      }
   ],
   "NotificationReceiverInfo"=> {"transport"=>    {
      "type"=> "TransportHttp",
      "hostAddress"=> $TIP,
      "port"=> $TPORT,
      "macScramblingEnabled"=> "false",
      "urlPath"=> "/mse/",
      "https"=> "false"
   }}
}};

my $notification = $rest->notification_create($notif);

my $notification_view = $rest->notification_view();
print Dumper $notification_view;

