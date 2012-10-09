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
 * @copyright   2008-2012 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

  require_once('../common.php');

  $current_top="configuration";
  $current_sub="switches";

  $view_item = set_default($_REQUEST['view_item'], 'all');

  $my_table=new table("switchconfig get $view_item");
  include_once('../header.php');

  $is_printable=true;
  $my_table->set_editable(true);
  $fields_to_hide_by_default = array(
      'cliTransport', 'cliUser', 'cliPwd', 'cliEnablePwd', 
      'wsTransport', 'wsUser', 'wsPwd', 
      'radiusSecret', 'controllerIp', 'roles',
      'macSearchesMaxNb', 'macSearchesSleepInterval', 
      'SNMPVersion', 'SNMPCommunityRead', 'SNMPCommunityWrite', 'SNMPVersionTrap', 'SNMPCommunityTrap', 
      'SNMPEngineID', 'SNMPUserNameRead', 'SNMPAuthProtocolRead', 
      'SNMPAuthPasswordRead', 'SNMPPrivProtocolRead', 'SNMPPrivPasswordRead', 
      'SNMPUserNameWrite', 'SNMPAuthProtocolWrite', 'SNMPAuthPasswordWrite', 
      'SNMPPrivProtocolWrite', 'SNMPPrivPasswordWrite', 'SNMPUserNameTrap', 
      'SNMPAuthProtocolTrap', 'SNMPAuthPasswordTrap', 'SNMPPrivProtocolTrap', 
      'SNMPPrivPasswordTrap','inlineTrigger', 
  );
  # adding customVlan1 to 99 to the hidden list
  for ($i = 1; $i <= 99; $i++) {
      $fields_to_hide_by_default[] = 'customVlan' . $i;
  };
  $my_table->set_hideable($fields_to_hide_by_default);
  $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
  $my_table->set_per_page(set_default($_REQUEST['per_page'],25));

  $my_table->tableprint(false);

  include_once('../footer.php');

?>
