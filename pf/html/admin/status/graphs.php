<?
  require_once('../common.php');

  $current_top="status";
  $current_sub="graphs";
  $is_printable=true;

  include_once('../header.php');

  jpgraph_check();

  $type = set_default($_GET['type'], 'nodes');
  $span = set_default($_GET['span'], 'day');

  $spanable = array('unregistered', 'violations', 'nodes');

  if(in_array($type, $spanable)){
    $pretty_type = pretty_header("$current_top-$current_sub", $type);
    if($span == 'day')
      $additional = "$pretty_type: <a href='$current_top/$current_sub.php?type=$type&span=day'><u>Daily</u></a> | <a href='$current_top/$current_sub.php?type=$type&span=month'>Monthly</a> | <a href='$current_top/$current_sub.php?type=$type&span=year'>Yearly</a>";
    else if($span == 'month')
      $additional = "$pretty_type: <a href='$current_top/$current_sub.php?type=$type&span=day'>Daily</a> | <a href='$current_top/$current_sub.php?type=$type&span=month'><u>Monthly</u></a> | <a href='$current_top/$current_sub.php?type=$type&span=year'>Yearly</a>";
    else
      $additional = "$pretty_type: <a href='$current_top/$current_sub.php?type=$type&span=day'>Daily</a> | <a href='$current_top/$current_sub.php?type=$type&span=month'>Monthly</a> | <a href='$current_top/$current_sub.php?type=$type&span=year'><u>Yearly</u></a>";
  }

  print helper_menu($current_top, $current_sub, $type, $_GET['menu'], $additional);

  if (($_REQUEST['type'] != "ifoctetshistoryuser") && ($_REQUEST['type'] != "ifoctetshistorymac") && ($_REQUEST['type'] != "ifoctetshistoryswitch")) {
    $img_src = "status/grapher.php?type=$type&span=$span";
    print "<div id=graph><img src='$img_src'></div>";  
  } elseif ($_REQUEST['type'] == "ifoctetshistoryuser") {
?>
  <div id="history">
  <form action="<?=$current_top?>/<?=$current_sub?>.php?type=<?=$type?>&menu=<?=$_GET[menu]?>" name="history" method="post">
  <table class="main">
     <tr>
        <td rowspan=4 valign=top style="width: 70px"><img src='images/report.png'></td>
        <td>User</td>
        <td>
          <select name="pid">
<?php
$person_lines = PFCMD("person view all");
array_shift($person_lines);
foreach($person_lines as $current_person_line){
  $pieces = explode('|', $current_person_line);
  print "            <option value=\"" .$pieces[0] . "\"" . ($pieces[0] == $_REQUEST['pid'] ? " selected" : '') . ">" . $pieces[0] . (($pieces[1] != '') ? " (" . $pieces[1] . ")" : '') . "</option>\n";
}
                           
?>
          </select>
        </td>
     </tr>
     <tr>
        <td>Start Date and Time</td>
        <td><input id='start_time' name="start_time" value="<?=$_REQUEST['start_time']?>"><button type="reset" id="button_time">...</button> <?php show_calendar_with_button('start_time', 'button_time') ?></td>
     </tr>
     <tr>
        <td>End Date and Time</td>
        <td><input id='end_time' name="end_time" value="<?=$_REQUEST['end_time']?>"><button type="reset" id="button_time">...</button> <?php show_calendar_with_button('end_time', 'button_time') ?></td>
     </tr>
     <tr>
        <td colspan="2" align="right"><input type="submit" value="Query IfOctets History"></td>
     </tr>
  </table>
  </form>
  </div>
  <?php

  if (isset($_REQUEST['pid']) && (strlen(trim($_REQUEST['pid'])) > 0)) {
    if ((isset($_REQUEST['start_time']) && (strlen(trim($_REQUEST['start_time'])) > 0)) &&
      (isset($_REQUEST['end_time']) && (strlen(trim($_REQUEST['end_time'])) > 0))) {
      $img_src = "status/grapher.php?type=$type&pid={$_REQUEST['pid']}&start_time=" . urlencode($_REQUEST['start_time']) . "&end_time=" . urlencode($_REQUEST['end_time']);
      print "<div id=graph><img src='$img_src'></div>";  
    }
    $get_args['pid'] = $_REQUEST['pid'];
    $get_args['start_time'] = $_REQUEST['start_time'];
    $get_args['end_time'] = $_REQUEST['end_time'];
  }
} elseif ($_REQUEST['type'] == "ifoctetshistorymac") {
?>
  <div id="history">
  <form action="<?=$current_top?>/<?=$current_sub?>.php?type=<?=$type?>&menu=<?=$_GET[menu]?>" name="history" method="post">
  <table class="main">
     <tr>
        <td rowspan=4 valign=top style="width:70px"><img src='images/report.png'></td>
        <td>MAC</td>
        <td><input type="text" name="pid" value='<?=$_REQUEST['pid']?>'></td>
     </tr>
     <tr>
        <td>Start Date and Time</td>
        <td><input id='start_time' name="start_time" value="<?=$_REQUEST['start_time']?>"><button type="reset" id="button_time">...</button> <?php show_calendar_with_button('start_time', 'button_time') ?></td>
     </tr>
     <tr>
        <td>End Date and Time</td>
        <td><input id='end_time' name="end_time" value="<?=$_REQUEST['end_time']?>"><button type="reset" id="button_time">...</button> <?php show_calendar_with_button('end_time', 'button_time') ?></td>
     </tr>
     <tr>
        <td colspan="2" align="right"><input type="submit" value="Query IfOctets History"></td>
     </tr>
  </table>
  </form>
  </div>
  <?php

  if (isset($_REQUEST['pid']) && (strlen(trim($_REQUEST['pid'])) > 0)) {
    if ((isset($_REQUEST['start_time']) && (strlen(trim($_REQUEST['start_time'])) > 0)) &&
      (isset($_REQUEST['end_time']) && (strlen(trim($_REQUEST['end_time'])) > 0))) {
      $img_src = "status/grapher.php?type=$type&pid={$_REQUEST['pid']}&start_time=" . urlencode($_REQUEST['start_time']) . "&end_time=" . urlencode($_REQUEST['end_time']);
      print "<div id=graph><img src='$img_src'></div>";  
    }
    $get_args['pid'] = $_REQUEST['pid'];
    $get_args['start_time'] = $_REQUEST['start_time'];
    $get_args['end_time'] = $_REQUEST['end_time'];
  }
} elseif ($_REQUEST['type'] == "ifoctetshistoryswitch") {
?>
  <div id="history">
  <form action="<?=$current_top?>/<?=$current_sub?>.php?type=<?=$type?>&menu=<?=$_GET[menu]?>" name="history" method="post">
  <table class="main">
     <tr>
        <td rowspan=5 valign=top style="width:70px"><img src='images/report.png'></td>
        <td>Switch</td>
        <td><input type="text" name="switch" value='<?=$_REQUEST['switch']?>'></td>
     </tr>
     <tr>
        <td>Port</td>
        <td><input type="text" name="port" value='<?=$_REQUEST['port']?>'></td>
     </tr>
     <tr>
        <td>Start Date and Time</td>
        <td><input id='start_time' name="start_time" value="<?=$_REQUEST['start_time']?>"><button type="reset" id="button_time">...</button> <?php show_calendar_with_button('start_time', 'button_time') ?></td>
     </tr>
     <tr>
        <td>End Date and Time</td>
        <td><input id='end_time' name="end_time" value="<?=$_REQUEST['end_time']?>"><button type="reset" id="button_time">...</button> <?php show_calendar_with_button('end_time', 'button_time') ?></td>
     </tr>
     <tr>
        <td colspan="2" align="right"><input type="submit" value="Query IfOctets History"></td>
     </tr>
  </table>
  </form>
  </div>
  <?php

    if (isset($_REQUEST['switch']) && (strlen(trim($_REQUEST['switch'])) > 0) && isset($_REQUEST['port']) && (strlen(trim($_REQUEST['port'])) > 0)) {
    if ((isset($_REQUEST['start_time']) && (strlen(trim($_REQUEST['start_time'])) > 0)) &&
      (isset($_REQUEST['end_time']) && (strlen(trim($_REQUEST['end_time'])) > 0))) {
      $img_src = "status/grapher.php?type=$type&switch={$_REQUEST['switch']}&port={$_REQUEST['port']}&start_time=" . urlencode($_REQUEST['start_time']) . "&end_time=" . urlencode($_REQUEST['end_time']);
      print "<div id=graph><img src='$img_src'></div>";  
    }
    $get_args['switch'] = $_REQUEST['switch'];
    $get_args['port'] = $_REQUEST['port'];
    $get_args['start_time'] = $_REQUEST['start_time'];
    $get_args['end_time'] = $_REQUEST['end_time'];
  }
}            


  include_once('../footer.php');

?>

