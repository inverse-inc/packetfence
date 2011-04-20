<?php
/**
 * captive-portal.php - Captive Portal configuration / customization
 *
 * Remediation pages content modifications. 
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
 * @copyright   2011 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 * 
 */

  $current_top="configuration";
  $current_sub="captive-portal";

  require_once('../common.php');
  include_once('../header.php');

  # TODO refactoring extract into methods

  $remediation_pages = array();
  # must have access to remediation templates
  $remediation_path = realpath($_SERVER['DOCUMENT_ROOT'] . '/../user/content/violations');
  if (!is_dir($remediation_path)) {
    print_error("Unable to open path $remediation_path");
  }

  # loop on remediation templates
  if ($dh = opendir($remediation_path)) {
    while (($file = readdir($dh)) !== false) {
      # ignore ., .. and all files not ending with .php
      if ($file != "." && $file != ".." && preg_match("/\.php$/", $file)) {
        $remediation_pages[$file] = array(
          'filename_abs' => $remediation_path . '/' . $file,
          'last-modified' => filemtime($remediation_path . '/' . $file)
        );
      }
    }
    closedir($dh);
  }
  ksort($remediation_pages);

  # USER SUBMITS CHANGES TO FILE
  if (isset($_POST['save'])) {

    $filename = $_POST['filename'];
    # test for file existence in the remediation files hash (implies validated filename and existence)
    if (array_key_exists($filename, $remediation_pages)) {

      # if last-modified is different there's a conflict
      if ($remediation_pages[$filename]['last-modified'] != $_POST['last-modified']) {
        print_error(
          "Other changes happened to the file during modification! "
          . "Please review and merge the changes below."
        );
        $file_content = "<<<<<<< Your content\n";
        $file_content .= $_POST['file_content'];
        $file_content .= "=======\n";
        $file_content .= file_get_contents($remediation_pages[$filename]['filename_abs']);
        $file_content .= ">>>>>>> Filesystem content\n";
        $last_modified = $remediation_pages[$filename]['last-modified'];

      } else {

        $filename_abs = $remediation_pages[$filename]['filename_abs'];
        $success = false;
        if (is_writable($filename_abs)) {

          if ($handle = fopen($filename_abs, 'w')) {

            if (fwrite($handle, $_POST['file_content']) === FALSE) {
              print_error("Cannot write to file ($filename_abs)");
            } else {
              $success = true;
            }
          } else {
            print_error("Cannot open file ($filename_abs) for writing..");
          }

          fclose($handle);

        } else {
          print_error(
            "$filename is not writable. Verify the permissions of files in $remediation_path/. "
            . "Changes were NOT saved."
          );
        }

        if ($success === TRUE) {
          print_notice("Changes to $filename saved successfully!");
          $file_content = file_get_contents($remediation_pages[$filename]['filename_abs']);
          $last_modified = $remediation_pages[$filename]['last-modified'];
        } else {
          # writing failed so we send back data we received to avoid user data loss
          $file_content = $_POST['file_content'];
          $last_modified = $_POST['last-modified'];
        }

      }

    } else {
      print_error("Illegal filename");
    }

  } else {

    # if no file was clicked on, load the first file
    if (isset($_GET['file'])) {
      $filename = $_GET['file'];
    } else {
      $files = array_keys($remediation_pages);
      $filename = $files[0];
    }
  
    # test for file existence in the remediation files hash (implies validated filename and existence)
    if (array_key_exists($filename, $remediation_pages)) {
  
      # grab file content
      $file_content = file_get_contents($remediation_pages[$filename]['filename_abs']);
      $last_modified = $remediation_pages[$filename]['last-modified'];
  
    } else {
      print_error("Illegal filename");
    }
  }

?>

<div id=content>
<center>Here are the various remediation pages. Click on one to edit it.</center>
<table class='configuration'>
<tr>
  <td class='left'><? print_filetable($remediation_pages, $filename); ?></td>
  
  <td valign=top style='padding-top:25px;'>
    <form action='<?=$current_top."/".$current_sub?>.php' method='POST'>
    <table width=90% align=center>
      <tr>
        <td>
          <textarea rows=30 cols=100 name=file_content><?=$file_content?></textarea>
          <input type='hidden' name='last-modified' value='<?=$last_modified?>'>
          <input type='hidden' name='filename' value='<?=$filename?>'>
        </td>
      </tr>
      <tr><td class='buttonbar'>
        Note: You can preview remediation pages from the Config -&gt; Violation window
        <input type='submit' name="save" value='Save changes'>
      </td></tr>
    </table>
    </form>
  </td>
</tr></table>
</div>

<?

function print_filetable ($remediation_pages, $selection='') {
    global $current_top, $current_sub;
    foreach ($remediation_pages as $filename => $data) {
        $first++ == 0 ? $class = "top" : $class = "";

        if ($selection == $filename) { 
          $class .= " selected";
        }

        // I'm a bit disgusted of myself but at least it's not as bad as main.php
        print "<a href='$current_top/$current_sub.php?file=$filename'>
                 <div id='$filename' class='$class'><table><tr>
                 <td>$filename</td><td class='arrow'>&raquo;</td></tr></table>
               </div></a>";
    }
}

include_once('../footer.php');

?>
