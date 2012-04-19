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
 * @author      Olivier Bilodeau <obilodeau@inverse.ca>
 * @copyright   2008-2010, 2012 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

  $current_top = 'violation';
  $current_sub = 'edit';

  include('../common.php');
?>
<html>
<head>
  <title>PF::Violation::Edit</title>
  <link rel="shortcut icon" href="/favicon.ico"> 
  <link rel="stylesheet" href="../style.css" type="text/css">
</head>

<body class="popup">

<?
  perform_access_control_in_popup();

  $edit_item = set_default($_REQUEST['item'], '');

  if($_POST){
    $edit_cmd = "$current_top edit $edit_item ";
    foreach($_POST as $key => $val){
      $parts[] = "$key=\"$val\""; 
    }
    $edit_cmd.=implode(", ", $parts);

    # I REALLLLYY mean false (avoids 0, empty strings and empty arrays to pass here)
    if (PFCMD($edit_cmd) === false) {
      print_error($_error);
      close_popup_tags();
      exit();
    }
    # no errors from pfcmd, go on
    $edited=true; 
    print "<script type='text/javascript'>opener.location.reload();window.close();</script>";

  }

  $vids_pfcmd=PFCMD("class view all");

  foreach($vids_pfcmd as $line){
    $parts=preg_split("/\|/", $line);
    $vids[]=array('vid' => $parts[2], 'desc' => $_SESSION['violation_classes'][$parts[2]]);
  }
  array_shift($vids);

  $edit_info = new table("$current_top view $edit_item");

  print "<form name='edit' method='post' action='/$current_top/edit.php?item=$edit_item'>";
  print "<div id='add'><table>";
  print "<tr><td><img src='../images/violation.png' width=16 height=16></td><td valign='middle' colspan=2><b>Editing Violation ".$edit_info->rows[0]['id']."</b></td></tr>";
  foreach($edit_info->rows[0] as $key => $val){
    if(($key == 'id')||($key == 'computername')){
      continue;
    }

    $pretty_key = pretty_header("$current_top-view", $key);
    if($key == 'status'){
      print "<tr><td></td><td>$pretty_key:</td><td>";
      printSelect( array('open' => 'Open', 'closed' => 'Closed'), 'hash', $val, "name='$key'");
    } elseif ($key == 'vid') {
      print "<tr><td></td><td>$pretty_key:</td><td><select name='$key'>";
      foreach($vids as $vid) {
        print "      <option value='$vid[vid]'";
        if ($vid[vid] == $val) {
          print " selected";
        }
        print ">$vid[desc] ($vid[vid])</option>\n";
      }
      print "</select>";
    } elseif ($key == 'notes') {
      print "<tr><td></td><td>$pretty_key:</td><td></td></tr><tr><td colspan='3'><textarea name='$key' rows='5'>$val</textarea>";
    } else {
      print "<tr><td></td><td>$pretty_key:</td><td><input type='text' name='$key' value='$val'>";
    }

    if($key == 'start_date' || $key == 'release_date'){
      $now = date('Y-m-d H:i:s');
      print  " <img src='../images/date.png' onClick=\"document.edit.$key.value='$now';return false;\" title='Insert Current Time' style='cursor:pointer;'>";
    }

    print "</td></tr>";

  }
  print "<tr><td colspan=3 align=right><input type='submit' value='Edit ".ucfirst($current_top)."'></td></tr>";
  print "</table></div>";
  print "</form>";

?>
</body>
</html>
