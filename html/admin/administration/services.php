<?php
/**
 * TODO short desc
 *
 * TODO long desc
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
 * USA.
 * 
 * @author      Dominik Gehl <dgehl@inverse.ca>
 * @copyright   2008-2010 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

  $current_top="administration";
  $current_sub="services";

  require_once('../common.php');
  include_once('../header.php');

  if(isset($_POST['service']) && isset($_POST['action'])){
    PFCMD("service {$_POST['service']} {$_POST['action']}");
  }

  $configs = PFCMD('config get all');
  $hostname = get_configuration_value('general.hostname');
  $domainname = get_configuration_value('general.domain');

  $checkup = PFCMD('checkup');
?>

<div id=status> 
<table width=90% align=center>
  <tr class=header>
    <td class=header width=30px align=center>System</td>
    <td class=header align=center>Services</td>
  </tr>
  <tr class=content>
    <td class=system><img src="../images/wire.png"><br><?php echo "$hostname.$domainname"; ?></td>
    <td class=services>
        <? print_status_table() ?>
    </td>
  </tr>
  <tr class=header>
    <td class=header colspan=2 align=center>Configuration check-up</td>
  </tr>
  <tr class=content>
    <td class=checkup colspan=2 align=center>
    <?php
      if($checkup) {
        ?><textarea rows=10 cols=100 disabled name=checkup><?php
        foreach($checkup as $line) {
          print "$line\n";
        }
        ?></textarea><?php
      } else {
        ?><p align=center>Configuration checkup failed.</p><?php
      }
    ?>
    </td>
  </tr>
</table>
</div>

<?

include_once('../footer.php');

function print_status_table(){
  global $current_top;
  global $current_sub;

  $ordered_service_list=array('pfdetect', 'pfdhcplistener', 'pfmon', 'pfredirect', 'line', 'named', 'dhcpd', 'radiusd', 'pfsetvlan', 'snmptrapd', 'line', 'snort', 'suricata');
  $data=array_slice(PFCMD('service pf status'), 1); // sliced to get rid of headers
  print "<table width=75% align=center>";
  print "<tr><td><b>Service</b></td><td><b>Expected Status</b></td><td><b>Actual Status</b></td><td colspan=3 align=center><b>Action</b></td></tr>";
  

  foreach ($ordered_service_list as $current_service) {
    if ($current_service == 'line') {
      print "<tr><td colspan=6><hr></td></tr>\n";
    } else {
      foreach($data as $line){
        $services=preg_split("/\|/",$line);

        if ($services[0] == $current_service) {
          print "<tr>\n";
          print "  <td";
          if ($services[1] == 1) {
            if ($services[2] == 0) {
              print " style=\"color:red\"";
            } else {
              print " style=\"color:green\"";
            }
          }
          print ">$services[0]</td>\n";
          print "<td>" . (($services[1] == 0) ? 'Stopped' : 'Running') . "</td>\n";
          print "<td>" . (($services[2] == 0) ? 'Stopped' : 'Running (pid: ' . $services[2] . ')') . "</td>\n";
          if (($services[1] == 1) && ($services[2] == 0)) {
            print "<td align=center>";
            image_button(
                "$current_top/$current_sub.php", array( 'service' => $services[0], 'action' => 'start'), 
                'images/start.png', "Start $services[0]"
            );
            print "</td>\n";
          } else {
            print "<td>&nbsp;</td>\n";
          }
          if (($services[1] == 1) && ($services[2] != 0)) {
            print "<td align=center>";
            image_button(
                "$current_top/$current_sub.php", array( 'service' => $services[0], 'action' => 'stop' ), 
                'images/stop.png', "Stop $services[0]"
            );
            print "</td>\n";

            print "<td align=center>";
            image_button(
                "$current_top/$current_sub.php", array( 'service' => $services[0], 'action' => 'restart'), 
                'images/restart.png', "Restart $services[0]"
            );
            print "</td>\n";
          } else {
            print "<td>&nbsp;</td>\n";
            print "<td>&nbsp;</td>\n";
          }
          print "</tr>\n";    
        }
      }
    }
  }
  
  print "<tr><td colspan=6><hr></td></tr>\n";
  print "<tr>\n";
  print "<td>All Services</td>\n";
  print "<td>&nbsp;</td>\n";
  print "<td>&nbsp;</td>\n";
  print "<td align=center>&nbsp;</td>\n";
  print "<td align=center>";
  image_button(
      "$current_top/$current_sub.php", array( 'service' => 'pf', 'action' => 'stop' ), 
      'images/stop.png', "Stop All"
  );
  print "</td>\n";
  print "<td align=center>&nbsp;</td>";
  print "</tr>\n";
  print "</table>";

}



?>
