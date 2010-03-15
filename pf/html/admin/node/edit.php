<?php
/**
 * @licence http://opensource.org/licenses/gpl-2.0.php GPL
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
</head>

<body class="popup">

<?
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
  print "<div id='add'><table>";
  print "<tr><td><img src='../images/node.png'></td><td valign='middle' colspan=2><b>Editing: ".$edit_info->rows[0][$edit_info->key]."</b></td></tr>";
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
      printSelect( array('unreg' => 'Unregistered', 'reg' => 'Registered', 'grace' => 'Grace'), 'hash', $val, "name='$key'");
      break;

    case 'voip':
      print "<tr><td></td><td>$pretty_key:</td><td>";
      printSelect( array('no' => 'No', 'yes' => 'Yes'), 'hash', $val, "name='$key'");
      break;

    case 'switch':
    case 'port':
      print "<tr><td></td><td>$pretty_key:</td><td><input type='text' name='$key' value='$val' disabled>";
      break;

    case 'connection_type':
      print "<tr><td></td><td>$pretty_key:</td><td><p title='$val' style='font-size: 0.7em;'>$connection_type[$val]</p>";
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
  print "<tr><td colspan=3 align=right><input type='submit' value='Edit ".ucfirst($current_top)."'></td></tr>";
  print "</table></div>";
  print "</form>";
?>

</html>
