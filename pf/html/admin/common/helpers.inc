<?php
/**
 * @licence http://opensource.org/licenses/gpl-2.0.php GPL
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

?>
