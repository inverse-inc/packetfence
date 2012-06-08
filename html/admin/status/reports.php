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
 * @author      Francois Gaudreault <fgaudreault@inverse.ca>
 * @author      Dominik Gehl <dgehl@inverse.ca>
 * @copyright   2008-2012 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

  require_once('../common.php');
  require_once('grapher.php');

  $current_top="status";
  $current_sub="reports";

  include_once('../header.php');

  $active_available = array(
    'registered', 'unregistered', 
    'os', 'osclass', 
    'unknownprints', 'unknownuseragents', 
    'openviolations', 'statics',
    'connectiontype', 'connectiontypereg',
    'ssid'
  );
  $type = set_default($_REQUEST['type'], 'ipmachistory');
  $subtype = set_default($_GET['subtype'], '');

  $pid = set_default($_REQUEST['pid'], $_GET['view_item']);

  $get_args = array('menu' => $_GET['menu'], 'type' => $type);

  $pretty_type = pretty_header("$current_top-$current_sub", $type);
  
  if(in_array($type, $active_available)){
    if($subtype == 'active' || $subtype == 'inactive')
      $additional = "$pretty_type: <a href='$current_top/$current_sub.php?menu=$_GET[menu]&type=$type&subtype=all'>All</a>  | <a href='$current_top/$current_sub.php?menu=$_GET[menu]&type=$type&subtype=active'><u>Active</u></a>";
    else
      $additional = "$pretty_type: <a href='$current_top/$current_sub.php?menu=$_GET[menu]&type=$type&subtype=all'><u>All</u></a>  | <a href='$current_top/$current_sub.php?menu=$_GET[menu]&type=$type&subtype=active'>Active</a>";
  }
  
  if ($type == 'osclassbandwidth') {
      $window_choices = array('all', 'day', 'week', 'month', 'year');
      $additional = "$pretty_type Window: ";
      foreach ($window_choices as $window) {
         if ($subtype == $window) {
             $link_title = '<u>'.ucfirst($window).'</u>';
         }
         else {
             $link_title = ucfirst($window);
         }
         $menu_html[] = "<a href='$current_top/$current_sub.php?menu=$_GET[menu]&type=$type&subtype=$window'>$link_title</a>";
      }
      $additional .= implode(' | ', $menu_html);
  }

  $extra_goodness = helper_menu($current_top, $current_sub, $type, $_GET[menu], $additional);

  if(($type == 'ipmachistory') || ($_REQUEST['type'] == 'locationhistoryswitch') || ($_REQUEST['type'] == 'locationhistorymac') || ($_REQUEST['type'] == 'ifoctetshistoryuser') || ($_REQUEST['type'] == 'ifoctetshistoryswitch') || ($_REQUEST['type'] == 'ifoctetshistorymac')) {
    print $extra_goodness;
    unset($extra_goodness);
  }
  if($type == 'ipmachistory'){
  ?>
  <div id="ipmachistory">
  <form action="<?=$current_top?>/<?=$current_sub?>.php" name="ipmachistory" method="get">
  <input type="hidden" name="type" value="<?=$type?>">
  <input type="hidden" name="menu" value="<?=$_GET['menu']?>">
  <table class="main">
    <tr><td rowspan=20 valign=top><img src='images/report.png'></td></tr>
    <tr>
      <td>IP/MAC</td>
      <td><input type="text" name="pid" value='<?=$pid?>'></td>
    </tr>
    <tr>
      <td>Start Date and Time (optional)</td>
      <td><input id='start_time' name="start_time" value="<?=$_REQUEST['start_time']?>"><button type="reset" id="button_time">...</button> <?php show_calendar_with_button('start_time', 'button_time') ?></td>
    </tr>
    <tr>
      <td>End Date and Time (optional)</td>
      <td><input id='end_time' name="end_time" value="<?=$_REQUEST['end_time']?>"><button type="reset" id="button_time1">...</button> <?php show_calendar_with_button('end_time', 'button_time1') ?></td>
    </tr>
    <tr>
      <td colspan="2" align="right"><input type="submit" value="Query History"></td>
    </tr>
  </table>
  </form>
  </div>

  <?php

  if(isset($_REQUEST['pid'])) {
    $pid=$_REQUEST['pid'];
  }

  if (isset($pid) && (strlen(trim($pid)) > 0)) {
    if ((isset($_REQUEST['start_time']) && (strlen(trim($_REQUEST['start_time'])) > 0)) &&
      (isset($_REQUEST['end_time']) && (strlen(trim($_REQUEST['end_time'])) > 0))) {
      $my_table=new table("ipmachistory $pid start_time={$_REQUEST['start_time']},end_time={$_REQUEST['end_time']}");
    } else {
      $my_table=new table("ipmachistory $pid");
    }
    $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
    $my_table->set_per_page(set_default($_REQUEST['per_page'],1001));
    $my_table->set_linkable(array( array('mac', 'node/view.php'), array('owner', 'person/lookup.php')));
    $get_args['pid'] = $pid;
    $get_args['start_time'] = $_REQUEST['start_time'];
    $get_args['end_time'] = $_REQUEST['end_time'];
    $my_table->tableprint(true);
  }
  
} elseif ($_REQUEST['type'] == "locationhistoryswitch") {
  ?>
  <div id="history">
  <form action="<?=$current_top?>/<?=$current_sub?>.php" name="history" method="get">
  <input type="hidden" name="type" value="<?=$type?>">
  <input type="hidden" name="menu" value="<?=$_GET['menu']?>">
  <table class="main">
    <tr><td rowspan=20 valign=top><img src='images/report.png'></td></tr>
    <tr>
      <td>Switch</td>
      <td><input type="text" name="switch" value='<?=$_REQUEST['switch']?>'></td>
    </tr>
    <tr>
      <td>Port</td>
      <td><input type="text" name="port" value='<?=$_REQUEST['port']?>'></td>
    </tr>
    <tr>
      <td>Date and Time (optional)</td>
      <td><input id='time' name="time" value="<?=$_REQUEST['time']?>"><button type="reset" id="button_time">...</button> <?php show_calendar_with_button('time','button_time') ?></td>
    </tr>
    <tr>
      <td colspan="2" align="right"><input type="submit" value="Query Location History"></td>
    </tr>
  </table>
  </form>
  </div>

  <?php

  if (isset($_REQUEST['switch']) && (strlen(trim($_REQUEST['switch'])) > 0) &&
      isset($_REQUEST['port']) && (strlen(trim($_REQUEST['port'])) > 0)) {
    $my_table=new table("locationhistoryswitch {$_REQUEST['switch']} {$_REQUEST['port']} {$_REQUEST['time']}");
    $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
    $my_table->set_per_page(set_default($_REQUEST['per_page'],1001));
    $my_table->set_linkable(array( array('mac', 'node/view.php'), array('owner', 'person/lookup.php')));
    $get_args['switch'] = $_REQUEST['switch'];
    $get_args['port'] = $_REQUEST['port'];
    $get_args['time'] = $_REQUEST['time'];
    $my_table->tableprint(true);
  }

} elseif ($_REQUEST['type'] == "locationhistorymac") {
  ?>
  <div id="history">
  <form action="<?=$current_top?>/<?=$current_sub?>.php" name="history" method="get">
  <input type="hidden" name="type" value="<?=$type?>">
  <input type="hidden" name="menu" value="<?=$_GET['menu']?>">
  <table class="main">
    <tr><td rowspan=20 valign=top><img src='images/report.png'></td></tr>
    <tr>
      <td>MAC</td>
      <td><input type="text" name="mac" value='<?=$_REQUEST['mac']?>'></td>
    </tr>
    <tr>
      <td>Date and Time (optional)</td>
      <td><input id='time' name="time" value="<?=$_REQUEST['time']?>"><button type="reset" id="button_time">...</button> <?php show_calendar_with_button('time', 'button_time') ?></td>
    </tr>
    <tr>
      <td colspan="2" align="right"><input type="submit" value="Query Location History"></td>
    </tr>
  </table>
  </form>
  </div>

  <?php

  if (isset($_REQUEST['mac']) && (strlen(trim($_REQUEST['mac'])) > 0)) {
    $my_table=new table("locationhistorymac {$_REQUEST['mac']} {$_REQUEST['time']}");
    $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
    $my_table->set_per_page(set_default($_REQUEST['per_page'],1001));
    $my_table->set_linkable(array( array('mac', 'node/view.php'), array('owner', 'person/lookup.php')));
    $get_args['mac'] = $_REQUEST['mac'];
    $get_args['time'] = $_REQUEST['time'];
    $my_table->tableprint(true);
  }

} elseif ($_REQUEST['type'] == "ifoctetshistoryswitch") {
  ?>
  <div id="history">
  <form action="<?=$current_top?>/<?=$current_sub?>.php" name="history" method="get">
  <input type="hidden" name="type" value="<?=$type?>">
  <input type="hidden" name="menu" value="<?=$_GET['menu']?>">
  <table class="main">
    <tr><td rowspan=20 valign=top><img src='images/report.png'></td></tr>
    <tr>
      <td>Switch</td>
      <td><input type="text" name="switch" value='<?=$_REQUEST['switch']?>'></td>
    </tr>
    <tr>
      <td>Port</td>
      <td><input type="text" name="port" value='<?=$_REQUEST['port']?>'></td>
    </tr>
    <tr>
      <td>Start Date and Time (optional)</td>
      <td><input id='start_time' name="start_time" value="<?=$_REQUEST['start_time']?>"><button type="reset" id="button_time">...</button> <?php show_calendar_with_button('start_time', 'button_time') ?></td>
    </tr>
    <tr>
      <td>End Date and Time (optional)</td>
      <td><input id='end_time' name="end_time" value="<?=$_REQUEST['end_time']?>"><button type="reset" id="button_time1">...</button> <?php show_calendar_with_button('end_time', 'button_time1') ?></td>
    </tr>
    <tr>
      <td colspan="2" align="right"><input type="submit" value="Query IfOctets History"></td>
    </tr>
  </table>
  </form>
  </div>

  <?php

  if (isset($_REQUEST['switch']) && (strlen(trim($_REQUEST['switch'])) > 0) &&
      isset($_REQUEST['port']) && (strlen(trim($_REQUEST['port'])) > 0)) {
    if ((isset($_REQUEST['start_time']) && (strlen(trim($_REQUEST['start_time'])) > 0)) &&
      (isset($_REQUEST['end_time']) && (strlen(trim($_REQUEST['end_time'])) > 0))) {
      $my_table=new table("ifoctetshistoryswitch {$_REQUEST['switch']} {$_REQUEST['port']} start_time={$_REQUEST['start_time']},end_time={$_REQUEST['end_time']}");
    } else {
      $my_table=new table("ifoctetshistoryswitch {$_REQUEST['switch']} {$_REQUEST['port']}");
    }
    $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
    $my_table->set_per_page(set_default($_REQUEST['per_page'],1001));
    $my_table->set_linkable(array( array('mac', 'node/view.php'), array('owner', 'person/lookup.php')));
    $get_args['switch'] = $_REQUEST['switch'];
    $get_args['port'] = $_REQUEST['port'];
    $get_args['start_time'] = $_REQUEST['start_time'];
    $get_args['end_time'] = $_REQUEST['end_time'];
    $my_table->tableprint(true);
  }

} elseif ($_REQUEST['type'] == "ifoctetshistorymac") {
  ?>
  <div id="history">
  <form action="<?=$current_top?>/<?=$current_sub?>.php" name="history" method="get">
  <input type="hidden" name="type" value="<?=$type?>">
  <input type="hidden" name="menu" value="<?=$_GET['menu']?>">
  <table class="main">
    <tr><td rowspan=20 valign=top><img src='images/report.png'></td></tr>
    <tr>
      <td>MAC</td>
      <td><input type="text" name="mac" value='<?=$_REQUEST['mac']?>'></td>
    </tr>
    <tr>
      <td>Start Date and Time (optional)</td>
      <td><input id='start_time' name="start_time" value="<?=$_REQUEST['start_time']?>"><button type="reset" id="button_time">...</button> <?php show_calendar_with_button('start_time', 'button_time') ?></td>
    </tr>
    <tr>
      <td>End Date and Time (optional)</td>
      <td><input id='end_time' name="end_time" value="<?=$_REQUEST['end_time']?>"><button type="reset" id="button_time1">...</button> <?php show_calendar_with_button('end_time', 'button_time1') ?></td>
    </tr>
    <tr>
      <td colspan="2" align="right"><input type="submit" value="Query IfOctets History"></td>
    </tr>
  </table>
  </form>
  </div>

  <?php

  if (isset($_REQUEST['mac']) && (strlen(trim($_REQUEST['mac'])) > 0)) {
    if ((isset($_REQUEST['start_time']) && (strlen(trim($_REQUEST['start_time'])) > 0)) &&
      (isset($_REQUEST['end_time']) && (strlen(trim($_REQUEST['end_time'])) > 0))) {
      $my_table=new table("ifoctetshistorymac {$_REQUEST['mac']} start_time={$_REQUEST['start_time']},end_time={$_REQUEST['end_time']}");
    } else {
      $my_table=new table("ifoctetshistorymac {$_REQUEST['mac']}");
    }
    $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
    $my_table->set_per_page(set_default($_REQUEST['per_page'],1001));
    $my_table->set_linkable(array( array('mac', 'node/view.php'), array('owner', 'person/lookup.php')));
    $get_args['mac'] = $_REQUEST['mac'];
    $get_args['start_time'] = $_REQUEST['start_time'];
    $get_args['end_time'] = $_REQUEST['end_time'];
    $my_table->tableprint(true);
  }

} elseif ($_REQUEST['type'] == "ifoctetshistoryuser") {
  ?>
  <div id="history">
  <form action="<?=$current_top?>/<?=$current_sub?>.php" name="history" method="get">
  <input type="hidden" name="type" value="<?=$type?>">
  <input type="hidden" name="menu" value="<?=$_GET['menu']?>">
  <table class="main">
    <tr><td rowspan=20 valign=top><img src='images/report.png'></td></tr>
    <tr>
      <td>User</td>
      <td><input type="text" name="pid" value='<?=$_REQUEST['pid']?>'></td>
    </tr>
    <tr>
      <td>Start Date and Time (optional)</td>
      <td><input id='start_time' name="start_time" value="<?=$_REQUEST['start_time']?>"><button type="reset" id="button_time">...</button> <?php show_calendar_with_button('start_time', 'button_time') ?></td>
    </tr>
    <tr>
      <td>End Date and Time (optional)</td>
      <td><input id='end_time' name="end_time" value="<?=$_REQUEST['end_time']?>"><button type="reset" id="button_time1">...</button> <?php show_calendar_with_button('end_time', 'button_time1') ?></td>
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
      $my_table=new table("ifoctetshistoryuser {$_REQUEST['pid']} start_time={$_REQUEST['start_time']},end_time={$_REQUEST['end_time']}");
    } else {
      $my_table=new table("ifoctetshistoryuser {$_REQUEST['pid']}");
    }
    $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
    $my_table->set_per_page(set_default($_REQUEST['per_page'],1001));
    $my_table->set_linkable(array( array('mac', 'node/view.php'), array('owner', 'person/lookup.php')));
    $get_args['pid'] = $_REQUEST['pid'];
    $get_args['start_time'] = $_REQUEST['start_time'];
    $get_args['end_time'] = $_REQUEST['end_time'];
    $my_table->tableprint(true);
  }

} else{
  $type.=" $subtype";

  $my_table=new table("report $type");
  $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
  $my_table->set_per_page(set_default($_REQUEST['per_page'],1001));
  $my_table->set_linkable(array( array('mac', 'status/reports.php?type=history'), array('ip', 'status/reports.php?type=history'), array('pid', 'person/view.php'), 
array('owner', 'person/lookup.php')));

  if(strstr($type,'unknownprints')){
    get_global_conf();

    ## Updating DHCP Fingerprints ##  
    if($_REQUEST['update']){
      $msg = update_fingerprints();
    } 

    ## Sharing Fingerprints ##
    if($_REQUEST['upload']){
      if($msg){ $msg.="<br>"; }
      $msg .= share_fingerprints($my_table->rows);
    }

    if($msg){
      $extra_goodness .= "<div id='message_box'>$msg</div>";
    }
  } elseif (strstr($type,'unknownuseragents')){
    get_global_conf();

    ## Sharing Fingerprints ##
    if($_REQUEST['upload']){
      if($msg){ $msg.="<br>"; }
      $msg .= share_useragents($my_table->rows);
    }

    if($msg){
      $extra_goodness .= "<div id='message_box'>$msg</div>";
    }
  }

  in_array('percent', $my_table->headers) ? $graph = true : $graph = false;
  
  if($graph){
    $no_filter=true;
    $extra_goodness .= "<center><table width=80%><tr><td width=50% valign=top align=center>";
  }

  $my_table->tableprint(false);

  if($graph){
    print "</td><td style='padding-top:15px;' align=center valign=top>";
    jsgraph(array('type' => trim($type), 'span' => 'report'));
    print "</td></tr></table></center>";
  }

  $is_printable = true;
}

include_once('../footer.php');

?>

