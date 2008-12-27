#
# Copyright 2005 David LaPorte <david@davidlaporte.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
# Copyright 2008 Inverse groupe conseil <dgehl@inverse.ca>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

use strict;
use warnings;
use Log::Log4perl;

use vars qw/%cmd %table2key $grammar $delimiter/;

$delimiter="|";

$::RD_AUTOACTION = q {
  if ($#item>1 ){
   foreach my $val (@item[1..$#item]){
      if (ref($val) eq 'ARRAY') {
        push @{$main::cmd{$item[0]}},@{$val};
      }else{ push @{$main::cmd{$item[0]}},$val; }
   }
  }elsif ($#item==1){$item[1]}
};

%table2key = (
  "person"          => "pid",
  "node"            => "mac",
  "violation"       => "id",
  "class"           => "vid",
  "trigger"         => "trigger",
  "scan"            => "id",
); 

$grammar = q {
   start : command eofile

   command :   'service' service_options /$/
             | 'node' node_options /$/
             | 'person' person_options /$/
             | 'nodecategory' nodecategory_options /$/
             | 'switchlocation' switchlocation_options /$/
             | 'violation' violation_options /$/
             | 'class' class_options /$/
             | 'trigger' trigger_options /$/
             | 'ui' 'menus' ui_options(?) /$/
             | 'ui' 'dashboard' dashboard_options vid(?) /$/
             | 'report' ('inactive' | 'active') 
             | 'report' ('unregistered' | 'registered' | 'osclass' | 'os' | 'unknownprints' | 'openviolations' | 'statics') ('all' | 'active')(?) /$/
             | 'fingerprint' fingerprint_options /$/
             | 'config' ('get' | 'set' | 'help') /.+/ /$/
             | 'lookup' ('person' | 'node') value /$/
             | 'version' /$/
             | 'reload' ('fingerprints' | 'violations') /$/
             | 'update' ('fingerprints' | 'oui') /$/
             | 'manage' manage_options /$/
             | 'help' config_value /$/
             | 'graph' ('unregistered' | 'registered' | 'violations' | 'nodes') ('day'|'month'|'year')(?)/$/
             | 'graph' 'ifoctetshistoryswitch' ipaddr number date_range /$/
             | 'graph' 'ifoctetshistorymac' mac date_range /$/
             | 'graph' 'ifoctetshistoryuser' value date_range /$/
             | 'schedule' schedule_options /$/
             | 'locationhistoryswitch' ipaddr number date(?) /$/
             | 'locationhistorymac' mac date(?) /$/
             | 'ifoctetshistoryswitch' ipaddr number date_range(?) /$/
             | 'ifoctetshistorymac' mac date_range(?) /$/
             | 'ifoctetshistoryuser' value date_range(?) /$/
             | 'ipmachistory' addr date_range(?) /$/
             | 'history' addr date(?) /$/
             | {main::usage()}

   service_options : service ('stop' | 'start' | 'restart' | 'status' | 'watch')
                    {[$item{service},$item[2]]}

   traplog_options: 'most' number ('day' | 'week' | 'total')

   manage_options : ('freemac' | 'deregister') macaddr | ('vclose'|'vopen') macaddr number | 'register' macaddr value edit_options(?)

   dashboard_options : 'recent_violations_opened' | 'recent_violations_closed' | 'current_grace' | 'recent_violations' | 'recent_registrations' | 'current_activity' | 'current_node_status'

   person_options : 'add' value person_edit_options(?)  | 'view' value | 'edit' value person_edit_options | 'delete' value

   nodecategory_options : 'view' nodecategory_id

   node_options : 'add' mac node_edit_options | 'count' (mac|node_filter) | 'view' (mac|node_filter) orderby_options(?) limit_options(?) | 'edit' mac node_edit_options | 'delete' mac
   
   switchlocation_options : 'view' ipaddr number

   violation_options : 'add' violation_edit_options | 'view' vid | 'edit' vid violation_edit_options | 'delete' vid 

   schedule_options : 'view' vid | 'now' host_range edit_options(?) | 'add' host_range edit_options | 'edit' number edit_options | 'delete' number

   class_options : 'view' vid 

   trigger_options : 'view' vid ('scan' | 'detect')(?)

   fingerprint_options : 'view' ('all' | /\d+(,\d+)*/)

   ui_options : 'file' '=' value

   service : 'pfmon' | 'pfdhcplistener' | 'pfdetect' | 'pfredirect' | 'snort' | 'httpd' | 'pfsetvlan' | 'snmptrapd' | 'pf'

   mac : 'all' | macaddr

   node_filter : ('category'|'pid') '=' value
                {push @{$main::cmd{'node_filter'}}, [$item[1],$item{value}] }

   limit_options : 'limit' /\d+/ ',' /\d+/

   orderby_options : 'order' 'by' node_view_field ('asc' | 'desc')(?)
   
   vid : 'all' | /\d+/

   addr : ipaddr | macaddr

   ipaddr : /(\d{1,3}\.){3}\d{1,3}/

   nodecategory_id : /[a-z]+/i

   host_range : /(\d{1,3}\.){3}\d{1,3}[\/\-0-9]*/

   macaddr : /(([0-9a-f]{2}[-:]){5}[0-9a-f]{2})|(([0-9a-f]{4}\.){2}[0-9a-f]{4})/i

   number : /\d+/
 
   edit_options : <leftop: assignment ',' assignment>

   date_range : 'start_time' '=' date ',' 'end_time' '=' date
                {push @{$main::cmd{$item[0]}}, [$item[1],$item[3],$item[2]], [$item[5],$item[7],$item[6]] }

   date : /[^,=]+/

   config_value : /.+/
   
   person_edit_options : <leftop: person_assignment ',' person_assignment>

   node_edit_options : <leftop: node_assignment ',' node_assignment>

   violation_edit_options : <leftop: violation_assignment ',' violation_assignment>

   assignment : columname '=' value
                {push @{$main::cmd{$item[0]}}, [$item{columname},$item{value},"="] } |
                columname '>' value
                {push @{$main::cmd{$item[0]}}, [$item{columname},$item{value},">"] } |
                columname '<' value
                {push @{$main::cmd{$item[0]}}, [$item{columname},$item{value},"<"] }

   person_assignment : person_view_field '=' value
                {push @{$main::cmd{$item[0]}}, [$item{person_view_field},$item{value}] }

   node_assignment : node_view_field '=' value
                {push @{$main::cmd{$item[0]}}, [$item{node_view_field},$item{value}] }

   violation_assignment : violation_view_field '=' value
                {push @{$main::cmd{$item[0]}}, [$item{violation_view_field},$item{value}] }

   class_assignment : class_view_field '=' value
                {push @{$main::cmd{$item[0]}}, [$item{class_view_field},$item{value}] }

   columname : /[a-z_]+/i

   value : '"' /[0-9a-zA-Z_\*\.\-\:_\;\@\ ]*/ '"' {$item[2]} | /[0-9a-zA-Z_\*\.\-\:_\;\@]+/

   person_view_field : 'pid' | 'notes'

   node_view_field :  'mac' | 'pid' | 'detect_date' | 'regdate' | 'unregdate' | 'lastskip' | 'status' | 'user_agent' | 'computername'  | 'notes' | 'last_arp' | 'last_dhcp' | 'dhcp_fingerprint' | 'switch' | 'port' | 'vlan'

   violation_view_field :  'id' | 'mac' | 'vid' | 'start_date' | 'release_date' | 'status' | 'notes'

   class_view_field :  'vid' | 'description' | 'auto_enable' | 'max_enables' | 'grace_period' | 'priority' | 'url' | 'max_enable_url' | 'redirect_url' | 'button_text' | 'disable'

   eofile: /^\Z/
};


sub usage {
  my $command = basename($0);
  if (defined $ARGV[0] && defined($main::{"help_".$ARGV[0]})){
   ($main::{"help_".$ARGV[0]} or sub { print "No such sub: help_".$ARGV[0]."\n"; })->(); 
   exit(1);  
  }

  print STDERR << "EOF";
Usage: $command <command> [options]

class           	| view violation classes
config          	| query, set, or get help on pf.conf configuration paramaters
fingerprint     	| view DHCP Fingerprints
graph           	| trending graphs 
history         	| IP/MAC history
ifoctetshistorymac    	| accounting history
ifoctetshistoryswitch 	| accounting history
ifoctetshistoryuser   	| accounting history
ipmachistory    	| IP/MAC history
locationhistorymac   	| Switch/Port history
locationhistoryswitch 	| Switch/Port history
lookup          	| node or pid lookup against local data store
node            	| node manipulation
nodecategory       	| nodecategory manipulation
graph           	| trending graphs 
person          	| person manipulation
reload          	| rebuild fingerprint or violations tables without restart
report          	| current usage reports
schedule        	| Nessus scan scheduling
service         	| start/stop/restart and get PF daemon status
switchlocation  	| view switchport description and location
traplog                 | update traplog RRD files and graphs or obtain switch IPs
trigger         	| view and throw triggers
ui              	| used by web UI to create menu hierarchies and dashboard
update          	| download canonical fingerprint or OUI data
version         	| get installed PF version and database MD5s
violation       	| violation manipulation

Please view "$command help <command>" for details on each option
EOF
  exit;
}

1
