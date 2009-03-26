<?php
/**
 * @licence http://opensource.org/licenses/gpl-2.0.php GPL
 */

  require_once('../common.php');

  $current_top="node";
  $current_sub="categories";

  $view_item = set_default($_REQUEST['view_item'], 'all');

  $my_table=new table("nodecategory view $view_item");
  $my_table->set_linkable(array(array('name', 'node/view.php?filter_type=category')));

  $is_printable=true;
  $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
  $my_table->set_per_page(set_default($_REQUEST['per_page'],25));

  include_once('../header.php');

  $my_table->tableprint(false);

  include_once('../footer.php');

?>
