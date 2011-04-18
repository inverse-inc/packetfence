<?php
/**
 * User-Agent Violation Information
 *
 * Screen that displays available User-Agent violations types
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
 */

  require_once('../common.php');
 
  $current_top="configuration";
  $current_sub="useragent";

  get_global_conf();

  ## Sharing User-Agent Fingerprints ##
  if($_REQUEST['upload']){
    if($msg){ $msg.="<br>"; }
    $msg .= share_useragents($my_table->rows);
  }
  if($_GET['gracias']){
    $msg .= "Thank you for sharing your unknown fingerprints!";
  }

  if($msg){
    $extra_goodness = "<div id='message_box'>$msg</div>";
  }
  else{
    $extra_goodness = "
        <div id='message_box'>
          <a href='$current_top/$current_sub.php?menu=$_GET[menu]&amp;type=$_GET[type]&amp;upload=true'><img src='images/up.png' alt='Share Unknown User-Agent Fingerprints' title='Share Unknown User-Agent Fingerprints'>Share Unknown User-Agent Fingerprints</a>
        </div>";
  }

  include_once('../header.php');

  $view_item = set_default($_REQUEST['view_item'], 'all');

  $my_table=new table("useragent view $view_item");

  $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
  $my_table->set_per_page(set_default($_REQUEST['per_page'],100));

  $my_table->tableprint(false);

  include_once('../footer.php');

?>
