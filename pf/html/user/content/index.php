<?php
/**
 * index.php
 *
 * Shows remediation information to the user (called by redir.cgi).
 * Supports a preview mode for Administrators to preview a violation.
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
 * @author      Dominik Gehl <dgehl@inverse.ca>
 * @copyright   2008-2011 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php    GPL
 */

  # if we view this page through Web Admin vhost it means we are in preview mode
  if ($_SERVER["VHOST"] == "ADMIN") {

    # they must be authenticated, the below will take care of it
    include('../../admin/common.php');

    $preview = true;
    $template_path = $_SERVER['DOCUMENT_ROOT'] . "/../user/content/violations";

    # populating with fake data
    $user_data['ip'] = "127.0.0.1";
    $user_data['mac'] = "ff:ff:ff:ff:ff:ff";
  } else {

    # normal mode
    $preview = false;
    $template_path = $_SERVER['DOCUMENT_ROOT'] . "/content/violations";

    # loading user-data
    $user_data['ip'] = $_SERVER['REMOTE_ADDR'];
    # Client IP Lookup if Proxy-Bypass is used
    if ($user_data['ip'] == '127.0.0.1') {
        if (isset($_SERVER['HTTP_X_FORWARDED_FOR'])) {
            $user_data['ip'] = $_SERVER['HTTP_X_FORWARDED_FOR'];
        }
    }

    $PFCMD=dirname(dirname($_SERVER['DOCUMENT_ROOT'])) . '/bin/pfcmd';
    $command = "history $user_data[ip]";
    exec("ARGS=".escapeshellarg($command)." $PFCMD 2>&1", $output, $total);

    $keys = explode('|',array_shift($output));
    $vals = explode('|',array_shift($output));

    for($i=0; $i< count($keys); $i++){
      $user_data[$keys[$i]]=$vals[$i];
    }
  }

  setlocale(LC_ALL, 'en_US');
  bindtextdomain("packetfence", "/usr/local/pf/conf/locale");
  textdomain("packetfence");

  $template = $_GET['template'];
  # verify template's existence
  if (!file_exists("$template_path/$template.php") || preg_match("/[\'|\"|\/]/", $template)) {
      die("An error occured on this page, please contact the Helpdesk.");
  }

  include("$template_path/$template.php");

  $logo_src = "content/images/biohazard-sm.gif";

  if(file_exists('header.html')){
    $custom_header = file_get_contents('header.html'); 
  }

  if(file_exists('footer.html')){
    $custom_footer = file_get_contents('footer.html'); 
  }

  $preview ? $title = "Preview: Quarantine Established!" : $title = "Quarantine Established!";

?>

<html>
<title><?php echo _($title)?></title>

<head>
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
<?php echo _("Quarantine Established!") ?>
            </td>
        </tr>
    </table>
    </center>
</div>

<?=$custom_header?>

<div id='description'>
    <p id='description_header' class='sub_header'><?php echo _($description_header) ?></p>
    <span class='description_text'> <?php echo _($description_text) ?> </span>
</div>

<div id='remediation'>
    <p class='sub_header'><?php echo _($remediation_header) ?></p>
    <span class='remediation_text'><?php echo _($remediation_text) ?> </span>
</div>

<div id='user_info'>
    <p class='sub_header'><?php echo _("Additional Assistance") ?></p>

    <?php echo _("If your network connectivity becomes permanently disabled or you are unable to follow the instructions above, please contact your local IT support staff for assistance.") ?>

    <?php echo _("The following information should be provided upon request:") ?>

    <ul>
        <li><?php echo _("IP Address") ?> - <?=$user_data['ip']?></li>
        <li><?php echo _("MAC Address") ?> - <?=strtoupper($user_data['mac'])?></li>
    
    </ul>

</div>
<?=$custom_footer?>

</div>
</body>

</html>
