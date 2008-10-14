<?
  $current_top = 'node';
  $current_sub = 'edit';

  include('../common.php');
?>

<head>
  <title>// packetfence //</title>
  <link rel="shortcut icon" href="/favicon.ico"> 
  <link rel="stylesheet" href="../style.php" type="text/css">
</head>

<body class=add>

<?
  $edit_item = set_default($_REQUEST['item'], '');

  if($_POST){
    $edit_cmd = "$current_top edit $edit_item ";
    foreach($_POST as $key => $val){
      $parts[] = "$key=\"$val\""; 
    }
    $edit_cmd.=implode(", ", $parts);

    PFCMD($edit_cmd);
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

    $pretty_key = pretty_header("$current_top-view", $key);
    if($key == 'status'){
      print "<tr><td></td><td>$pretty_key:</td><td>";
      printSelect( array('unreg' => 'Unregistered', 'reg' => 'Registered', 'grace' => 'Grace'), 'hash', $val, "name='$key'");
    }
    else{
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
