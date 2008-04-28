<?
if(!function_exists("set_default")){
  function set_default($value, $default){
    if(isset($value))
      return $value;
    else
      return $default;
  }
}

$remediation_conf = '/usr/local/pf/conf/ui-global.conf';

if(file_exists($remediation_conf)){
  $global_conf = unserialize(file_get_contents($remediation_conf));
  $current = $global_conf['remediation'];
}

$logo_src = set_default($current['logo_src'], "content/images/biohazard-sm.gif");


$user_data['ip'] = $_SERVER['REMOTE_ADDR'];

$PFCMD='/usr/local/pf/bin/pfcmd';
$command = "history $user_data[ip]";
exec("ARGS=".escapeshellarg($command)." $PFCMD 2>&1", $output, $total);

$keys = explode('|',array_shift($output));
$vals = explode('|',array_shift($output));

for($i=0; $i< count($keys); $i++){
  $user_data[$keys[$i]]=$vals[$i];
}
?>                                            
<html>
  
<head>
  <title>Reboot</title>
<? $abs_url="https://$_SERVER[HTTP_HOST]"; ?>
  <link rel="stylesheet" href="<?=$abs_url?>/content/style.php" type="text/css">
</head>

<body>
<div id='div_body'>

<div id='header'>
<center>
   <table class='header'>
      <tr>
        <td class='logo'>
          <img src='<?=$abs_url?>/<?=$logo_src?>' id='logo'>
        </td>
        <td class='title' id='title'>
          Reboot
        </td>
      </tr>
   </table>
</center>
</div>

<div id='remediation'>  
  <p>Please reboot your computer now in order for the new network settings
  to be applied.</p>
</div>

<div id='user_info'>
  <p class='sub_header'>Additional Assistance</p>

  If your network connectivity becomes permanently disabled or you are unable to follow the instructions above, please contact your local IT support staff for assistance.

  The following information should be provided upon request:

  <ul>
     <li>IP Address - <?=$user_data['ip']?></li>
     <li>MAC Address - <?=strtoupper($user_data['mac'])?></li>
  </ul>

</div>
                  
</div>
</body>
</html>
