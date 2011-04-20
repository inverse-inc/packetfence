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
 * @author      Dominik Gehl <dgehl@inverse.ca>
 * @copyright   2008-2010 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

$current_top = "configuration";
$current_sub = "main";
require('../common.php');
include('../header.php');

?>

<script type='text/javascript'>
  function selectSection(section, alt){
    var regEx = eval("/^section_/");
    var spans = document.getElementsByTagName('li');

    for(i=0; i<spans.length; i++){
     if(spans[i].id.match(regEx)){
        spans[i].style.backgroundColor='#F7F7F7';
      }
    }
    document.getElementById('section_' + section).style.backgroundColor='#DDDDDD';

    regEx = eval("/^settings_/");
    spans = document.getElementsByTagName('span');

    for(i=0; i<spans.length; i++){
      if(spans[i].id.match(regEx)){
        spans[i].style.display='none';
      }
    }


    var a = eval(document.getElementById('settings_' + section) != null); 
    if(a){
      document.getElementById('settings_' + section).style.display='block';
    }
    else if(alt){
      document.getElementById('settings_' + alt).style.display='block';
    }

    var divs = document.getElementsByTagName('li');
    //close other blocks
    regEx = new RegExp("^section_([^.]+)\\..+");
    for(i=0; i<divs.length; i++){
      var match = regEx.exec(divs[i].id);
      if(match != null){
        var mainSection = RegExp.$1;
        var mainSectionRegExp = new RegExp("^" + mainSection);
        if (! section.match(mainSectionRegExp)) {
          divs[i].style.display='none';
        }
      }
    }
    //open the necessary blocks
    regEx = new RegExp("^section_" + section);
    for(i=0; i<divs.length; i++){
      if(divs[i].id.match(regEx)){
        divs[i].style.display='block';
      }
    }
  }

  

</script>

<?

$configs = PFCMD('config get all');

$time_units = array('s' => 'seconds', 'm' => 'minutes', 'h' => 'hours', 'd' => 'days', 'w' => 'weeks'); 
if(isset($_GET['update'])){
  foreach($configs as $config) {
    $parts_ar=preg_split("/\|/",$config);
    $type = array_pop($parts_ar);
    $options_ar=preg_split("/=/", $parts_ar[0]);
    $pf_option=array_shift($options_ar);
    $option=preg_replace("/\.|\s/", "_", $pf_option);
    if (strncmp($option, 'interface_', 10) == 0) {
      continue;
    }
    $value=implode("=", $options_ar);
    if(!$value){
      $value = $parts_ar[1];
    }

    if(is_array($_POST[$option])){
      if($type == 'time'){
        $value = set_default($value, $parts_ar[1]);
        if($_POST["$option"]['amount'].$_POST["$option"]['unit'] != $value){
          $time_value = $_POST["$option"]['amount'].$_POST["$option"]['unit'];
          PFCMD("config set $pf_option=$time_value");
          $msg .= "Changed $pf_option from '$value' to '$time_value'<br>";
        }
      }

      else if($value != $multi_option=implode(",", $_POST[$option])){     
        $pf_option=preg_replace("/\s.*\./", ".", $pf_option);
        PFCMD("config set $pf_option=$multi_option");
        $msg .= "Changed $pf_option from '$value' to '$multi_option'<br>";
      }
    }

    else if($value != $_POST[$option]){
      if ($_POST[$option] != '') {
        PFCMD("config set $pf_option=$_POST[$option]");
        $msg .= "Changed $option from '$value' to '$_POST[$option]'<br>\n";
      } else {
        $msg .= "Unable to change $option from '$value' to ''<br>\n";
      }
    }
  }
  if(!isset($msg)){
    $msg = "No changes were made.";
  }
  $configs=PFCMD('config get all');
}

$current_heading = '';

foreach($configs as $config){
        preg_match("/^(([^.=]+)\.[^=]+)=(.+)$/", $config, $matches);
        $parts = explode('|', $matches[3]);

        $options = array();
        if($parts[0]){
          $options['value']   = $parts[0];
        }
        $options['default'] = $parts[1];
        $options['options'] = $parts[2];
        $options['type']    = $parts[3];

        if (strncmp($matches[2], 'interface', 9) != 0) {
                $config_tree[$matches[2]][$matches[1]] = $options;
        }
}

if($msg){
        print_notice($msg);
}

print "<table class='configuration'>";
print "  <tr>";
print "    <td class='left'>";
print "      <ul>";

$added_sections = array();

foreach($config_tree as $section => $val){
        # this sets class to top on first item and then always nothing
        $i++ == 0 ? $class = 'top' : $class = '';
        unset($matches);
        
        $my_section = set_default($matches[0], $section);

        #$nice_section = set_default($matches[2], $section);
        print "<li id='section_$section' class='$class' onClick='selectSection(\"$section\", \"false\");'>"
                 .ucfirst($section)."<span class='arrow'>&raquo;</span></li>";

}
print "      </ul>";

print "    </td><td valign=top style='padding-top:30px;'>";
print "<form name='config' action='$current_top/$current_sub.php?update=true' method='post'>";
foreach($config_tree as $section => $settings){
        print "<span id='settings_$section' style='display:none; border:1px solid #aaa; background: #F7F7F7; padding:10px;'>";
        print "<center><font style='font-weight:bold; font-size:12pt;'><u>".ucfirst($section)."</u></font></center>";

        print "<table align=center style='margin-top:10px;overflow:auto;'>";
        foreach($settings as $setting => $options){
                print "<tr><td style='width:200px;'>";
        if (substr_compare('proxies', $setting, 0, 7) == 0) {
          print $setting;
        } else {
          print "<a class='no_hover' HREF=\"javascript:popUp('$current_top/more_info.php?option=$setting', '100', '500');\">$setting</a>";
        }
        print "</td><td style='text-align:right;'>";
                $setting = preg_replace("/\./", "_", $setting);
                switch($options['type']){
                        case "date":
                        $value = set_default($options['value'], $options['default']);
                              print "<input type='text' name='$setting' value='$value' id='$setting'>";
                        show_calendar($setting);
                        break;

                        case "time":
                        $value = set_default($options['value'], $options['default']);
                        preg_match("/^(\d+)([s|m|h|d|w])/", $value, $matches);
                        print "<input type='text' name='{$setting}[amount]' value='$matches[1]' size=5>";
                        printSelect($time_units, 'HASH', $matches[2], "name='{$setting}[unit]'");
                        break;

                        case "multi":
                        print "<select multiple name='".$setting."[]'>";
                        $my_options = explode(";", $options['options']);  
                        $my_values = explode(",", set_default($options['value'],$options['default']));
                        foreach($my_options as $option){
                                if(in_array($option, $my_values))
                                        print "    <option value='$option' SELECTED>$option</option>\n";
                                else
                                        print "    <option value='$option'>$option</option>\n";
                        }
                        print "</select>";
                        break;

                        case "toggle":
                        $my_options=explode(";", $options['options']);
                        print "<select name='$setting'>";
                        $value = set_default($options['value'], $options['default']);
                        foreach($my_options as $option){
                                if($option == $value)
                                        print "<option value='$option' SELECTED>$option</option>";
                                else
                                        print "<option value='$option'>$option</option>";
                        }
                        print "</select>";
                        break;

                        default:
                        $value = set_default($options['value'], $options['default']);
                        if(!$value && $options['value'] == '0' || $options['default'] == '0'){
                                $value = '0';
                        }

                        if (($setting =="database_pass") || ($setting == "scan_pass")) {
                                print "<input type='password' name='$setting'  value='$value'>";
                        } elseif (($setting=='trapping_range') || ($setting=='trapping_blacklist') || ($setting=='trapping_whitelist') || ($setting == 'trapping_redirecturl')) {
                                print "<textarea name='$setting'>$value</textarea>\n";
                        } else {
                                print "<input type='text' name='$setting'  value='$value'>\n";
                        }
                        break;
                }
                print "</td></tr>";
        }
        print "<tr><td colspan=2 class='buttonbar'><input type='submit' value='Submit'></td></tr>";
        print "</table>";
        print "</span>";
}
print "</td></tr>";
print "</form>";
print "</table>";

print "<script>selectSection(\"alerting\");</script>";
        
include('../footer.php');

?>
