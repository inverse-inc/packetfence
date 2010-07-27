<?php
/**
 * adminperm.inc: Granular Access Control
 *
 * @copyright	Copyright (C) 2010 Inverse inc.
 * @license	http://opensource.org/licenses/gpl-2.0.php GPLv2 or later
 * @author	Kevin Creechan for eSubnet Enterprises <kcreechan@esubnet.com>
 *
 */

$delim = "-";  // the usertype-username deliminator is set here.

list($usertype) = explode($delim,$_SESSION['user']);

$fname = "/usr/local/pf/conf/admin.perm";
$handle = fopen($fname, "r");
$users=array();
$pages=array();
while (!feof($handle)) {
    $buffer = trim(fgets($handle));
    if (substr($buffer,0,1)!="#" AND $buffer!="") {
        if (substr($buffer,0,1)=="u") {
            list($type,$user,$perm) = explode(",",$buffer);
            $users[$user]=$perm;
        }
        if (substr($buffer,0,1)=="p") {
            list($type,$page,$perm) = explode(",",$buffer);
            $pages[$page]=$perm;
        }
    }
}
$fclose;

if (array_key_exists($usertype, $users)!=TRUE) {
    echo "<html><head><meta http-equiv='refresh' content='4;url=/login.php?logout=true'></head><body>";
    echo "<br /><br /><br /><br /><br /><center>User does not exist in admin.perms<br /><br /><br />Logging out.<br /><br /><br /><br /><br /><br /></center>";
    echo "</body></html>";
    exit();
}

if ($users[$usertype]<$pages[$current_top]) {

    // echo "BAD HIT";
    if ($current_top!="status") {

	// insufficient permissions, we notice them
        echo "<div id='message_box'>You have insufficient permissions to view this page.</div>";
        include_once('../footer.php');

    } else {
        echo "<html><head><meta http-equiv='refresh' content='0;url=/login.php?'></head><body></body></html>";
    }
    exit();
}

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
?>
