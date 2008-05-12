#!/usr/bin/perl -w
#
# (c) 2006-2008 Inverse inc., licensed under the GPLv2
#
# Author: Regis Balzard <rbalzard@inverse.ca>
#         Dominik Gehl  <dgehl@inverse.ca>
#
# Check if (when this node is the master):
#   - packetfence, pfmon, http and pfsetvlan services are running
# If not then notify administrators.
#

use strict;
use warnings;
use diagnostics;
use FindBin;
use Net::SMTP;
use Log::Log4perl qw(:easy);
use constant {
    LIB_DIR => $FindBin::Bin . "/../../lib",
    CONF_FILE => $FindBin::Bin . "/../../conf/switches.conf"
};
use lib LIB_DIR;
use pf::SwitchFactory;

require 5.8.8;

Log::Log4perl->easy_init(
    {
        level => $DEBUG,
        layout => '%d (%r) %M%n    %m %n'
    }
);
my $logger = Log::Log4perl->get_logger('');


my $trouble = 1;
my $switchFactory = new pf::SwitchFactory(
    -configFile => CONF_FILE
);
my %Config = %{$switchFactory->{_config}};
my $count = 0;
my $status;
my $hostname =`/bin/hostname --long`;
my $host;
my $domain ;
my $ext ;

($host,$domain,$ext) = split(/\./,$hostname);

while (($count < 3) && ($trouble > 0)) {
    $logger->debug("starting loop $count");
    $trouble = 0;
    if ($count > 0) {
        $logger->debug("entering sleep");
        sleep 60;
        $logger->debug("finishing sleep");
    }

    #$status = `/usr/bin/cl_status rscstatus`
    $status = "all";
    chomp($status);
    if ($status eq "all") {
        $logger->debug("testing for pfsetvlan pid");
        my $pid=`/sbin/pidof -x pfsetvlan`;
        $pid =~ s/\n//g;
        if (! $pid) {
            $trouble++; 
        }
        if ( !(-e "/usr/local/pf/var/httpd.pid") || !(-e "/usr/local/pf/var/pfmon.pid") ) {
            $trouble = $trouble + 2; 
        }
    }
    $logger->debug("trouble value is $trouble");
    $count++;
}

if ($trouble > 0) {
    my $mail_host = $Config{'default'}{'mail_hostname'};
    my @mail_to = split(/,/, $Config{'default'}{'mail_to'});
    my $mail_from = $Config{'default'}{'mail_from'};
    my $smtp = Net::SMTP->new($mail_host, Debug => 0) or die "service_watcher.pl cannot connect to mail server $mail_host";

    $smtp->mail($mail_from);
    $smtp->to(@mail_to, { SkipBad => 1});
    $smtp->data();
    $smtp->datasend("To: " . join(', ', @mail_to) . "\n");
    $smtp->datasend("From: $mail_from\n");
    $smtp->datasend("Subject: Packetfence Alert\n");
    $smtp->datasend("\n");
    $smtp->datasend("$host is the master but the following service(s) are not running and need to be manually restarted:\n");
    if ( ($trouble == 1) || ($trouble == 3) ) {
        $smtp->datasend("\t- pfsetvlan\n"); 
        $smtp->datasend("\n");
        $smtp->datasend("The script is re-starting pfsetvlan\n");
        `rm -f /var/lock/subsys/pfsetvlan`;
        `rm -f /var/run/pfsetvlan.pid`;
        `/etc/init.d/pfsetvlan start`;
    }
    if ( ($trouble == 2) || ($trouble == 3) ) { 
        `/etc/init.d/packetfence stop`;
        sleep(10);
        `/etc/init.d/packetfence start`;

        $smtp->datasend("\t- packetfence\n"); 
        $smtp->datasend("\n");
        $smtp->datasend("The script is re-starting PacketFence\n");

    }
    $smtp->dataend();
    $smtp->quit();
}

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

