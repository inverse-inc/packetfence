<?
  $current_top = 'configuration';
  $current_sub = 'networks';

  include('../common.php');
?>

<html>
<head>
  <title>PF::Configuration::Networks::Add</title>
  <link rel="shortcut icon" href="/favicon.ico"> 
  <link rel="stylesheet" href="../style.css" type="text/css">
</head>

<body class="popup">

<?
  $edit_item = set_default($_REQUEST['item'], '');

  if($_POST){
    foreach($_POST as $key => $val){
      if ($key == 'network') {
        $edit_item = $val;
      } else {
        if (is_array($val)) {
          $parts[] = "$key=\"" . join(",", $val) . "\"";
        } else {
          $parts[] = "$key=\"$val\""; 
        }
      }
    }
    $edit_cmd = "networkconfig add $edit_item ";
    $edit_cmd.=implode(", ", $parts);

    PFCMD($edit_cmd);
    $edited=true; 
    print "<script type='text/javascript'>opener.focus(); opener.location.href = opener.location; self.close();</script>";

  }

  $edit_info = new table("networkconfig get $edit_item");

  print "<form name='edit' method='post' action='/$current_top/" . $current_sub . "_add.php?item=$edit_item'>";
  print "<div id='add'><table>";
  print "<tr><td><img src='../images/node.png'></td><td valign='middle' colspan=2><b>Adding new network:</b></td></tr>";
  foreach($edit_info->rows[0] as $key => $val){
    if($key == $edit_info->key){
      continue;
    }
    if($key == "network") {
      $val = '';
    }

    $pretty_key = pretty_header("configuration-networks", $key);
    if ($key == 'type') {
      print "<tr><td></td><td>$pretty_key:</td><td>";
      printSelect( array('' => 'please choose',
                         'isolation' => 'Isolation',
                         'registration' => 'Registration',
                    ),
                   'hash', $val, "name='$key'");
    } else {
      print "<tr><td></td><td>$pretty_key:</td><td><input type='text' name='$key' value='$val'>";
    }

    if(($key == 'regdate')||($key == 'unregdate')){
      $now = date('Y-m-d H:i:s');
      print  " <img src='../images/date.png' onClick=\"document.edit.$key.value='$now';return false;\" title='Insert Current Time' style='cursor:pointer;'>";
    }

    print "</td></tr>";
  }
  print "<tr><td colspan=3 align=right><input type='submit' value='Add network'></td></tr>";
  print "</table></div>";
  print "</form>";
?>

</html>
