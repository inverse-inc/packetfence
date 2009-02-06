<?
  require_once('../common.php');

  $current_top="configuration";
  $current_sub="interfaces";

  $view_item = set_default($_REQUEST['view_item'], 'all');

  $my_table=new table("interfaceconfig get $view_item");
  include_once('../header.php');

  $is_printable=true;
  $my_table->set_editable(true);
  $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
  $my_table->set_per_page(set_default($_REQUEST['per_page'],25));

  $my_table->tableprint(false);

  include_once('../footer.php');

?>
