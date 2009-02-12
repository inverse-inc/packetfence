#
# Copyright 2005 David LaPorte <david@davidlaporte.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
# Copyright 2008-2009 Inverse groupe conseil <dgehl@inverse.ca>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

package pf::pfcmd::help;

use strict;
use warnings;
use File::Basename qw(basename);
use Log::Log4perl;

BEGIN {
  use Exporter ();
  our (@ISA, @EXPORT);
  @ISA    = qw(Exporter);
  @EXPORT = qw();
}

sub usage {
  my $command = basename($0);
  if (defined($ARGV[0])) {
    my $functionName = "pf::pfcmd::help::help_" . $ARGV[0];
    if (defined(&$functionName)){
      ($pf::pfcmd::help::{"help_".$ARGV[0]})->();
      exit(1);
    }
  }

  print STDERR << "EOF";
Usage: $command <command> [options]

class                   | view violation classes
config                  | query, set, or get help on pf.conf configuration paramaters
configfiles             | push or pull configfiles into/from database
fingerprint             | view DHCP Fingerprints
graph                   | trending graphs
history                 | IP/MAC history
ifoctetshistorymac      | accounting history
ifoctetshistoryswitch   | accounting history
ifoctetshistoryuser     | accounting history
interfaceconfig         | query/modify interface configuration parameters
ipmachistory            | IP/MAC history
locationhistorymac      | Switch/Port history
locationhistoryswitch   | Switch/Port history
lookup                  | node or pid lookup against local data store
manage                  | manage node entries
networkconfig           | query/modify network configuration parameters
node                    | node manipulation
nodecategory            | nodecategory manipulation
person                  | person manipulation
reload                  | rebuild fingerprint or violations tables without restart
report                  | current usage reports
schedule                | Nessus scan scheduling
service                 | start/stop/restart and get PF daemon status
switchconfig            | query/modify switches.conf configuration parameters
switchlocation          | view switchport description and location
traplog                 | update traplog RRD files and graphs or obtain switch IPs
trigger                 | view and throw triggers
ui                      | used by web UI to create menu hierarchies and dashboard
update                  | download canonical fingerprint or OUI data
version                 | get installed PF version and database MD5s
violation               | violation manipulation
violationconfig         | query/modify violations.conf configuration parameters

Please view "$command help <command>" for details on each option
EOF
  return 1;
}

sub help_manage {
  print STDERR << "EOT";
Usage: pfcmd manage <freemac|register|deregister|vclose|vopen> <mac> [options]

manage nodes

  freemac          | free MAC from ARP spoof
  register         | register node
  deregister       | unregister node
  vclose           | close violation for node
  vopen            | open new violation for node
EOT
  return 1;
}

sub help_service {
  print STDERR << "EOT";
Usage: pfcmd service <service> [start|stop|restart|status|watch]

stop/stop/restart specified service
status returns PID of specified PF daemon or 0 if not running
watch acts as a service watcher which can send email/restart the services

  httpd            | apache
  pf               | all services
  pfdetect         | PF snort alert parser
  pfdhcplistener   | PF DHCP monitoring daemon
  pfmon            | PF ARP monitoring daemon
  pfredirect       | bogus POP3/SMTP servers
  pfsetvlan        | PF VLAN isolation daemon
  snmptrapd        | SNMP trap receiver daemon
  snort            | if stopped or restarted, pfredirect must also be restarted
EOT
  return 1;
}

sub help_nodecategory {
  print STDERR << "EOT";
Usage: pfcmd nodecategory view category

manipulate nodecategories

examples:
  pfcmd nodecategory view all
  pfcmd nodecategory view myCategory
EOT
  return 1;
}

sub help_configfiles {
  print STDERR << "EOT";
Usage: pfcmd configfiles <push|pull>

push configfiles into database or pull them from database

examples:
  pfcmd configfiles push
  pfcmd configfiles pull
EOT
  return 1;
}

sub help_node {
  print STDERR << "EOT";
Usage: pfcmd node <add|count|view|edit|delete> mac [assignments]

manipulate node entries

examples:
  pfcmd node view all
  pfcmd node view all order by pid limit 10,20
  pfcmd node view pid=1 order by pid desc limit 10,20
  pfcmd node count all
  pfcmd node add 00:01:02:03:04:05 status="reg",pid=1
  pfcmd node delete 00:01:02:03:04:05 
EOT
  return 1;
}

sub help_person {
  print STDERR << "EOT";
Usage: pfcmd person <add|view|edit|delete> pid [assignments]

manipulate person entries

examples:
  pfcmd person view all
  pfcmd person add bjenkins notes="Bob Jenkins"
  pfcmd person delete bjenkins
EOT
  return 1;
}

sub help_violation {
  print STDERR << "EOT";
Usage: pfcmd violation <view|edit|delete> id [assignments]
             violation add [assignments]

manipulate violation entries. the id is DIFFERENT from vid.  The ID is just 
a unique identifier for this specific violation, not the ID contained in violation.conf

examples:
  pfcmd violation view all
  pfcmd violation add vid=1200003,mac=00:01:02:03:04:05
  pfcmd violation delete 4
EOT
  return 1;
}

sub help_schedule {
  print STDERR << "EOT";
Usage: pfcmd schedule <view|add|edit|delete> [number|ip-range|ipaddress/cidr] [assignments]

use nessus to scan ip(s).  IP address can be specified as IP, Start-EndIP, IP/xx Cidr format.

examples:
  pfcmd schedule view all
  pfcmd schedule view 1
  pfcmd schedule now 128.11.23.2/24 tid=11808;11835;11890;12209
  pfcmd schedule add 128.11.23.7/24 tid=all,date="0 3 * * *"
  pfcmd schedule add 128.11.23.2/24 tid=11808;11835;11890;12209,date="0 3 * * *"
  pfcmd schedule delete 2
EOT
  return 1;
}

sub help_locationhistoryswitch {
  print STDERR << "EOT";
Usage: pfcmd locationhistoryswitch switch ifIndex [date]
        
get the MAC connected to a specified switch port with optional date (in mysql format)

examples:
  pfcmd locationhistoryswitch 192.168.0.1 10
  pfcmd locationhistoryswitch 192.168.0.1 6 2006-10-12 15:00:00
EOT
  return 1;
}

sub help_locationhistorymac {
  print STDERR << "EOT";
Usage: pfcmd locationhistorymac mac [date]
        
get the switch port where a specified MAC connected to with optional date (in mysql format)

examples:
  pfcmd locationhistorymac 00:11:22:33:44:55
  pfcmd locationhistorymac 00:11:22:33:44:55 2006-10-12 15:00:00
EOT
  return 1;
}

sub help_ifoctetshistoryswitch {
  print STDERR << "EOT";
Usage: pfcmd ifoctetshistoryswitch switch ifIndex
        
get the bytes throughput through a specified switch port with optional date

examples:
  pfcmd ifoctetshistoryswitch 192.168.0.1 10
  pfcmd ifoctetshistoryswitch 192.168.0.1 10 start_time=2007-10-12 10:00:00,end_time=2007-10-13 10:00:00
EOT
  return 1;
}

sub help_ifoctetshistorymac {
  print STDERR << "EOT";
Usage: pfcmd ifoctetshistorymac mac
        
get the bytes throughput generated by a specified MAC with optional date

examples:
  pfcmd ifoctetshistorymac 00:11:22:33:44:55
  pfcmd ifoctetshistorymac 00:11:22:33:44:55 start_time=2007-10-12 10:00:00,end_time=2007-10-13 10:00:00

EOT
  return 1;
}

sub help_ifoctetshistoryuser {
  print STDERR << "EOT";
Usage: pfcmd ifoctetshistoryuser pid
        
get the bytes throughput generated by a specified user with optional date

examples:
  pfcmd ifoctetshistoryuser testUser
  pfcmd ifoctetshistoryuser testUser start_time=2007-10-12 10:00:00,end_time=2007-10-13 10:00:00

EOT
  return 1;
}

sub help_ipmachistory {
  print STDERR << "EOT";
Usage: pfcmd ipmachistory <ip|mac> [start_date=<date>,end_time=<date>]
        
get the MAC/IP mapping for a specified IP or MAC with optional date (in mysql format)

examples:
  pfcmd ipmachistory 192.168.1.100
  pfcmd ipmachistory 192.168.1.100 start_time=2006-10-12 15:00:00,end_time=2006-10-18 12:00:00
EOT
  return 1;
}

sub help_history {
  print STDERR << "EOT";
Usage: pfcmd history <ip|mac> [date]
        
get the MAC/IP mapping for a specified IP or MAC with optional date (in mysql format)

examples:
  pfcmd history 192.168.1.100
  pfcmd history 192.168.1.100 2006-10-12 15:00:00
EOT
  return 1;
}

sub help_report {
  print STDERR << "EOT";
Usage: pfcmd report <active|inactive> | <registered|unregistered|os|osclass|unknownprints|openviolations|statics> [all|active]

display canned reports - "active" modifier shows only nodes with open iplog entries

active         | show all nodes with open iplog entries
inactive       | show all nodes without an open iplog entry
registered     | show all registered nodes
unregistered   | show all unregistered nodes
os             | show OS distribution
osclass        | show OS distribution, aggregated by class
unknownprints  | show DHCP fingerprints without a known OS mapping
openviolations | show all open violations
statics        | show probable static IPs
EOT
  return 1;
}

sub help_graph {
  print STDERR << "EOT";
Usage: pfcmd graph <registered|unregistered|violations|nodes> [day|month|year]
    or
       pfcmd graph ifoctetshistoryswitch <switch> <ifIndex> start_time=<time>,end_time=<time>
       pfcmd graph ifoctetshistorymac <MAC> start_time=<time>,end_time=<time>
       pfcmd graph ifoctetshistoryuser <pid> start_time=<time>,end_time=<time>

provide data form graphs aggregated my day, month, or year

registered            | historical registered node data
unregistered          | historical unregistered node data
violations            | historical open violation data
nodes                 | dual series graph of registered vs unregistered
ifoctetshistoryswitch | history of traffic usage for a given switchport
ifoctetshistorymac    | history of traffic usage for a given MAC
ifoctetshistoryuser   | history of traffic usage for a given user
EOT
  return 1;
}

sub help_config {
  print STDERR << "EOT";
Usage: pfcmd config <get|set|help> option[=value]

get, set, or display help on pf.conf configuration values

examples:
  pfcmd config get general.hostname
  pfcmd config set general.hostname=new_hostname
  pfcmd config help general.hostname
EOT
  return 1;
}

sub help_ui {
  print STDERR << "EOT";
Usage: pfcmd ui menus
                dashboard <recent_violations|recent_violations_opened|recent_violations_closed|recent_registrations> <interval>
                dashboard <current_grace|current_activity|current_node_status>

provide UI menu details and bite-size dashboard/rss information "nuggets"

ui menus                 | provide menu details to web UI
recent_violations        | show recent violation activity in <interval> hours (up to 10 records) 
recent_violations_opened | show recent violation opens in <interval> hours (up to 10 records)
recent_violations_closed | show recent violation closes in <interval> hours (up to 10 records)
recent_registrations     | show recent registrations in <interval> hours (up to 10 records)
current_grace            | show nodes (up to 10) currently in "grace"
current_activity         | show active vs inactive nodes
current_node_status      | show registered vs unregistered active nodes
EOT
  return 1;
}

sub help_class {
  print STDERR << "EOT";
Usage: pfcmd class view <vid>

view violation classification - to edit, use violations.conf and "pfcmd reload violations"
EOT
  return 1;
}

sub help_trigger {
  print STDERR << "EOT";
Usage: pfcmd trigger view <id> [scan|detect]

view the Snort IDs, OS IDs,  and Nessus plugins associated with violations.  To edit, modify violations.conf and execute "pfcmd reload violations" 

examples:
	pfcmd trigger view all
	pfcmd trigger view 12
	pfcmd trigger view all scan
EOT
  return 1;
}

sub help_update {
  print STDERR << "EOT";
Usage: pfcmd update <fingerprints|oui>

download canonical fingerprint or OUI data

fingerprints | update dhcp_fingerprints.conf from packetfence.org
oui          | update OUI prefixes from IEEE
EOT
  return 1;
}

sub help_reload {
  print STDERR << "EOT";
Usage: pfcmd reload <fingerprints|violations>

reload fingerprints or violations database tables without restart
EOT
  return 1;
}

sub help_version {
  print STDERR << "EOT";
Usage: pfcmd version 

get installed PF version and database MD5s
EOT
  return 1;
}

sub help_fingerprint {
  print STDERR << "EOT";
Usage: pfcmd fingerprint view <all|id>

show DHCP Fingerprints stored in database

examples:
  pfcmd fingerprint view all
  pfcmd fingerprint view 1,6,15,44,3,33
EOT
  return 1;
}

sub help_switchlocation {
  print STDERR << "EOT";
Usage: pfcmd switchlocation view <ip> <ifIndex>

show switchlocation information stored in database

examples:
  pfcmd switchlocation view 192.168.70.1 3
EOT
  return 1;
}

sub help_lookup {
  print STDERR << "EOT";
Usage: pfcmd lookup <person|node> value

call bin/lookup_person.pl or bin/lookup_node.pl with the passed value
EOT
  return 1;
}

sub help_violationconfig {
  print STDERR << "EOT";
Usage: pfcmd violationconfig get <all|defaults|vid>
       pfcmd violationconfig add <vid> [assignments]
       pfcmd violationconfig edit <vid> [assignments]
       pfcmd violationconfig delete <vid>

query/modify violations.conf configuration file
EOT
  return 1;
}

sub help_networkconfig {
  print STDERR << "EOT";
Usage: pfcmd networkconfig get <all|network>
       pfcmd networkconfig add <network> [assignments]
       pfcmd networkconfig edit <network> [assignments]
       pfcmd networkconfig delete <network>

query/modify networks.conf configuration file
EOT
  return 1;
}

sub help_interfaceconfig {
  print STDERR << "EOT";
Usage: pfcmd interfaceconfig get <all|interface>
       pfcmd interfaceconfig add <interface> [assignments]
       pfcmd interfaceconfig edit <interface> [assignments]
       pfcmd interfaceconfig delete <interface>

query/modify pf.conf configuration file
EOT
  return 1;
}

sub help_switchconfig {
  print STDERR << "EOT";
Usage: pfcmd switchconfig get <all|default|IP>
       pfcmd switchconfig add <IP> [assignments]
       pfcmd switchconfig edit <IP> [assignments]
       pfcmd switchconfig delete <IP>

query/modify switches.conf configuration file
EOT
  return 1;
}

sub help_traplog {
  print STDERR << "EOT";
Usage: pfcmd traplog update
       pfcmd traplog most <number> {day|week|total}

obtain the switch IPs of the <n> switches having sent the most traps
update traplog RRD files and graphs - this command should not be
  run by hand but executed through a crontab in 5 minute intervals; for
  example
  */5 * * * * /usr/local/pf/bin/pfcmd traplog update
EOT
  return 1;
}

1;
