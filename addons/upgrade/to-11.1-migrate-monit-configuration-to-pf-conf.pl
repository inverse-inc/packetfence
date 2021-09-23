#!/usr/bin/perl

use strict;
use warnings;

use lib '/usr/local/pf/lib';
use lib '/usr/local/pf/lib_perl/lib/perl5';
use Config::IniFiles;
use pf::file_paths qw($pf_config_file);

my $MONIT_DIR = "/etc/monit/conf.d";
if (-f "/etc/redhat-release") {
  $MONIT_DIR="/etc/monit.d/";
}

unless (-f "$MONIT_DIR/monit_general.conf") {
  print "No monit configuration detected. Nothing to do. \n";
  exit 0;
}

my $emails = `grep 'set alert' /etc/monit.d/monit_general.conf | awk '{print \$3}' | sort | uniq | tr '\\n' ',' | sed 's/,\$/\\n/'`;
$emails =~ s/\n$//;
my $subject_prefix = `grep subject: /etc/monit.d/monit_general.conf | sed 's/subject: \\(.*\\) | Monit.*/\\1/' | sed 's/^\\s*//g' `;
$subject_prefix =~ s/\n$//;
my $mailserver=`grep 'set mailserver' /etc/monit.d/monit_general.conf | awk '{ print \$3 }'`;
$mailserver =~ s/\n$//;

my @configurations;
if (-f "$MONIT_DIR/00_packetfence.conf") {
  push @configurations, "packetfence";
}
if (-f "$MONIT_DIR/10_packetfence-portsec.conf") {
  push @configurations, "portsec";
}
if (-f "$MONIT_DIR/20_packetfence-drbd.conf") {
  push @configurations, "drbd";
}
if (-f "$MONIT_DIR/40_OS-winbind.conf") {
  push @configurations, "os-winbind";
}
if (-f "$MONIT_DIR/50_OS-checks.conf") {
  push @configurations, "os-checks";
}

my $configurations_str = join(",", @configurations);

print "Reconfiguring monit in pf.conf using emails:'$emails', subject_prefix:'$subject_prefix', configurations:'$configurations_str', mailserver:'$mailserver' \n";

my $ini = Config::IniFiles->new(-file => $pf_config_file);

$ini->AddSection("monit") if(!$ini->SectionExists("monit"));

my %monit_conf = (
    status => "enabled",
    alert_email_to => $emails,
    subject_prefix => $subject_prefix,
    configurations => $configurations_str,
    mailserver => $mailserver,
);

while(my ($k, $v) = each(%monit_conf)) {
    if($ini->val("monit", $k)) {
        $ini->setval("monit", $k, $v);
    } else {
        $ini->newval("monit", $k, $v);
    }
}

$ini->RewriteConfig();

print "All done!\n";
