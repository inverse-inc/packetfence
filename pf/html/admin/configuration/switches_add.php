<?php
/**
 * @licence http://opensource.org/licenses/gpl-2.0.php GPL
 */

  $current_top = 'configuration';
  $current_sub = 'switches';

  include('../common.php');
?>

<html>
<head>
  <title>PF::Configuration::Switches::Add</title>
  <link rel="shortcut icon" href="/favicon.ico"> 
  <link rel="stylesheet" href="../style.css" type="text/css">
</head>

<body class="popup">

<?
  perform_access_control_in_popup();

  $edit_item = set_default($_REQUEST['item'], '');

  if($_POST){
    foreach($_POST as $key => $val){
      if ($key == 'ip') {
        $edit_item = $val;
      } else {
        $parts[] = "$key=\"$val\""; 
      }
    }
    $edit_cmd = "switchconfig add $edit_item ";
    $edit_cmd.=implode(", ", $parts);

    PFCMD($edit_cmd);
    $edited=true; 
    print "<script type='text/javascript'>opener.focus(); opener.location.href = opener.location; self.close();</script>";

  }

  $edit_info = new table("switchconfig get $edit_item");

  print "<form name='edit' method='post' action='/$current_top/" . $current_sub . "_add.php?item=$edit_item'>";
  print "<div id='add'><table>";
  print "<tr><td><img src='../images/node.png'></td><td valign='middle' colspan=2><b>Adding new switch:</b></td></tr>";
  foreach($edit_info->rows[0] as $key => $val){
    if($key == $edit_info->key){
      continue;
    }
    if($key == "ip") {
      $val = '';
    }

    $pretty_key = pretty_header("configuration-switches", $key);
    if (($key == 'SNMPVersion') || ($key == 'SNMPVersionTrap')) {
      print "<tr><td></td><td>$pretty_key:</td><td>";
      printSelect( array('' => 'please choose', '1' => '1', '2c' => '2c', '3' => '3'), 'hash', $val, "name='$key'");
    } elseif (($key == 'uplink') || ($key == 'vlans')) {
      print "<tr><td></td><td>$pretty_key:</td><td><textarea name='$key'>$val</textarea>";
    } elseif ($key == 'mode') {
      print "<tr><td></td><td>$pretty_key:</td><td>";
      printSelect( array('' => 'please choose', 'discovery' => 'discovery', 'ignore' => 'ignore', 'production' => 'production', 'registration' => 'registration', 'testing' => 'testing'), 'hash', $val, "name='$key'");
    } elseif ($key == 'type') {
      print "<tr><td></td><td>$pretty_key:</td><td>";
      # to list all modules under SNMP: find . -type f | sed 's/^\.\///' | sed 's/\//::/' | sed 's/.pm$//'
      printSelect( array('' => 'please choose',
                         'ThreeCom::NJ220' => '3COM NJ220', 
                         'ThreeCom::SS4200' => '3COM SS4200', 
                         'ThreeCom::SS4500' => '3COM SS4500', 
                         'ThreeCom::Switch_4200G' => '3COM 4200G',
                         'Accton::ES3526XA' => 'Accton ES3526XA', 
                         'Accton::ES3528M' => 'Accton ES3528M',
                         'Amer::SS2R24i' => 'Amer SS2R24i',
                         'Aruba::Controller_200' => 'Aruba Controller 200', 
                         'Cisco::Aironet_1130' => 'Cisco Aironet 1130',
                         'Cisco::Aironet_1242' => 'Cisco Aironet 1242',
                         'Cisco::Aironet_1250' => 'Cisco Aironet 1250',
                         'Cisco::Catalyst_2900XL' => 'Cisco Catalyst 2900XL',
                         'Cisco::Catalyst_2950' => 'Cisco Catalyst 2950',
                         'Cisco::Catalyst_2960' => 'Cisco Catalyst 2960',
                         'Cisco::Catalyst_2970' => 'Cisco Catalyst 2970',
                         'Cisco::Catalyst_3500XL' => 'Cisco Catalyst 3500XL',
                         'Cisco::Catalyst_3550' => 'Cisco Catalyst 3550',
                         'Cisco::Catalyst_3560' => 'Cisco Catalyst 3560',
                         'Cisco::Controller_4400_4_2_130' => 'Cisco Controller 4400',
                         'Cisco::WLC_2106' => 'Cisco WLC 2106',
                         'Dell::PowerConnect3424' => 'Dell PowerConnect 3424',
                         'Dlink::DES_3526' => 'D-Link DES 3526',
                         'Dlink::DWS_3026' => 'D-Link DWS 3026',
                         'Enterasys::Matrix_N3' => 'Enterasys Matrix N3',
                         'Enterasys::SecureStack_C2' => 'Enterasys SecureStack C2',
                         'Enterasys::SecureStack_C3' => 'Enterasys SecureStack C3',
                         'Enterasys::D2' => 'Enterasys Standalone D2',
                         'Extreme::Summit_X250e' => 'Extreme Networks Summit X250e',
                         'Foundry::FastIron_4802' => 'Foundry FastIron 4802',
                         'HP::Procurve_2500' => 'HP Procurve 2500',
                         'HP::Procurve_2600' => 'HP Procurve 2600',
                         'HP::Procurve_4100' => 'HP Procurve 4100',
                         'Intel::Express_460' => 'Intel Express 460',
                         'Intel::Express_530' => 'Intel Express 530',
                         'Linksys::SRW224G4' => 'Linksys SRW224G4',
                         'Nortel::BayStack4550' => 'Nortel BayStack 4550',
                         'Nortel::BayStack470' => 'Nortel BayStack 470',
                         'Nortel::BayStack5520' => 'Nortel BayStack 5520',
                         'Nortel::BayStack5520Stacked' => 'Nortel BayStack 5520 Stacked',
                         'Nortel::BPS2000' => 'Nortel BPS 2000',
                         'Nortel::ES325' => 'Nortel ES325',
                         'PacketFence' => 'PacketFence',
                         'SMC::TS6224M' => 'SMC TigerStack 6224M'
                    ), 
                   'hash', $val, "name='$key'");
    } elseif ($key == 'cliTransport') {
      print "<tr><td></td><td>$pretty_key:</td><td>";
      printSelect( array('' => 'please choose', 'Telnet' => 'Telnet', 'SSH' => 'SSH'), 'hash', $val, "name='$key'");
    } else {
      print "<tr><td></td><td>$pretty_key:</td><td><input type='text' name='$key' value='$val'>";
    }

    if(($key == 'regdate')||($key == 'unregdate')){
      $now = date('Y-m-d H:i:s');
      print  " <img src='../images/date.png' onClick=\"document.edit.$key.value='$now';return false;\" title='Insert Current Time' style='cursor:pointer;'>";
    }

    print "</td></tr>";
  }
  print "<tr><td colspan=3 align=right><input type='submit' value='Add switch'></td></tr>";
  print "</table></div>";
  print "</form>";
?>

</html>
