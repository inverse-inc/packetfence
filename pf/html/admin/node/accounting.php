<?php
/**
 * Node User-Agent Information
 *
 * Screen that displays User-Agent information on the nodes
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
 * @author      Francois Gaudreault <fgaudreault@inverse.ca>
 * @copyright   2011 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

  require_once('../common.php');
 
  $current_top="node";
  $current_sub="accounting";

  include_once('../header.php');

  $view_item = set_default($_REQUEST['view_item'], 'all');

  $my_table=new table("nodeaccounting view active");
  $my_table=new table("nodeaccounting view inactive");

  $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
  $my_table->set_per_page(set_default($_REQUEST['per_page'],100));

  $my_table->set_linkable(array( array('mac', 'node/lookup.php') ));
  $my_table->tableprint(false);

  include_once('../footer.php');

?>
