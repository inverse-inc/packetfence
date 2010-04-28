<?php
/**
 * @licence http://opensource.org/licenses/gpl-2.0.php GPL
 */

  $current_top = 'configuration';
  $current_sub = 'violation';

  include('../common.php');
?>

<html>
<head>
  <title>PF::Configuration::Violation::Add</title>
  <link rel="shortcut icon" href="/favicon.ico"> 
  <link rel="stylesheet" href="../style.css" type="text/css">
</head>

<body class="popup">

<?
  $edit_item = set_default($_REQUEST['item'], '');

  if($_POST){
    foreach($_POST as $key => $val){
      if ($key == 'vid') {
        $edit_item = $val;
      } else {
        if (is_array($val)) {
          $parts[] = "$key=\"" . join(",", $val) . "\""; 
        } else {
          $parts[] = "$key=\"$val\""; 
        }
      }
    }
    $edit_cmd = "violationconfig add $edit_item ";
    $edit_cmd.=implode(", ", $parts);

    # I REALLLLYY mean false (avoids 0, empty strings and empty arrays to pass here)
    if (PFCMD($edit_cmd) === false) {
      # an error was shown by PFCMD now die to avoid closing the popup
      exit();
    }
    # no errors from pfcmd, go on
    $edited=true; 
    print "<script type='text/javascript'>opener.focus(); opener.location.href = opener.location; self.close();</script>";

  }

  $edit_info = new table("violationconfig get $edit_item");

  print "<form name='edit' method='post' action='/$current_top/" . $current_sub . "_add.php?item=$edit_item'>";
  print "<div id='add'><table>";
  print "<tr><td><img src='../images/violation.png'></td><td valign='middle' colspan=2><b>Adding new violation: </b></td></tr>";
  foreach($edit_info->rows[0] as $key => $val){
    if($key == $edit_info->key){
      continue;
    }
    if($key == "vid") {
      $val = '';
    }

    $pretty_key = pretty_header("configuration-violation", $key);
    if (($key == 'disable') || ($key == 'auto_enable')) {
      print "<tr><td></td><td>$pretty_key:</td><td>";
      printSelect( array('Y' => 'Yes', 'N' => 'No'), 'hash', $val, "name='$key'
");
    } elseif ($key == 'actions') {
      print "<tr><td></td><td>$pretty_key:</td><td>";
      # TODO: port to printMultiSelect (and look for others to port too)
      print "\n<select multiple name='$key" .  "[]'>";
      $my_values = explode(",", $val);
      $my_options = array('autoreg' => 'Autoreg', 'email' => 'Email', 'log' => 'Log', 'trap' => 'Trap');
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
    } else {
      print "<tr><td></td><td>$pretty_key:</td><td><input type='text' name='$key' value='$val'>";
    }

    if(($key == 'regdate')||($key == 'unregdate')){
      $now = date('Y-m-d H:i:s');
      print  " <img src='../images/date.png' onClick=\"document.edit.$key.value='$now';return false;\" title='Insert Current Time' style='cursor:pointer;'>";
    }

    print "</td></tr>";
  }
  print "<tr><td colspan=3 align=right><input type='submit' value='Add violation'></td></tr>";
  print "</table></div>";
  print "</form>";
?>

</html>
