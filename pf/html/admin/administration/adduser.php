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

  require_once('../common.php');

  $current_top="administration";
  $current_sub="adduser";

  include_once('../header.php');

  if($_POST['username'] && $_POST['password1'] && $_POST['password2']){
     if(preg_match("/(;|\&|\"|\')/", $_POST['username'])){
       print "<div id='error' style='text-align:left;padding:10px;background:#FF7575;'><b>";
       print "Error: Username contains invalid characters";
       print "</b></div>\n";
       exit;
     }
     if(preg_match("/(;|\'|\"|\&)/", $_POST['password1'])){
       print "<div id='error' style='text-align:left;padding:10px;background:#FF7575;'><b>";
       print "Error: password contains invalid characters";
       print "</b></div>\n";
       exit;
     }


     if($_POST['password1'] != $_POST['password2']) {
       print "<div id='error' style='text-align:left;padding:10px;background:#FF7575;'><b>";
       print "Error: Passwords do not match!";
       print "</b></div>\n";
     } else{
	$filename = dirname(dirname($_SERVER['DOCUMENT_ROOT'])) . "/conf/users/" . $_POST['username'];
        if(file_exists($filename)){
       print "<div id='error' style='text-align:left;padding:10px;background:#FF7575;'><b>";
	  print "Error: User $_POST[username] already exists!";
       print "</b></div>\n";
	}
	else{
  	  exec("/usr/bin/htpasswd -b " . dirname(dirname($_SERVER['DOCUMENT_ROOT'])) . "/conf/admin.conf $_POST[username] $_POST[password1]");
          $defaults = array('font-size' => 'medium', 'homepage' => 'status/dashboard.php');
  	  if (!$handle = fopen($filename, 'w+')) {
            print "<div id='error' style='text-align:left;padding:10px;background:#FF7575;'><b>";
            echo "Error: Cannot open file ($filename)";
            print "</b></div>\n";
            exit;
          }

          if (fwrite($handle, serialize($defaults)) === FALSE) {
            print "<div id='error' style='text-align:left;padding:10px;background:#FF7575;'><b>";
            echo "Error: Cannot write to file ($filename)";
            print "</b></div>\n";
            exit;
          }
          fclose($handle);        
          print "User $_POST[username] added";
       }
    }       
  }

?>

  <div id=add>
  <form action="administration/adduser.php" name="history" method="POST">
  <table class=add>
    <tr><td rowspan=20 valign=top><img src='images/adduser.png' alt=''></td></tr>      
    <tr>
      <td>Username</td>
      <td><input type=text name=username></td>
    </tr>
    <tr>
      <td>Password</td>
      <td><input type='password'  name='password1'></td>
    </tr>
    <tr>
      <td>Password (confirm)</td>
      <td><input type='password' name='password2'></td>
    </tr>
    <tr>
      <td colspan=2 align=right><input type=submit value='Add User'></td>
    </tr>
  </table>
  </form>  
  </div>

<?
  include_once('../footer.php');
?>

