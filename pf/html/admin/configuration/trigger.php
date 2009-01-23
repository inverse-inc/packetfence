<?

  require_once('../common.php');

  $current_top="configuration";
  $current_sub="trigger";

  $view_item = set_default($_REQUEST['view_item'], 'all');

  $my_table=new table("trigger view $view_item");
  $my_table->set_linkable(array( array('vid', 'configuration/violation.php')));

  $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
  $my_table->set_per_page(set_default($_REQUEST['per_page'],100));

  include_once('../header.php');

  $my_table->tableprint(false);

  include_once('../footer.php');

?>
