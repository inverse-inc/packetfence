<?php
/**
 * helpers.inc: helpers functions
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
 * @copyright   2010 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPLv2 or later
 */

    /*
     * Stores nodecategory information in session
     */
    function nodecategory_caching() {
        global $logger;
        if (!isset($_SESSION['nodecategory'])) {
          $nodecategory_table=new table("nodecategory view all");
          if ($nodecategory_table->rows){
            foreach ($nodecategory_table->rows as $row) {
              $_SESSION['nodecategory'][$row['category_id']] = $row['name'];
            }
          }
          $logger->debug("nodecategory cached");
        }
    }

    /*
     * Gives back a cat_id => name array if the nodecategory cache is filled, empty array otherwise
     */
    function get_nodecategories() {
        global $logger;
        if (isset($_SESSION['nodecategory'])) {
           return $_SESSION['nodecategory'];
        } else {
           $logger->debug("nodecategory cache is not set");
           return array();
        }
    }

    /*
     * Gives back a special array meant for printSelect. It includes a "No category" and does the right thing with keys
     */
    function get_nodecategories_for_dropdown() {
        // first, a 'No category' entry
        $cat_for_drop[''] = 'No category';

        $categories = get_nodecategories();
        // we want a value => value hash to get the form right for pfcmd (it expects category names not ids)
        foreach ($categories as $value) {
            $cat_for_drop[$value] = $value; 
        }
        return $cat_for_drop;
    }

    /*
     * Invalidates nodecategory information in session, this way the next call to nodecategory_caching will cache
     */
    function invalidate_nodecategory_cache() {
        global $logger;
        if (isset($_SESSION['nodecategory'])) {
            $logger->debug("nodecategory cache invalidated, will be reloaded on next nodecategory_caching call");
            unset($_SESSION['nodecategory']);
        }
    }

    /*
     * Gives back array meant for printSelect that outputs possible values for a node's status
     */
    function get_node_status_for_dropdown() {
        return array(
            'unreg' => 'Unregistered',
            'reg' => 'Registered',
            'grace' => 'Grace',
            'pending' => 'Pending approval'
        );
    }

    /*
     * Returns full path where pf is installed
     */
    function get_pf_path() {
        return '/usr/local/pf/';
    }

    /*
     * Returns var path
     */
    function get_var_path() {
        return get_pf_path() . 'var/';
    }

    /*
     * is_protected_vid - returns true or false based on if a violation class should allowed to be deleted or not
     * Encapsulate business logic about protected violation classes.
     */
    function is_protected_vid($vid) {
        // defaults, 1100000, 1200000, 1300000 are protected
        if (preg_match("/^(?:1[123]\d\d\d\d\d)|(?:defaults)$/", $vid)) {
            return true;
        } else {
            return false;
        }
    }
