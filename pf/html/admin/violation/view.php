<?php
/**
 * @licence http://opensource.org/licenses/gpl-2.0.php GPL
 */


  $current_top="violation";
  $current_sub="view";

  require('../common.php');

  $my_table=new table("violation view all");
  $my_table->set_editable(true);
  $my_table->set_linkable(array( array('vid', 'configuration/violation.php'), array('mac','node/view.php')));
  $is_printable=true;

  $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
  $my_table->set_per_page(set_default($_REQUEST['per_page'],25));

  include_once('../header.php');

  $my_table->tableprint(false);

  include_once('../footer.php');

?>
