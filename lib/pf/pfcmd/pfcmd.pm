=head1 NAME

pfcmd grammar


=head1 DESCRIPTION

bin/pfcmd command-line parser.
It is not used directly, we precompile it in advance so it's faster to load.

NOTE: always remember that this file is only part of the story, lib/pf/pfcmd.pm is always parsed first!

=head1 MANUAL PRECOMPILE

The grammar is usually compiled by the RPM install process 
however if you do any modifications on your own you might want to precompile it again youself.

To do so, from /usr/local/pf/, run: 

  /usr/bin/perl -w -e "use strict; use warnings; use Parse::RecDescent; use lib \"./lib\"; use pf::pfcmd::pfcmd; Parse::RecDescent->Precompile(\$grammar, \"pfcmd_pregrammar\");"

Then put the resulting pfcmd_pregrammar.pm file in /usr/local/pf/lib/pf/pfcmd/

For more information about the grammar syntax: http://search.cpan.org/~dconway/Parse-RecDescent-1.96.0/lib/Parse/RecDescent.pm#DESCRIPTION

=cut

use strict;
use warnings;

use vars qw/%cmd $grammar/;

$::RD_AUTOACTION = q {
  if ($#item>1 ){
   foreach my $val (@item[1..$#item]){
      if (ref($val) eq 'ARRAY') {
        push @{$main::cmd{$item[0]}},@{$val};
      }elsif ($val ne '') { push @{$main::cmd{$item[0]}},$val; }
   }
  }elsif ($#item==1){$item[1]}
};

$grammar = q {
   start : command eofile
           { 1; }

   command : 'node' node_options
             | 'nodecategory' nodecategory_options
             | 'person' person_options
             | 'interfaceconfig' interfaceconfig_options
             | 'networkconfig' networkconfig_options
             | 'switchconfig' switchconfig_options
             | 'floatingnetworkdeviceconfig' floatingnetworkdeviceconfig_options
             | 'violationconfig' violationconfig_options
             | 'violation' violation_options
             | 'manage' manage_options
             | 'schedule' schedule_options

   manage_options : 'register' macaddr pid edit_options(?)

   person_options : 'add' pid person_edit_options(?)  | 'edit' pid person_edit_options | 'delete' value

   node_options : 'add' macaddr node_edit_options | 'edit' macaddr node_edit_options 

   # nodecategory add is without an id and edit is with one
   nodecategory_options : 'add' nodecategory_edit_options | 'edit' /\d+/ nodecategory_edit_options | 'delete' /\d+/

   interfaceconfig_options: ('add' | 'edit') (/[^ ]+/) interfaceconfig_edit_options

   networkconfig_options: ('add' | 'edit') ipaddr networkconfig_edit_options

   switchconfig_options: ('add' | 'edit') ('default'|ipaddr) switchconfig_edit_options

   floatingnetworkdeviceconfig_options: ('add' | 'edit') macaddr floatingnetworkdeviceconfig_edit_options

   violationconfig_options: ('add' | 'edit') ('defaults'|/\d+/) violationconfig_edit_options

   violation_options : 'add' violation_edit_options | 'edit' /\d+/ violation_edit_options | 'delete' /\d+/ 

   schedule_options : 'now' host_range edit_options(?) | 'add' host_range edit_options | 'edit' /\d+/ edit_options

   mac : 'all' | macaddr

   ipaddr : /(\d{1,3}\.){3}\d{1,3}/

   host_range : /(\d{1,3}\.){3}\d{1,3}[\/\-0-9]*/

   macaddr : /(([0-9a-f]{2}[-:]){5}[0-9a-f]{2})|(([0-9a-f]{4}\.){2}[0-9a-f]{4})/i

   date : /[^,=]+/

   # another pid regex is also defined in pf::pfcmd. Make sure to maintain both.
   pid: '"' /[&=?()\/,0-9a-zA-Z_\*\.\-\:\;\@\ \+\!\^\[\]\|\#\\\\]+/ '"' {$item[2]} | /[a-zA-Z0-9\-\_\.\@\/\:\+\!,]+/

   edit_options : <leftop: assignment ',' assignment>

   interfaceconfig_edit_options : <leftop: interfaceconfig_assignment ',' interfaceconfig_assignment>

   networkconfig_edit_options : <leftop: networkconfig_assignment ',' networkconfig_assignment>

   switchconfig_edit_options : <leftop: switchconfig_assignment ',' switchconfig_assignment>

   floatingnetworkdeviceconfig_edit_options : <leftop: floatingnetworkdeviceconfig_assignment ',' floatingnetworkdeviceconfig_assignment>

   violationconfig_edit_options : <leftop: violationconfig_assignment ',' violationconfig_assignment>

   person_edit_options : <leftop: person_assignment ',' person_assignment>

   node_edit_options : <leftop: node_assignment ',' node_assignment>

   nodecategory_edit_options : <leftop: nodecategory_assignment ',' nodecategory_assignment>

   violation_edit_options : <leftop: violation_assignment ',' violation_assignment>

   assignment : columname '=' value
                {push @{$main::cmd{$item[0]}}, [$item{columname},$item{value},"="] } |
                columname '>' value
                {push @{$main::cmd{$item[0]}}, [$item{columname},$item{value},">"] } |
                columname '<' value
                {push @{$main::cmd{$item[0]}}, [$item{columname},$item{value},"<"] }

   person_assignment : person_view_field '=' value
                {push @{$main::cmd{$item[0]}}, [$item{person_view_field},$item{value}] }

   interfaceconfig_assignment : interfaceconfig_view_field '=' value
                {push @{$main::cmd{$item[0]}}, [$item{interfaceconfig_view_field},$item{value}] }

   networkconfig_assignment : networkconfig_view_field '=' value
                {push @{$main::cmd{$item[0]}}, [$item{networkconfig_view_field},$item{value}] }

   switchconfig_assignment : 
       switchconfig_view_field '=' value 
           {push @{$main::cmd{$item[0]}}, [$item{switchconfig_view_field},$item{value}] }
       |
       switchconfig_password_field '=' password
           {push @{$main::cmd{$item[0]}}, [$item{switchconfig_password_field},$item{password}] }


   floatingnetworkdeviceconfig_assignment : floatingnetworkdeviceconfig_view_field '=' value
                {push @{$main::cmd{$item[0]}}, [$item{floatingnetworkdeviceconfig_view_field},$item{value}] }

   violationconfig_assignment : violationconfig_view_field '=' value
                {push @{$main::cmd{$item[0]}}, [$item{violationconfig_view_field},$item{value}] }

   node_assignment : node_view_field '=' value {push @{$main::cmd{$item[0]}}, [$item{node_view_field},$item{value}] }
                     | 'pid' '=' pid {push @{$main::cmd{$item[0]}}, ['pid',$item{pid}] }

   nodecategory_assignment : nodecategory_view_field '=' value
                {push @{$main::cmd{$item[0]}}, [$item{nodecategory_view_field},$item{value}] }

   violation_assignment : violation_view_field '=' value
                {push @{$main::cmd{$item[0]}}, [$item{violation_view_field},$item{value}] }

   columname : /[a-z_]+/i

   value : '"' /[&=?()\/,0-9a-zA-Z_\*\.\-\:_\;\@\ \+\!]*/ '"' {$item[2]} | /[\/0-9a-zA-Z_\*\.\-\:_\;\@]+/

   # allowing more chars as passwords
   password : '"' /[&=?()\/,0-9a-zA-Z_\*\.\-\:_\;\@\ \+\!\$]*/ '"' {$item[2]} | /[\/0-9a-zA-Z_\*\.\-\:_\;\@\$]+/

   person_view_field : 'pid' | 'firstname' | 'lastname' | 'email' | 'telephone' | 'company' | 'address' | 'notes' | 'sponsor'

   node_view_field : 'mac' | 'pid' | 'category' | 'detect_date' | 'regdate' | 'unregdate' | 'lastskip' | 'status' | 'user_agent' | 'computername'  | 'notes' | 'last_arp' | 'last_dhcp' | 'dhcp_fingerprint' | 'voip' | 'bypass_vlan'

   nodecategory_view_field :  'name' | 'max_nodes_per_pid' | 'notes'

   interfaceconfig_view_field : 'interface' | 'ip' | 'mask' | 'type' | 'enforcement' | 'vip'

   networkconfig_view_field : 'type' | 'netmask' | 'named' | 'dhcpd' | 'gateway' | 'domain-name' | 'dns' | 'dhcp_start' | 'dhcp_end' | 'dhcp_default_lease_time' | 'dhcp_max_lease_time' | 'pf_gateway' | 'next_hop' | 'nat'

   switchconfig_view_field : 'type' | 'mode' | 'uplink' | 'SNMPVersionTrap' | 'SNMPVersion' | 'cliTransport' | 'cliUser' | 'wsTransport' | 'wsUser' | 'vlans' | 'normalVlan' | 'registrationVlan' | 'isolationVlan' | 'macDetectionVlan' | 'guestVlan' | /customVlan\d\d?/ | 'macSearchesMaxNb' | 'macSearchesSleepInterval' | 'VoIPEnabled' | 'voiceVlan' | 'SNMPEngineID' | 'SNMPUserNameRead' | 'SNMPAuthProtocolRead' | 'SNMPPrivProtocolRead' | 'SNMPUserNameWrite' | 'SNMPAuthProtocolWrite' | 'SNMPPrivProtocolWrite' | 'SNMPUserNameTrap' | 'SNMPAuthProtocolTrap' | 'SNMPPrivProtocolTrap' | 'controllerIp' | 'roles' | 'inlineTrigger' | 'inlineVlan' | 'deauthMethod'

   switchconfig_password_field : 'SNMPCommunityRead' | 'SNMPCommunityWrite' | 'SNMPCommunityTrap' | 'cliPwd' | 'cliEnablePwd' | 'wsPwd' | 'SNMPAuthPasswordRead' | 'SNMPPrivPasswordRead' | 'SNMPAuthPasswordWrite' | 'SNMPPrivPasswordWrite' | 'SNMPAuthPasswordTrap' | 'SNMPPrivPasswordTrap' | 'radiusSecret'

   floatingnetworkdeviceconfig_view_field : 'ip' | 'trunkPort' | 'pvid' | 'taggedVlan'

   violationconfig_view_field : 'desc' | 'enabled' | 'auto_enable' | 'actions' | 'max_enable' | 'grace' | 'window' | 'vclose' | 'priority' | 'url' | 'button_text' | 'trigger' | 'vlan' | 'whitelisted_categories'

   violation_view_field :  'id' | 'mac' | 'vid' | 'start_date' | 'release_date' | 'status' | 'notes'

   eofile: /^\Z/
};

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
