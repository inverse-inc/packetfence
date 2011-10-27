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

  $current_top = 'person';
  $current_sub = 'edit';

  include('../common.php');
?>
<html>
<head>
  <title>PF::Person::Edit</title>
  <link rel="shortcut icon" href="/favicon.ico"> 
  <link rel="stylesheet" href="../style.css" type="text/css">
</head>

<body class="popup">

<?
  perform_access_control_in_popup();

  $edit_item = set_default($_REQUEST['item'], '');

  if($_POST){
    $edit_cmd = "$current_top edit \"$edit_item\" ";
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

  if (! preg_match("/^[a-zA-Z0-9\-\_\.\@]+$/", $edit_item)) {
    print "<div id='error' style='text-align:left;padding:10px;background:#FF7575;'><b>";
    print "Error: Username contains invalid characters";
    print "</b></div>\n";
    exit;
  }
  $edit_info = new table("$current_top view $edit_item");

  print "<form method='post' action='/$current_top/edit.php?item=$edit_item'>";
  print "<div id='add'><table>";
  print "<tr><td><img src='../images/person.png'></td><td valign='middle' colspan=2><b>Editing: ".$edit_info->rows[0][$edit_info->key]."</b></td></tr>";
  foreach($edit_info->rows[0] as $key => $val){
    if($key == $edit_info->key){
      continue;
    }

    $pretty_key = pretty_header("$current_top-view", $key);
    switch($key) {
    case 'notes':
      print "<tr><td></td><td>$pretty_key:</td><td></td></tr><tr><td colspan='3'><textarea name='$key' rows='5'>" 
            . htmlentities($val) . 
            "</textarea></td></tr>";
      break;

    default:
      print "<tr><td></td><td>$pretty_key:</td><td><input type='text' name='$key' value='"
            . htmlentities($val, ENT_QUOTES) . 
            "'></td></tr>";
    }
  }
  print "<tr><td colspan=3 align=right><input type='submit' value='Edit ".ucfirst($current_top)."'></td></tr>";
  print "</table></div>";
  print "</form>";

?>
</html>
