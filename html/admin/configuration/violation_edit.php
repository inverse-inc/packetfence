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

  $current_top = 'configuration';
  $current_sub = 'violation';

  include('../common.php');
?>

<html>
<head>
  <title>PF::Configuration::Violation::Edit</title>
  <link rel="shortcut icon" href="/favicon.ico"> 
  <link rel="stylesheet" href="../style.css" type="text/css">
</head>

<body class="popup">

<?
  perform_access_control_in_popup();

  $edit_item = set_default($_REQUEST['item'], '');

  if($_POST){
    $edit_cmd = "violationconfig edit $edit_item ";
    foreach($_POST as $key => $val){
      if (is_array($val)) {
        $parts[] = "$key=\"" . join(",", $val) . "\""; 
      } else {
        $parts[] = "$key=\"$val\""; 
      }
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
    print "<script type='text/javascript'>opener.focus(); opener.location.href = opener.location; self.close();</script>";

  }

  $edit_info = new table("violationconfig get $edit_item");

  print "<form name='edit' method='post' action='/$current_top/" . $current_sub . "_edit.php?item=$edit_item'>";
  print "<div id='add'><table>";
  print "<tr><td><img src='../images/violation.png'></td><td valign='middle' colspan=2><b>Editing: ".$edit_info->rows[0]['desc']."</b></td></tr>";
  foreach($edit_info->rows[0] as $key => $val){
    if($key == $edit_info->key){
      continue;
    }
    if($key == "vid") {
      continue;
    }

    $pretty_key = pretty_header("configuration-violation", $key);
    if (($key == 'enabled') || ($key == 'auto_enable')) {
      print "<tr><td></td><td>$pretty_key:</td><td>";
      printSelect( array('Y' => 'Yes', 'N' => 'No'), 'hash', $val, "name='$key'");
    } elseif ($key == 'actions') {
      print "<tr><td></td><td>$pretty_key:</td><td>";
      # TODO: port to printMultiSelect (and look for others to port too)
      print "\n<select multiple name='$key" .  "[]'>";
      $my_values = explode(",", $val);
      $my_options = array('autoreg' => 'Autoreg', 'close' => 'Close', 'email' => 'Email', 'log' => 'Log', 'trap' => 'Trap');
      foreach ($my_options as $option_val => $option_txt) {
        if (in_array($option_val, $my_values)) {
          print "<option value='$option_val' SELECTED>$option_txt</option>\n";
        } else {
          print "<option value='$option_val'>$option_txt</option>\n";
        }
      }
      print "</select>\n";
    } elseif ($key == 'whitelisted_categories') {
        print "<tr><td></td><td>$pretty_key:</td><td>";
        $selected = explode(",", $val);
        printMultiSelect(get_nodecategories_for_dropdown(), 'hash', $selected, "multiple name='{$key}[]'");
    } elseif ($key == 'trigger') {
      print "<tr><td></td><td>$pretty_key:</td><td><textarea name='$key'>$val</textarea>";
    } elseif ($key == 'vclose') {
      $vids_pfcmd=PFCMD("class view all");

      foreach($vids_pfcmd as $line){
        $parts=preg_split("/\|/", $line);
        $vids[]=array('vid' => $parts[2], 'desc' => $_SESSION['violation_classes'][$parts[2]]);
      }
      array_shift($vids);
      print "<tr><td></td><td>$pretty_key:</td><td><select name='$key'>\n";
      foreach($vids as $vid) {
        print "      <option value='$vid[vid]'>$vid[desc] ($vid[vid])</option>\n";
      }
      print "</select>\n";

    } else {
      print "<tr><td></td><td>$pretty_key:</td><td><input type='text' name='$key' value='$val'>";
    }

    print "</td></tr>";
  }
  print "<tr><td colspan=3 align=right><input type='submit' value='Edit ".ucfirst($current_top)."'></td></tr>";
  print "</table></div>";
  print "</form>";
?>

</body>
</html>
