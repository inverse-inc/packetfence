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

  if(isset($_GET['service']) && isset($_GET['action'])){
    PFCMD("service {$_GET['service']} {$_GET['action']}");
  }

  $configs = PFCMD('config get all');
  $hostname = '';
  $domainname = '';
  foreach ($configs as $config) {
    $parts_ar=preg_split("/\|/",$config);
    $type = array_pop($parts_ar);
    $options_ar=preg_split("/=/", $parts_ar[0]);
    $pf_option=array_shift($options_ar);
    if ( ($pf_option == 'general.hostname')
        || ($pf_option == 'general.domain') ) {
        $value = implode("=", $options_ar);
        if (!$value) {
            $value = $pars_ar[1];
        }
        if ($pf_option == 'general.hostname') {
            $hostname = $value;
        } else {
            $domainname = $value;
        }
    }
  }
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
</table>
</div>

<?

include_once('../footer.php');

function print_status_table(){
  global $current_top;
  global $current_sub;

  $ordered_service_list=array('pfdetect', 'pfdhcplistener', 'pfmon', 'pfredirect', 'line', 'named', 'dhcpd', 'pfsetvlan', 'snmptrapd', 'line', 'snort');
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
            print "<td align=center><a href=$current_top/$current_sub.php?service=$services[0]&action=start><img src='images/start.png' title='Start $services[0]' border=0></a></td>";
          } else {
            print "<td>&nbsp;</td>\n";
          }
          if (($services[1] == 1) && ($services[2] != 0)) {
            print "<td align=center><a href=$current_top/$current_sub.php?service=$services[0]&action=stop><img src='images/stop.png' title='Stop $services[0]' border=0></a></td>\n";
            print "<td align=center><a href=$current_top/$current_sub.php?service=$services[0]&action=restart><img src='images/restart.png' title='Restart $services[0]' border=0></a></td>\n";
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
  print "<td align=center><a href=$current_top/$current_sub.php?service=pf&action=stop><img src='images/stop.png' title='Stop All' border=0></a></td>\n";
  print "<td align=center>&nbsp;</td>";
  print "</tr>\n";
  print "</table>";

}



?>
