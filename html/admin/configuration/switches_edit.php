<?php
/**
 * switches_edit.php: Network Device edit dialog
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
 * @copyright   2008-2012 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

  $current_top = 'configuration';
  $current_sub = 'switches';

  include('../common.php');
?>

<html>
<head>
  <title>PF::Configuration::Switches::Edit</title>
  <link rel="shortcut icon" href="/favicon.ico"> 
  <link rel="stylesheet" href="../style.css" type="text/css">
</head>

<body class="popup">

<?
  perform_access_control_in_popup();

  $edit_item = set_default($_REQUEST['item'], '');

  if($_POST){
    $edit_cmd = "switchconfig edit $edit_item ";
    foreach($_POST as $key => $val){
      $parts[] = "$key=\"$val\""; 
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

  $edit_info = new table("switchconfig get $edit_item");

  print "<form name='edit' method='post' action='/$current_top/" . $current_sub . "_edit.php?item=$edit_item'>";
  print "<div id='add'><table>";
  print "<tr><td><img src='../images/node.png'></td><td valign='middle' colspan=2><b>Editing: ".$edit_info->rows[0]['ip']."</b></td></tr>";
  foreach($edit_info->rows[0] as $key => $val){
    if($key == $edit_info->key){
      continue;
    }
    if($key == "ip") {
      continue;
    }

    $pretty_key = pretty_header("configuration-switches", $key);
    switch($key) {
      case 'SNMPVersion':
      case 'SNMPVersionTrap':
        print "<tr><td></td><td>$pretty_key:</td><td>";
        printSelect( array('' => 'please choose', '1' => '1', '2c' => '2c', '3' => '3'), 'hash', $val, "name='$key'");
        break;

      case 'inlineTrigger':
      case 'uplink':
      case 'vlans':
        print "<tr><td></td><td>$pretty_key:</td><td><textarea name='$key'>$val</textarea>";
        break;

      case 'mode':
        print "<tr><td></td><td>$pretty_key:</td><td>";
        printSelect( array('' => 'please choose', 'discovery' => 'discovery', 'ignore' => 'ignore', 'production' => 'production', 'registration' => 'registration', 'testing' => 'testing'), 'hash', $val, "name='$key'");
        break;

      case 'type':
        print "<tr><td></td><td>$pretty_key:</td><td>";
        # to list all modules under SNMP: find . -type f | sed 's/^\.\///' | sed 's/\//::/' | sed 's/.pm$//'
        printSelect( array('' => 'please choose',
                           'ThreeCom::E4800G' => '3COM E4800G',
                           'ThreeCom::E5500G' => '3COM E5500G',
                           'ThreeCom::NJ220' => '3COM NJ220', 
                           'ThreeCom::SS4200' => '3COM SS4200', 
                           'ThreeCom::SS4500' => '3COM SS4500', 
                           'ThreeCom::Switch_4200G' => '3COM 4200G',
                           'Accton::ES3526XA' => 'Accton ES3526XA', 
                           'Accton::ES3528M' => 'Accton ES3528M',
                           'AeroHIVE::AP' => 'AeroHIVE AP',
                           'AlliedTelesis::AT8000GS' => 'AlliedTelesis AT8000GS',
                           'Amer::SS2R24i' => 'Amer SS2R24i',
                           'Aruba' => 'Aruba Networks',
                           'Avaya::WC' => 'Avaya Wireless Controller',
                           'Avaya' => 'Avaya Switch (see Nortel)',
                           'Brocade' => 'Brocade Switches',
                           'Brocade::RFS' => 'Brocade RF Switches',
                           'Cisco::Aironet_1130' => 'Cisco Aironet 1130',
                           'Cisco::Aironet_1242' => 'Cisco Aironet 1242',
                           'Cisco::Aironet_1250' => 'Cisco Aironet 1250',
                           'Cisco::Catalyst_2900XL' => 'Cisco Catalyst 2900XL Series',
                           'Cisco::Catalyst_2950' => 'Cisco Catalyst 2950',
                           'Cisco::Catalyst_2960' => 'Cisco Catalyst 2960',
                           'Cisco::Catalyst_2960G' => 'Cisco Catalyst 2960G',
                           'Cisco::Catalyst_2970' => 'Cisco Catalyst 2970',
                           'Cisco::Catalyst_3500XL' => 'Cisco Catalyst 3500XL Series',
                           'Cisco::Catalyst_3550' => 'Cisco Catalyst 3550',
                           'Cisco::Catalyst_3560' => 'Cisco Catalyst 3560',
                           'Cisco::Catalyst_3560G' => 'Cisco Catalyst 3560G',
                           'Cisco::Catalyst_3750' => 'Cisco Catalyst 3750',
                           'Cisco::Catalyst_3750G' => 'Cisco Catalyst 3750G',
                           'Cisco::Catalyst_4500' => 'Cisco Catalyst 4500 Series',
                           'Cisco::Catalyst_6500' => 'Cisco Catalyst 6500 Series',
                           'Cisco::ISR_1800' => 'Cisco ISR 1800 Series',
                           'Cisco::WiSM' => 'Cisco WiSM',
                           'Cisco::WiSM2' => 'Cisco WiSM2',
                           'Cisco::WLC' => 'Cisco Wireless Controller (WLC)',
                           'Cisco::WLC_2100' => 'Cisco Wireless (WLC) 2100 Series',
                           'Cisco::WLC_2500' => 'Cisco Wireless (WLC) 2500 Series',
                           'Cisco::WLC_4400' => 'Cisco Wireless (WLC) 4400 Series',
                           'Cisco::WLC_5500' => 'Cisco Wireless (WLC) 5500 Series',
                           'Dell::PowerConnect3424' => 'Dell PowerConnect 3424',
                           'Dlink::DES_3526' => 'D-Link DES 3526',
                           'Dlink::DES_3550' => 'D-Link DES 3550',
                           'Dlink::DGS_3100' => 'D-Link DGS 3100',
                           'Dlink::DGS_3200' => 'D-Link DGS 3200',
                           'Dlink::DWL' => 'D-Link DWL Access-Point',
                           'Dlink::DWS_3026' => 'D-Link DWS 3026',
                           'Enterasys::Matrix_N3' => 'Enterasys Matrix N3',
                           'Enterasys::SecureStack_C2' => 'Enterasys SecureStack C2',
                           'Enterasys::SecureStack_C3' => 'Enterasys SecureStack C3',
                           'Enterasys::D2' => 'Enterasys Standalone D2',
                           'Extreme::Summit' => 'ExtremeNet Summit series',
                           'Extricom::EXSW' => 'Extricom EXSW Controllers',
                           'Foundry::FastIron_4802' => 'Foundry FastIron 4802',
                           'H3C::S5120' => 'H3C S5120 (HP/3Com)',
                           'HP::E4800G' => 'HP E4800G (3Com)',
                           'HP::E5500G' => 'HP E5500G (3Com)',
                           'HP::Procurve_2500' => 'HP ProCurve 2500 Series',
                           'HP::Procurve_2600' => 'HP ProCurve 2600 Series',
                           'HP::Procurve_3400cl' => 'HP ProCurve 3400cl Series',
                           'HP::Procurve_4100' => 'HP ProCurve 4100 Series',
                           'HP::Procurve_5300' => 'HP ProCurve 5300 Series',
                           'HP::Procurve_5400' => 'HP ProCurve 5400 Series',
                           'HP::Controller_MSM710' => 'HP ProCurve MSM710 Mobility Controller',
                           'Intel::Express_460' => 'Intel Express 460',
                           'Intel::Express_530' => 'Intel Express 530',
                           'Juniper::EX' => 'Juniper EX Series',
                           'LG::ES4500G' => 'LG-Ericsson iPECS ES-4500G',
                           'Linksys::SRW224G4' => 'Linksys SRW224G4',
                           'Meru::MC' => 'Meru MC',
                           'Motorola::RFS' => 'Motorola RF Switches',
                           'Netgear::FSM726v1' => 'Netgear FSM726v1',
                           'Netgear::GS110' => 'Netgear GS110',
                           'Nortel::BayStack4550' => 'Nortel BayStack 4550',
                           'Nortel::BayStack470' => 'Nortel BayStack 470',
                           'Nortel::BayStack5500' => 'Nortel BayStack 5500 Series',
                           'Nortel::BayStack5500_6x' => 'Nortel BayStack 5500 w/ firmware 6.x',
                           'Nortel::BPS2000' => 'Nortel BPS 2000',
                           'Nortel::ERS2500' => 'Nortel ERS 2500 Series',
                           'Nortel::ERS4000' => 'Nortel ERS 4000 Series',
                           'Nortel::ERS5000' => 'Nortel ERS 5000 Series',
                           'Nortel::ERS5000_6x' => 'Nortel ERS 5000 Series w/ firmware 6.x',
                           'Nortel::ES325' => 'Nortel ES325',
                           'PacketFence' => 'PacketFence',
                           'Ruckus' => 'Ruckus Wireless Controllers',
                           'SMC::TS6128L2' => 'SMC TigerStack 6128L2',
                           'SMC::TS6224M' => 'SMC TigerStack 6224M',
                           'SMC::TS8800M' => 'SMC TigerStack 8800 Series',
                           'Trapeze' => 'Trapeze Wireless Controller',
                           'Xirrus' => 'Xirrus WiFi Arrays'
                      ), 
                     'hash', $val, "name='$key'");
        break;

      case 'cliTransport':
        print "<tr><td></td><td>$pretty_key:</td><td>";
        printSelect( array('' => 'please choose', 'Telnet' => 'Telnet', 'SSH' => 'SSH'), 'hash', $val, "name='$key'");
        break;

      case 'wsTransport':
        print "<tr><td></td><td>$pretty_key:</td><td>";
        printSelect( array('' => 'please choose', 'http' => 'http', 'https' => 'https'), 'hash', $val, "name='$key'");
        break;

      case 'VoIPEnabled':
        print "<tr><td></td><td>$pretty_key:</td><td>";
        printSelect( array('' => 'please choose', 'yes' => 'Yes', 'no' => 'No'), 'hash', $val, "name='$key'");
        break;

      case 'deauthMethod':
        print "<tr><td></td><td>$pretty_key:</td><td>";
        printSelect( array('' => 'please choose', 'Telnet' => 'Telnet', 'SSH' => 'SSH', 'SNMP' => 'SNMP', 'Radius' => 'RADIUS', 'Http' => 'HTTP', 'Https' => 'HTTPS'), 'hash', $val, "name='$key'");
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
<?php
# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
?>
