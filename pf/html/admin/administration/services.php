<?php
/**
 * @licence http://opensource.org/licenses/gpl-2.0.php GPL
 */


  $current_top="administration";
  $current_sub="services";

  require_once('../common.php');
  include_once('../header.php');

  if(isset($_GET['service']) && isset($_GET['action'])){
    PFCMD("service {$_GET['service']} {$_GET['action']}");
  }

?>

<div id=status> 
<table width=90% align=center>
  <tr class=header>
    <td class=header width=30px align=center>System</td>
    <td class=header align=center>Services</td>
  </tr>
  <tr class=content>
    <td class=system><img src="../images/wire.png"><br><?system('uname -n')?></td>
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
          print "<td>" . (($services[2] == 0) ? 'Stopped' : 'Running') . "</td>\n";
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
  print "<td align=center><a href=$current_top/$current_sub.php?service=pf&action=restart><img src='images/restart.png' title='Restart All' border=0></a></td>";
  print "</tr>\n";
  print "</table>";

}



?>
