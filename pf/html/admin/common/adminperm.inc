<?php
/**
 * adminperm.inc: Granular Access Control
 *
 * @copyright	Copyright (C) 2010 Inverse inc.
 * @license	http://opensource.org/licenses/gpl-2.0.php GPLv2 or later
 * @author	Kevin Creechan for eSubnet Enterprises <kcreechan@esubnet.com>
 * @author	Olivier Bilodeau <obilodeau@inverse.ca>
 *
 */

define("ADMIN_PERMISSIONS_SESSION_PREFIX", "adminperms");
define("ADMIN_USERS", "users");
define("ADMIN_PERMS", "permissions");

/*
 * Test user rights and perform actual access prevention if user doesn't have sufficient rights
 */
function perform_access_control($is_popup=0) {
    global $logger;
    // holds current page, required to perform the access control
    global $current_top;

    $delim = "-";  // the usertype-username deliminator is set here.
    
    list($usertype) = explode($delim,$_SESSION['user']);

    parse_permission_file();

    $users = $_SESSION[ADMIN_PERMISSIONS_SESSION_PREFIX][ADMIN_USERS];
    $pages = $_SESSION[ADMIN_PERMISSIONS_SESSION_PREFIX][ADMIN_PERMS];

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

            // in a popup we don't need the footer
            if (!$is_popup) {
                include_once('../footer.php');
            }
    
        } else {
            echo "<html><head><meta http-equiv='refresh' content='0;url=/login.php?'></head><body></body></html>";
        }
        exit();
    }
}

/*
 * Helper to encapsulate the fact that we are using the same underlying code for now
 */ 
function perform_access_control_in_popup() {
    perform_access_control(1);
}
    
/*
 * Parses the permission configuration and put it in session
 */
function parse_permission_file() {
    $fname = "/usr/local/pf/conf/admin.perm";
    $handle = fopen($fname, "r");
    while (!feof($handle)) {
        $buffer = trim(fgets($handle));
        if (substr($buffer,0,1)!="#" AND $buffer!="") {
            if (substr($buffer,0,1)=="u") {
                list($type,$user,$perm) = explode(",",$buffer);
                $_SESSION[ADMIN_PERMISSIONS_SESSION_PREFIX][ADMIN_USERS][$user]=$perm;
            }
            if (substr($buffer,0,1)=="p") {
                list($type,$page,$perm) = explode(",",$buffer);
                $_SESSION[ADMIN_PERMISSIONS_SESSION_PREFIX][ADMIN_PERMS][$page]=$perm;
            }
        }
    }
    $fclose;

    return true;
}
# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
?>
