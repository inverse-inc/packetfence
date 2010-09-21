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
 * @author	Dominik Gehl <dgehl@inverse.ca>
 * @copyright 	2008-2010 Inverse inc.
 * @licence 	http://opensource.org/licenses/gpl-2.0.php	GPL
 */

  if(!function_exists("set_default")){
    function set_default($value, $default){
      if(isset($value))
        return $value;
      else
        return $default;
    }
  }

  setlocale(LC_ALL, 'en_US');
  bindtextdomain("packetfence", "/usr/local/pf/conf/locale");
  textdomain("packetfence");

  $user_data['ip'] = $_SERVER['REMOTE_ADDR'];

  $PFCMD=dirname(dirname($_SERVER['DOCUMENT_ROOT'])) . '/bin/pfcmd';
  $command = "history $user_data[ip]";
  exec("ARGS=".escapeshellarg($command)." $PFCMD 2>&1", $output, $total);

  $keys = explode('|',array_shift($output));
  $vals = explode('|',array_shift($output));

  for($i=0; $i< count($keys); $i++){
    $user_data[$keys[$i]]=$vals[$i];
  }

  $template = $_GET['template'];
  if($admin == 'yes'){
    $_GET['admin'] = 'yes';
  }

  $remediation_conf = dirname(dirname($_SERVER['DOCUMENT_ROOT'])) . '/conf/ui-global.conf';   

  if(file_exists($remediation_conf)){
    $global_conf = unserialize(file_get_contents($remediation_conf));
    $current = $global_conf['remediation'];
  }

  if(!$preview){
    if(!file_exists($_SERVER['DOCUMENT_ROOT'] . "/content/violations/$template.php") || preg_match("/[\'|\"|\/]/", $template)){
      die("An error occured on this page, please contact the Helpdesk.");
    }

    include($_SERVER['DOCUMENT_ROOT'] . "/content/violations/$template.php");
  }

  $description_header = set_default($description_header, $vid_data['description']);
  $logo_src = set_default($current['logo_src'], "content/images/biohazard-sm.gif");

  if(file_exists('header.html')){
    $custom_header = file_get_contents('header.html'); 
  }

  if(file_exists('footer.html')){
    $custom_footer = file_get_contents('footer.html'); 
  }

  $_GET['admin'] ? $title = "Registration Notification" : $title = "Quarantine Established!";

?>

<html>
<title><?php echo _($title)?></title>

<head>
	<? $abs_url="https://$_SERVER[HTTP_HOST]"; ?>
	<link rel="stylesheet" href="<?=$abs_url?>/content/style.php" type="text/css">
</head>


<body>
<div id='div_body'>

<?if(!$_GET['admin']){ //start non-admin section  ?>
<div id='header'>
	<center>
	<table class='header'>
		<tr>
			<td class='logo'>
				<img src='<?=$abs_url?>/<?=$logo_src?>' id='logo'>  
			</td>
			<td class='title' id='title'>
<?php echo _("Quarantine Established!") ?>
			</td>
		</tr>
	</table>
	</center>
</div>
<?} // end non-admin section?>

<?=$custom_header?>

<div id='description'>
	<p id='description_header' class='sub_header'><?php echo _($description_header) ?></p>
	<span class='description_text'> <?php echo _($description_text) ?> </span>
</div>

<div id='remediation'>
	<p class='sub_header'><?php echo _($remediation_header) ?></p>
	<span class='remediation_text'><?php echo _($remediation_text) ?> </span>
</div>

<?if(!$_GET['admin']){ // start non-admin section ?>
<div id='user_info'>
	<p class='sub_header'><?php echo _("Additional Assistance") ?></p>

	<?php echo _("If your network connectivity becomes permanently disabled or you are unable to follow the instructions above, please contact your local IT support staff for assistance.") ?>

	<?php echo _("The following information should be provided upon request:") ?>

	<ul>
		<li><?php echo _("IP Address") ?> - <?=$user_data['ip']?></li>
		<li><?php echo _("MAC Address") ?> - <?=strtoupper($user_data['mac'])?></li>
	
	</ul>

</div>
<?} // end non-admin section ?>
<?=$custom_footer?>

</div>
</body>

</html>
