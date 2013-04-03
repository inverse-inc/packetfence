package pf::pfcmd::help;

=head1 NAME

pf::pfcmd::help - usage messages

=cut

use strict;
use warnings;
use File::Basename qw(basename);
use Log::Log4perl;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw();
}

=head1 SUBROUTINES

TODO: This list is incomplete.

=over

=item usage

If a true value is passed as a parameter we output to STDOUT instead of STDERR.

=cut
sub usage {
    my ($to_stdout) = @_;

    my $command = basename($0);
    if ( defined( $ARGV[0] ) ) {
        my $functionName = "pf::pfcmd::help::help_" . $ARGV[0];
        if ( defined(&$functionName) ) {
            ( $pf::pfcmd::help::{ "help_" . $ARGV[0] } )->();
            exit(1);
        }
    }

    print { $to_stdout ? *STDOUT : *STDERR } << "EOF";
Usage: $command <command> [options]

checkup                      | perform a sanity checkup and report any problems or warnings
class                        | view violation classes
config                       | query, set, or get help on pf.conf configuration paramaters
configfiles                  | push or pull configfiles into/from database
floatingnetworkdeviceconfig  | query/modify floating network device configuration parameters
fingerprint                  | view DHCP Fingerprints
graph                        | trending graphs
history                      | IP/MAC history
import                       | bulk import of information into the database
ifoctetshistorymac           | accounting history
ifoctetshistoryswitch        | accounting history
ifoctetshistoryuser          | accounting history
interfaceconfig              | query/modify interface configuration parameters
ipmachistory                 | IP/MAC history
locationhistorymac           | Switch/Port history
locationhistoryswitch        | Switch/Port history
lookup                       | node or pid lookup against local data store
manage                       | manage node entries
networkconfig                | query/modify network configuration parameters
node                         | node manipulation
nodeaccounting               | RADIUS accounting information
nodecategory                 | nodecategory manipulation
nodeuseragent                | View User-Agent information associated to a node
person                       | person manipulation
reload                       | rebuild fingerprint or violations tables without restart
report                       | current usage reports
schedule                     | Nessus scan scheduling
service                      | start/stop/restart and get PF daemon status
switchconfig                 | query/modify switches.conf configuration parameters
switchlocation               | view switchport description and location
traplog                      | update traplog RRD files and graphs or obtain switch IPs
trigger                      | view and throw triggers
ui                           | used by web UI to create menu hierarchies and dashboard
update                       | download canonical fingerprint or OUI data
useragent                    | view User-Agent fingerprint information
version                      | output version information
violation                    | violation manipulation
violationconfig              | query/modify violations.conf configuration parameters

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

Services managed by PacketFence:
  dhcpd            | dhcpd daemon
  httpd            | Apache (Captive Portal and Web Admin and soap)
  httpd.webservices| Apache Webservices
  httpd.admin      | Apache Web admin
  httpd.portal     | Apache Captive Portal
  named            | DNS daemon (bind)
  pf               | all services that should be running based on your config
  pfdetect         | PF snort alert parser
  pfdhcplistener   | PF DHCP monitoring daemon
  pfmon            | PF ARP monitoring daemon
  pfsetvlan        | PF VLAN isolation daemon
  radiusd          | FreeRADIUS daemon
  snmptrapd        | SNMP trap receiver daemon
  snort            | Sourcefire Snort IDS
  suricata         | Suricata IDS

watch
Watch performs services checks to make sure that everything is fine. It's
behavior is controlled by servicewatch configuration parameters. watch is
typically best called from cron with something like:
*/5 * * * * /usr/local/pf/bin/pfcmd service pf watch
EOT
    return 1;
}

sub help_nodecategory {
    print STDERR << "EOT";
Usage: pfcmd nodecategory <view|edit|delete> id [assignments]
             nodecategory add [assignments]

manipulate nodecategories

examples:
  pfcmd nodecategory view all
  pfcmd nodecategory view 2
  pfcmd nodecategory add name=smartphones
  pfcmd nodecategory delete 2
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
  pfcmd node view pid="admin" order by pid desc limit 10,20
  pfcmd node count all
  pfcmd node add 00:01:02:03:04:05 status="reg",pid="admin"
  pfcmd node delete 00:01:02:03:04:05
EOT
    return 1;
}

sub help_nodeaccounting {
    print STDERR << "EOT";
Usage: pfcmd nodeaccounting view <all|id>

View RADIUS accounting information for a node

examples:
  pfcmd nodeaccounting view all
  pfcmd nodeaccounting view 00:01:02:03:04:05
EOT
    return 1;
}

sub help_nodeuseragent {
    print STDERR << "EOT";
Usage: pfcmd nodeuseragent view <all|id>

View User-Agent information associated to a node

examples:
  pfcmd nodeuseragent view all
  pfcmd nodeuseragent view 00:01:02:03:04:05
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
a unique identifier for this specific violation, not the ID contained in violations.conf

examples:
  pfcmd violation view all
  pfcmd violation add vid=1200003,mac=00:01:02:03:04:05
  pfcmd violation delete 4
EOT
    return 1;
}

sub help_schedule {
    print STDERR << "EOT";
Usage: pfcmd schedule <view|now|add|edit|delete> [number|ip-range|ipaddress/cidr|all] [assignments]

use nessus to scan ip(s).  IP address can be specified as IP, Start-EndIP, IP/xx Cidr format.

examples:
  pfcmd schedule view all
  pfcmd schedule view 1
  pfcmd schedule now 128.11.23.2/24
  pfcmd schedule add 128.11.23.7/24 date="0 3 * * *"
  pfcmd schedule add 128.11.23.2/24 date="0 3 * * *"
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
Usage: pfcmd report
               <active|inactive>
               <connectiontype|connectiontypereg|ssid> [all|active]
               <registered|unregistered|unknownprints|unknownuseragents> [all|active]
               <openviolations|statics> [all|active]
               <os|osclass> [all|active]
               osclassbandwidth [all|day|week|month|year]
               nodebandwidth
               topsponsor

display canned reports - "active" modifier shows only nodes with open iplog entries

active            | show all nodes with open iplog entries
inactive          | show all nodes without an open iplog entry
connectiontype    | show connections by type for all nodes
connectiontypereg | show connections by type for registered nodes only
registered        | show all registered nodes
unregistered      | show all unregistered nodes
os                | show OS distribution
osclass           | show OS distribution, aggregated by class
osclassbandwidth  | show bandwitdh usage by OS distribution (use day/week/month/year for the time window)
nodebandwidth     | show bandwitdh usage for the top 25 bandwidth eating nodes
sponsoruser       | show top 25 of sponsor user
unknownprints     | show DHCP fingerprints without a known OS mapping
unknownuseragents | show User-Agents fingerprints without a known Browser or OS mapping
openviolations    | show all open violations
ssid              | show user connections by SSID
statics           | show probable static IPs
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

sub help_checkup {
    print STDERR << "EOT";
Usage: pfcmd checkup

perform a sanity checkup and report any problems or warnings
EOT
    return 1;
}

sub help_version {
    print STDERR << "EOT";
Usage: pfcmd version

output version information
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

sub help_useragent {
    print STDERR << "EOT";
Usage: pfcmd useragent view <all|id>

show User-Agent Fingerprints known by the system

examples:
  pfcmd useragent view all
  pfcmd useragent view 1,6,15,44,3,33
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

show information about a person entry (searching by pid)
or a node entry (searching by mac)
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

sub help_floatingnetworkdeviceconfig {
    print STDERR << "EOT";
Usage: pfcmd floatingnetworkdeviceconfig get <all|floatingnetworkdevice>
       pfcmd floatingnetworkdeviceconfig add <floatingnetworkdevice> [assignments]
       pfcmd floatingnetworkdeviceconfig edit <floatingnetworkdevice> [assignments]
       pfcmd floatingnetworkdeviceconfig delete <floatingnetworkdevice>

query/modify floating_network_device.conf configuration file
EOT
    return 1;
}

sub help_import {
    print STDERR << "EOT";
Usage: pfcmd import <format> <filename>

Bulk import into the database. File input must be a of CSV format. Default
pid, category and voip status assigned to the imported nodes can be modified
in pf.conf.

Supported format:
- nodes

Nodes import format:
<MAC>

Node import automatically registers MACs with pid = 1 unless you configured
otherwise in pf.conf.

example:
  pfcmd import nodes /tmp/new-nodes.csv
EOT
    return 1;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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
