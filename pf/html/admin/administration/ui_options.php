<?php
  session_start();
  $current_top="administration";
  $current_sub="ui_options";

  require('../common.php');

  if($_POST){
    $options=array('font_size', 'homepage', 'cache_time', 'ui_debug');

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

<div id="history">
<form method='post' action='<?=$current_top?>/<?=$current_sub?>.php'>
<table class="main">
  <tr>
    <td><b>Font Size</b></td>
  </tr>
  <tr>  
    <td>
      <input type='radio' name='font_size' value='small' <? if($_SESSION['ui_prefs']['font_size']=='small') echo "checked";?> ><span style="font-size:8pt">Small</span>
      <input type='radio' name='font_size' value='medium' <? if($_SESSION['ui_prefs']['font_size']=='medium' || !isset($_SESSION['ui_prefs']['font_size'])) echo "checked";?> ><span style="font-size:10pt">Medium</span>
      <input type='radio' name='font_size' value='large' <? if($_SESSION['ui_prefs']['font_size']=='large')echo "checked";?> ><span style="font-size:14pt">Large</span>
    </td>
  </tr>
  <tr height=10px><td><hr></td></tr>
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
