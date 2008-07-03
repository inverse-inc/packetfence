<?

  $current_top="administration";
  $current_sub="services";

  require_once('../common.php');
  include_once('../header.php');

  if(isset($_GET['service']) && isset($_GET['action'])){
    PFCMD("control {$_GET['service']} {$_GET['action']}");
  }

?>

<div id=status> 
<table width=90% align=center>
  <tr class=header>
    <td class=header width=30px align=center>System</td>
    <td class=header align=center>Services</td>
  </tr>
  <tr class=content>
    <td class=system><img src="images/wire.jpg"><br><?system('uname -n')?></td>
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

  $data=array_slice(PFCMD('service pf'), 1); // sliced to get rid of headers
  print "<table width=75% align=center>";
  print "<tr><td align=center><b>Service (status)</b></td><td colspan=2 align=center><b>Action</b></td></tr>";
  

  foreach($data as $line){
    $services=preg_split("/\|/",$line);

    print "<tr>";
    if($services[2] == 0){
      print "<td><font color=red>$services[0] (stopped)</font></td>";
      print "<td align=center><a href=$current_top/$current_sub.php?service=$services[0]&action=start><img src='images/start.png' title='Start $services[0]' border=0></a></td>";
    }
    else{
      print "<td><font color=green>$services[0] (running)</font></td>";
      print "<td align=center><a href=$current_top/$current_sub.php?service=$services[0]&action=stop><img src='images/stop.png' title='Stop $services[0]' border=0></a></td><td align=center><a href=$current_top/$current_sub.php?service=$services[0]&action=restart><img src='images/restart.png' title='Restart $services[0]' border=0></a></td>";
    }
    print "</tr>";    
  }
  
  print "<tr>";
  print "<td>All Services</td>";
  print "<td align=center><a href=$current_top/$current_sub.php?service=pf&action=stop><img src='images/stop.png' title='Stop All' border=0></a></td><td align=center><a 
href=$current_top/$current_sub.php?service=pf&action=start><img src='images/start.png' title='Start All' border=0></a></td><td align=center><a href=$current_top/$current_sub.php?service=pf&action=restart><img src='images/restart.png' title='Restart All' border=0></a></td>";

  print "</table>";

}



?>
