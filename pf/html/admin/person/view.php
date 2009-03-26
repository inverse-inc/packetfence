<?php
/**
 * @licence http://opensource.org/licenses/gpl-2.0.php GPL
 */

  require_once('../common.php');

  $current_top="person";
  $current_sub="view";

  $view_item = set_default($_REQUEST['view_item'], 'all');

  $my_table=new table("person view $view_item");
  $my_table->set_editable(true);
  $is_printable=true;

  include_once('../header.php');

  $my_table->set_linkable(array( array('pid', 'person/lookup.php')));

  $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
  $my_table->set_per_page(set_default($_REQUEST['per_page'],25));

  $my_table->tableprint(false);

  include_once('../footer.php');

?>
