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
 * @licence     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

  session_start();
  $current_top="administration";
  $current_sub="ui_options";

  require('../common.php');

  if($_POST){
    $options=array('homepage', 'cache_time', 'ui_debug');

    foreach($_POST as $key => $val){
      if(in_array($key, $options)){
        $new_options[$key]=$val;
      }
    }

    $filename = dirname(dirname($_SERVER['DOCUMENT_ROOT'])) . "/conf/users/" . $_SESSION['user'];
    if (!$handle = fopen($filename, 'w+')) {
       echo "Cannot open file ($filename)";
       exit;
    }

    if (fwrite($handle, serialize($new_options)) === FALSE) {
      echo "Cannot write to file ($filename)";
      exit;
    }
    fclose($handle);
    if(is_readable($filename)){
      unset($_SESSION['ui_prefs']);
      $_SESSION['ui_prefs']=unserialize(file_get_contents($filename));
    }  
  } 

  include('../header.php');
?>

<div id="add">
<form method='post' action='<?=$current_top?>/<?=$current_sub?>.php'>
<table class="add">
  <tr> 
    <td><b>Select Default Homepage</b></td>
  </tr>
  <tr>
    <td><select name='homepage'>
<?

  if(!isset($_SESSION['ui_prefs']['homepage']))
    $_SESSION['ui_prefs']['homepage'] = 'status/dashboard'; 

  $options = array();

  $root_menus = meta('root');
  $dropdowns = array('graphs', 'reports');
  foreach ($root_menus as $current_root) {
    $rootFileName = $current_root[0];
    $rootShowName = $current_root[1];
    $sub_menus = meta($rootFileName);
    foreach ($sub_menus as $current_sub) {
      $subFileName = $current_sub[0];
      $subShowName = $current_sub[1];
      $file = $rootFileName . "/" . $subFileName . ".php";
      if (in_array($subFileName, $dropdowns)) {
        $file .= "?menu=true";
      }
      ($file == $_SESSION['ui_prefs']['homepage']) ? $selected = 'SELECTED' : $selected = ''; 
      array_push($options, "<option value='$file' $selected>$rootShowName - $subShowName</option>");
      if (in_array($subFileName, $dropdowns)) {
        $subsub_menus = meta("status-$subFileName");
        foreach ($subsub_menus as $current_subsub) {
          $file = $rootFileName . "/" . $subFileName . ".php?type=" . $current_subsub[0];
          ($file == $_SESSION['ui_prefs']['homepage']) ? $selected = 'SELECTED' : $selected = ''; 
          array_push($options, "<option value='$file' $selected>$rootShowName - $subShowName - " . $current_subsub[1] . "</option>");
          
        }
      }
    }
  }

  sort($options);
  array_unique($options);
  foreach ($options as $current_option) {
    print "$current_option\n";
  }
  
?>
    </select></td>
  </tr>
  <tr height=10px><td><hr></td></tr>
  </tr>
  <tr>
    <td><b>Image Cache Limit</b></td>
  </tr>
  <tr>
    <td><input type='text' name='cache_time' value='<?=$_SESSION['ui_prefs']['cache_time']?>'> minutes</td>
  </tr>
  <tr>
    <td><b>UI Debug Mode</b></td>
  </tr>
  <tr>
    <td><? printSelect(array('false' => 'Disabled', 'true' => 'Enabled'), 'hash', $_SESSION['ui_prefs']['ui_debug'], "name='ui_debug'") ?></td>
  </tr>
  <tr>
    <td colspan=10 align=right><input type='submit'></td>
  </tr>
</table>
</div>
</form>
<?php
  include('../footer.php');
?>
