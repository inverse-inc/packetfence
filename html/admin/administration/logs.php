<?php
/**
 * logs.php - View server side logs
 *
 * View the content of several log files. Allow users to troubleshoot their
 * PacketFence setup without requiring CLI access.
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

  $current_top="administration";
  $current_sub="logs";

  require_once('../common.php');
  include_once('../header.php');

  # by default lets get the last 500 lines, we might parametrize this
  $LINES = 500;

  # must have access to logs
  $logs_path = get_logs_path();
  if (!is_dir($logs_path)) {
    print_error("Unable to open path $logs_path");
  }

  # logs
  $logs_pages = array();
  $logs_pages['packetfence.log'] = "PacketFence Log";
  $logs_pages['access_log'] = "Captive Portal Access Log";
  $logs_pages['error_log'] = "Captive Portal Error Log";
  $logs_pages['admin_access_log'] = "Web Admin Access Log";
  $logs_pages['admin_debug_log'] = "Web Admin Debug Log";
  $logs_pages['admin_error_log'] = "Web Admin Error Log";
  #ksort($logs_pages);

  # if no file was clicked on, load the first file
  if (isset($_GET['file'])) {
    $filename = $_GET['file'];
  } else {
    $files = array_keys($logs_pages);
    $filename = $files[0];
  }

  # test for file existence in the logs files hash (implies validated filename and existence)
  if (array_key_exists($filename, $logs_pages)) {

    $abs_filename = $logs_path . $filename;
    # tail X lines of log content 
    # safe since filename must be in the above logs_pages whitelist
    $file_content = `tail -n $LINES $abs_filename`;

  } else {
    print_error("Illegal filename");
  }

?>
<script type="text/javascript">
// once dom is loaded, scroll to bottom of textarea
document.observe("dom:loaded", function() {

  $('log-content').scrollTop = $('log-content').scrollHeight;
});
</script>

<div id=content>
<center><?="Click on a log name on the left to view it. Only the last $LINES lines of logs are displayed."?></center>
<table class='configuration'>
<tr>
  <td class='left'><? print_filetable($logs_pages, $filename); ?></td>
  
  <td valign=top style='padding-top:26px;'>
    <table width=90% align=center>
      <tr>
        <td>
          <textarea id='log-content' rows=30 cols=100 name=file_content readonly><?=$file_content?></textarea>
        </td>
      </tr>
    </table>
  </td>
</tr></table>
</div>
<?

function print_filetable ($logs_pages, $selection='') {
    global $current_top, $current_sub;
    print "<ul>";
    foreach ($logs_pages as $filename => $description) {
        $first++ == 0 ? $class = "top" : $class = "";

        if ($selection == $filename) { 
          $class .= " selected";
        }

        print "<li id='$filename' class='$class'><a href='$current_top/$current_sub.php?file=$filename'>
                 $description<span class='arrow'>&raquo;</span>
               </a></li>";
    }
    print "</ul>";
}

include_once('../footer.php');

?>
