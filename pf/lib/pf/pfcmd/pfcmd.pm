#
# Copyright 2005 David LaPorte <david@davidlaporte.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
# Copyright 2008-2009 Inverse groupe conseil <dgehl@inverse.ca>
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
      }elsif ($val ne '') { push @{$main::cmd{$item[0]}},$val; }
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
           { 1; }

   command : 'node' node_options
             | 'person' person_options
             | 'switchconfig' switchconfig_options
             | 'violation' violation_options
             | 'trigger' 'view' vid ('scan' | 'detect')(?)
             | 'ui' 'menus' ui_options(?)
             | 'ui' 'dashboard' ('recent_violations_opened' | 'recent_violations_closed' | 'recent_violations' | 'recent_registrations') (/\d+/)(?)
             | 'ui' 'dashboard' ('current_grace' | 'current_activity' | 'current_node_status')
             | 'fingerprint' 'view' ('all' | /\d+(,\d+)*/)
             | 'config' ('get' | 'set' | 'help') /.+/
             | 'manage' manage_options
             | 'graph' ('unregistered' | 'registered' | 'violations' | 'nodes') ('day'|'month'|'year')(?)
             | 'graph' 'ifoctetshistoryswitch' ipaddr /\d+/ date_range 
             | 'graph' 'ifoctetshistorymac' macaddr date_range 
             | 'graph' 'ifoctetshistoryuser' value date_range 
             | 'schedule' schedule_options
             | 'traplog' ('update' | traplog_options)
             | 'locationhistoryswitch' ipaddr /\d+/ date(?)
             | 'locationhistorymac' macaddr date(?)
             | 'ifoctetshistoryswitch' ipaddr /\d+/ date_range(?)
             | 'ifoctetshistorymac' macaddr date_range(?)
             | 'ifoctetshistoryuser' value date_range(?)
             | 'ipmachistory' (ipaddr|macaddr) date_range(?)
             | 'history' (ipaddr|macaddr) date(?)

   traplog_options: 'most' /\d+/ ('day' | 'week' | 'total')

   manage_options : ('freemac' | 'deregister') macaddr | ('vclose'|'vopen') macaddr /\d+/ | 'register' macaddr value edit_options(?)

   person_options : 'add' value person_edit_options(?)  | 'view' value | 'edit' value person_edit_options | 'delete' value

   node_options : 'add' mac node_edit_options | 'count' (mac|node_filter) | 'view' (mac|node_filter) orderby_options(?) limit_options(?) | 'edit' macaddr node_edit_options | 'delete' macaddr

   switchconfig_options: 'edit' ('default'|ipaddr) switchconfig_edit_options

   violation_options : 'add' violation_edit_options | 'view' vid | 'edit' /\d+/ violation_edit_options | 'delete' /\d+/ 

   schedule_options : 'view' vid | 'now' host_range edit_options(?) | 'add' host_range edit_options | 'edit' /\d+/ edit_options | 'delete' /\d+/

   ui_options : 'file' '=' value

   mac : 'all' | macaddr

   node_filter : ('category'|'pid') '=' value
                {push @{$main::cmd{'node_filter'}}, [$item[1],$item{value}] }

   limit_options : 'limit' /\d+/ ',' /\d+/

   orderby_options : 'order' 'by' node_view_field ('asc' | 'desc')(?)
   
   vid : 'all' | /\d+/

   ipaddr : /(\d{1,3}\.){3}\d{1,3}/

   host_range : /(\d{1,3}\.){3}\d{1,3}[\/\-0-9]*/

   macaddr : /(([0-9a-f]{2}[-:]){5}[0-9a-f]{2})|(([0-9a-f]{4}\.){2}[0-9a-f]{4})/i

   date_range : 'start_time' '=' date ',' 'end_time' '=' date
                {push @{$main::cmd{$item[0]}}, [$item[1],$item[3],$item[2]], [$item[5],$item[7],$item[6]] }

   date : /[^,=]+/

   edit_options : <leftop: assignment ',' assignment>

   switchconfig_edit_options : <leftop: switchconfig_assignment ',' switchconfig_assignment>

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

   switchconfig_assignment : switchconfig_view_field '=' value
                {push @{$main::cmd{$item[0]}}, [$item{switchconfig_view_field},$item{value}] }

   node_assignment : node_view_field '=' value
                {push @{$main::cmd{$item[0]}}, [$item{node_view_field},$item{value}] }

   violation_assignment : violation_view_field '=' value
                {push @{$main::cmd{$item[0]}}, [$item{violation_view_field},$item{value}] }

   columname : /[a-z_]+/i

   value : '"' /[\/,0-9a-zA-Z_\*\.\-\:_\;\@\ ]*/ '"' {$item[2]} | /[\/0-9a-zA-Z_\*\.\-\:_\;\@]+/

   person_view_field : 'pid' | 'notes'

   node_view_field :  'mac' | 'pid' | 'detect_date' | 'regdate' | 'unregdate' | 'lastskip' | 'status' | 'user_agent' | 'computername'  | 'notes' | 'last_arp' | 'last_dhcp' | 'dhcp_fingerprint' | 'switch' | 'port' | 'vlan'

   switchconfig_view_field : 'type' | 'mode' | 'uplink'

   violation_view_field :  'id' | 'mac' | 'vid' | 'start_date' | 'release_date' | 'status' | 'notes'

   eofile: /^\Z/
};



1
