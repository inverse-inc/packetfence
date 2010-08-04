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

// default permission file
define("ADMIN_PERMISSIONS_FILE", "/usr/local/pf/conf/admin.perm");
// where is info stored in session
define("ADMIN_PERMISSIONS_SESSION_PREFIX", "adminperms");
// fileformat information
define("ADMIN_USERS", "users");
define("ADMIN_ROLES", "roles");
define("ADMIN_PERMS", "permissions");
// default role entry
define("ADMIN_DEFAULT_ROLE", "default_role");

/*
 * Test user rights and perform actual access prevention if user doesn't have sufficient rights
 */
function perform_access_control($is_popup=0) {
    global $logger;
    // holds current page, required to perform the access control
    global $current_top;
    $user = $_SESSION['user'];

    parse_permission_file();

    // assigning into easier to read variables
    $users = $_SESSION[ADMIN_PERMISSIONS_SESSION_PREFIX][ADMIN_USERS];
    $roles = $_SESSION[ADMIN_PERMISSIONS_SESSION_PREFIX][ADMIN_ROLES];
    $perms = $_SESSION[ADMIN_PERMISSIONS_SESSION_PREFIX][ADMIN_PERMS];

    // does the current user exist in permission tables?
    if (array_key_exists($user, $users)!=TRUE) {

        // if not, does a default role exist?
        if (array_key_exists(ADMIN_DEFAULT_ROLE, $users)!=TRUE) {

            echo "<html><head><meta http-equiv='refresh' content='4;url=/login.php?logout=true'></head><body>";
            echo "<br /><br /><br /><br /><br /><center>"
                ."User does not exist in permission configuration files and a default role is not defined. "
                ."Check the ".ADMIN_PERMISSIONS_FILE." file."
                ."<br /><br /><br />Logging out.<br /><br /><br /><br /><br /><br /></center>";
            echo "</body></html>";
            exit();
        } else {
            $logger->debug("User not defined, using ".ADMIN_DEFAULT_ROLE." instead.");
            $role = $users[ADMIN_DEFAULT_ROLE];
        }
    } else {
        // storing users' role
        $role = $users[$user];
    }

    $logger->debug("Looking up permission-level for user $user with role $role.");

    // validating roles and permissions
    if (!isset($roles, $perms) || !array_key_exists($role, $roles) || !array_key_exists($current_top, $perms)) {
        // insufficient permissions, we notice them
        echo "<div id='message_box'>Something is wrong with the web admin permission system. "
            ."Check admin debug logs for details.</div>";
        $logger->debug("Permission table: ".var_export($_SESSION[ADMIN_PERMISSIONS_SESSION_PREFIX], true));

        // in a popup we don't need the footer
        if (!$is_popup) {
            include_once('../footer.php');
        }
        exit();
    }

    if ($roles[$role]<$perms[$current_top]) {
    
        // Status page is handled differently below (redirects to login)
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
 * Parses the permission configuration and put it in $_SESSION
 */
function parse_permission_file() {

    $perms_file_content = parse_ini_file(ADMIN_PERMISSIONS_FILE, true);

    // Starting with PHP 5.2.7 parse_ini_file returns false instead of empty array
    if (empty($perms_file_content) || $perms_file_content == false) {

        echo "<div id='message_box'>"
            ."Something went wrong trying to parse the ".ADMIN_PERMISSIONS_FILE." permission file. "
            ."Validate the file syntax."
            ."</div>";

        // in a popup we don't need the footer
        if (!$is_popup) {
            include_once('../footer.php');
        }
        exit();
    }
    $_SESSION[ADMIN_PERMISSIONS_SESSION_PREFIX] = $perms_file_content;

    return true;
}
# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
?>
