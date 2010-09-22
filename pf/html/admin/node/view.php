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
 * @author      Olivier Bilodeau <obilodeau@inverse.ca>
 * @copyright   2008-2010 Inverse inc.
 * @licence     http://opensource.org/licenses/gpl-2.0.php      GPL
 */


  if(isset($_REQUEST['filter']) && (substr($_REQUEST['filter'],0,9) == 'category=')) {
    header("Location: $abs_url/node/view.php?filter_type=category&view_item=" . substr($_REQUEST['filter'],9) . "&sort=" . $_REQUEST['sort'] . "&direction=" . $_REQUEST['direction'] . "&per_page=" . $_REQUEST['per_page'] . "&page_num=" . $_REQUEST['page_num']);
    exit;
  }
  if(isset($_REQUEST['filter']) && (substr($_REQUEST['filter'],0,4) == 'pid=')) {
    header("Location: $abs_url/node/view.php?filter_type=pid&view_item=" . substr($_REQUEST['filter'],4) . "&sort=" . $_REQUEST['sort'] . "&direction=" . $_REQUEST['direction'] . "&per_page=" . $_REQUEST['per_page'] . "&page_num=" . $_REQUEST['page_num']);
    exit;
  }


  $current_top="node";
  $current_sub="view";

  require_once('../common.php');

  $page_num = set_default($_REQUEST['page_num'], 1);
  $per_page = set_default($_REQUEST['per_page'],25);

  # TODO change the default sort values to something meaningful
  $sort = set_default($_GET['sort'], 'mac');
  $direction = strtolower(set_default($_GET['direction'], 'asc'));

  $limit_clause = '';
  if ((! isset($_REQUEST['filter'])) || ($_REQUEST['filter'] == '')) {
    $limit_clause = "limit " . (($page_num-1)*$per_page) . "," . $per_page;
  }

  if (array_key_exists('filter_type', $_REQUEST)) {
    $my_table=new table("node view " . $_REQUEST['filter_type'] . '=' . $_REQUEST['view_item'] . " order by $sort $direction " . $limit_clause);
    $my_table->set_count_cmd("node count " . $_REQUEST['filter_type'] . '=' . $_REQUEST['view_item']);
    $my_table->count_result();
  } else {
    $view_item = set_default($_REQUEST['view_item'], 'all');
    $my_table=new table("node view $view_item order by $sort $direction $limit_clause");
    if ((! isset($_REQUEST['filter'])) || ($_REQUEST['filter'] == '')) {
      $my_table->set_count_cmd("node count $view_item");
      $my_table->count_result();
    }
  }

  $my_table->set_editable(true);
  $is_printable=true;

  include_once('../header.php');

  $my_table->set_violationable(true);
  $my_table->set_linkable(array( array('pid', 'person/lookup.php'), array('mac', 'node/lookup.php'), array('dhcp_fingerprint','configuration/fingerprint.php') ));
  $my_table->set_hideable(array('lastskp', 'user_agent', 'last_dhcp', 'lastskip', 'last_arp', 'last_arp', 'port', 'switch', 'vlan', 'voip', 'connection_type'));

  $my_table->set_page_num($page_num);
  $my_table->set_per_page($per_page);

  if ((! isset($_REQUEST['filter'])) || ($_REQUEST['filter'] == '')) {
    $my_table->set_sql_sort_and_limit(true);
  }

  $my_table->tableprint(false);

  include_once('../footer.php');

?>
