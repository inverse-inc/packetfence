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

$current_top="scan";
$current_sub="results";
require_once('../common.php');

# check of the $view_item parameter
$view_item_ok = false;
if (isset($_GET['view_item'])) {
  $view_item = $_GET['view_item'];
  if ((preg_match("/^dump_\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}([-\\\\]\d+)?_\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2}(\.nbe)?$/", $view_item)) &&
      (is_readable("$current_sub/$view_item"))) {
    $view_item_ok = true;
  } else {
}
}

if (isset($_GET['action']) && $_GET['action']=="save") {
  if (! $view_item_ok) {
    die("bad filename");
  }
  header("Content-type: application/text");
  header("Content-Disposition: attachment; filename=$view_item.txt");
  echo file_get_contents("$current_sub/$view_item");
  exit();
}

include_once('../header.php');

if (isset($_GET['action']) && $_GET['action']=="delete") {
  if (! $view_item_ok) {
    die("bad filename");
  }
  if (unlink("$current_sub/$view_item")) {
    echo "<br><font color=red>$view_item removed</font><br>";
  } else {
    echo "<b>Could not remove $view_item</b><br>";    
  }
  unset($view_item);
}


$files = array();
$handle = opendir('results');
while (false !== ($file = readdir($handle))) {
  if (preg_match("/^dump.+(\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2})(\.nbe)?$/", $file, $matches)){
    $files[$matches[1]] = $file;
  }
}

krsort($files);

echo "<div id=history>\n";

echo "  <table class=main>\n";
echo "    <tr>\n";
echo "      <td valign=top>\n";
echo "        <table>";

if (count($files) > 0) {
  foreach($files as $date => $file){
    echo "<tr><td><img src=\"images/dumptruck.gif\" alt=\"\"></td><td valign=\"middle\"><a href=\"$current_top/$current_sub.php?view_item=$file\">$file</a></td>";
    echo "<td><a href=\"$current_top/$current_sub.php?view_item=$file&amp;action=delete\"><img border=0 src='images/delete.png' alt=\"[ Delete ]\" onClick=\"return confirm('Delete this file?');\"></a></td></tr>\n";    
  }
} else {
  echo "<tr><td>No results</td></tr>";
}

echo "        </table>\n";
echo "      </td>\n";

if (isset($view_item) && ($view_item_ok)) {
  echo "<td class=contents valign=top>\n";
  print "<pre>";
  print "<b>$view_item</b>\n";
  print "[<a href=$current_top/$current_sub.php?view_item=$view_item&action=delete onClick=\"return confirm('Delete this file?');\">delete</a>] [<a href=$current_top/$current_sub.php?view_item=$view_item&action=save>save as</a>]\n\n";

  echo file_get_contents("$current_sub/$view_item");
  print "</pre>";
  print "</td>";
};
echo "    </tr>\n";
echo "  </table>\n";
echo "</div>\n";

include_once('../footer.php');

?>


