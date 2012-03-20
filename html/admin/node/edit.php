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
 * @copyright   2008-2010 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

  $current_top = 'node';
  $current_sub = 'edit';

  include('../common.php');
?>

<html>
<head>
  <title>PF::Node::Edit</title>
  <link rel="shortcut icon" href="/favicon.ico"> 
  <link rel="stylesheet" href="../style.css" type="text/css">
  <!--[if IE]><link rel="stylesheet" type="text/css" href="../iefixes.css" /><![endif]-->
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
      # an error was shown by PFCMD now die to avoid closing the popup
      exit();
    }
    # no errors from pfcmd, go on
    $edited=true; 
    print "<script type='text/javascript'>opener.location.reload();window.close();</script>";

  }

  $edit_info = new table("$current_top view $edit_item");

  print "<form name='edit' method='post' action='/$current_top/edit.php?item=$edit_item'>";
  print "<div id='add'>";
  print "<div id='header'><p><img src='../images/node.png'><b>Editing: ".$edit_info->rows[0][$edit_info->key]."</b></p></div>";
  print "<div id='content'><table>";
  foreach($edit_info->rows[0] as $key => $val){
    if($key == $edit_info->key){
      continue;
    }
    if($key == "nbopenviolations") {
      continue;
    }

    $pretty_key = pretty_header("$current_top-view", $key);
    switch($key) {
    case 'status':
      print "<tr><td></td><td>$pretty_key:</td><td>";
      printSelect(get_node_status_for_dropdown(), 'hash', $val, "name='$key'");
      break;

    case 'category':
      print "<tr><td></td><td>$pretty_key:</td><td>";
      printSelect(get_nodecategories_for_dropdown(), 'hash', $val, "name='$key'");
      break;

    case 'voip':
      print "<tr><td></td><td>$pretty_key:</td><td>";
      printSelect( array('no' => 'No', 'yes' => 'Yes'), 'hash', $val, "name='$key'");
      break;

    case 'computername':
    case 'dhcp_fingerprint':
    case 'user_agent':
    case 'last_switch':
    case 'last_port':
    case 'last_vlan':
    case 'last_ssid':
    case 'last_dot1x_username':
      print "<tr><td></td><td>$pretty_key:</td><td><input type='text' name='$key' value='$val' disabled>";
      break;

    case 'last_connection_type':
      print "<tr><td></td><td>$pretty_key:</td><td><p title='$val' style='font-size: 0.7em;'>$connection_type[$val]</p>";
      break;

    case 'notes':
      print "<tr><td></td><td>$pretty_key:</td><td></td><tr><td colspan='3'><textarea name='$key' rows='5'>$val</textarea>";
      break;

    default:
      print "<tr><td></td><td>$pretty_key:</td><td><input type='text' name='$key' value='$val'>";
    }

    if(($key == 'regdate')||($key == 'unregdate')){
      $now = date('Y-m-d H:i:s');
      print  " <img src='../images/date.png' onClick=\"document.edit.$key.value='$now';return false;\" title='Insert Current Time' style='cursor:pointer;'>";
    }

    print "</td></tr>";
  }
  print "</table></div>";
  print "<div id='footer'><p><input type='submit' value='Edit ".ucfirst($current_top)."'/></p></div>";
  print "</div></form>";
?>

</html>
