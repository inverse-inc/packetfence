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
 * @copyright   2008-2011, 2012 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

  $current_top = 'configuration';
  $current_sub = 'interfaces';

  include('../common.php');
?>

<html>
<head>
  <title>PF::Configuration::Interfaces::Edit</title>
  <link rel="shortcut icon" href="/favicon.ico"> 
  <link rel="stylesheet" href="../style.css" type="text/css">
</head>

<body class="popup">

<?
  perform_access_control_in_popup();

  $edit_item = set_default($_REQUEST['item'], '');

  if($_POST){
    $edit_cmd = "interfaceconfig edit $edit_item ";
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

  $edit_info = new table("interfaceconfig get $edit_item");

  print "<form name='edit' method='post' action='/$current_top/" . $current_sub . "_edit.php?item=$edit_item'>";
  print "<div id='add'><table>";
  print "<tr><td><img src='../images/node.png'></td><td valign='middle' colspan=2><b>Editing: ".$edit_info->rows[0]['interface']."</b></td></tr>";
  foreach($edit_info->rows[0] as $key => $val){
    if($key == $edit_info->key){
      continue;
    }
    if($key == "interface") {
      continue;
    }

    $pretty_key = pretty_header("configuration-interfaces", $key);
    switch($key) {
      case 'type':
        print "<tr><td></td><td>$pretty_key:</td><td>";
        print "\n<select multiple name='$key" .  "[]'>";
        # migrating deprecated values: managed -> management, dhcplistener -> dhcp-listener
        foreach (explode(",", $val) as $value) {
          switch ($value) {
            case 'managed':
              $my_values[] = 'management';
              break;

            case 'dhcplistener':
              $my_values[] = 'dhcp-listener';
              break;

            default:
              $my_values[] = $value;
          }
        }
        $my_options = array(
          'dhcp-listener' => 'dhcp-listener', 
          'external' => 'external',
          'high-availability' => 'high-availability',
          'internal' => 'internal', 
          'management' => 'management', 
          'monitor' => 'monitor'
        );
        foreach ($my_options as $option_val => $option_txt) {
          if (in_array($option_val, $my_values)) {
            print "<option value='$option_val' SELECTED>$option_txt</option>\n";
          } else {
            print "<option value='$option_val'>$option_txt</option>\n";
          }
        }
        print "</select>\n";
        break;

      case 'enforcement':
        print "<tr><td></td><td>$pretty_key:</td><td>";
        printSelect(
          array('' => 'only if type internal', 'vlan' => 'VLAN', 'inline' => 'Inline'), 
          'hash', $val, "name='$key'"
        );
        break;

      default:
        print "<tr><td></td><td>$pretty_key:</td><td><input type='text' name='$key' value='$val'>";
        break;

    }
    print "</td></tr>";
  }
  print "<tr><td colspan=3 align=right><input type='submit' value='Edit ".ucfirst($current_top)."'></td></tr>";
  print "</table></div>";
  print "</form>";
?>

</body>
</html>
