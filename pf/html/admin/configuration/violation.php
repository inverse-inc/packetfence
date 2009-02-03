<?
  require_once('../common.php');

  $current_top="configuration";
  $current_sub="violation";

  $view_item = set_default($_REQUEST['view_item'], 'all');

  $my_table=new table("violationconfig get $view_item");
  $my_table->set_editable(true);
  $my_table->set_linkable(array( array('url', 'configuration/instructions.php')));
  $my_table->set_hideable(array('grace', 'priority', 'button_text', 'trigger'));
  $is_printable=true;

  $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
  $my_table->set_per_page(set_default($_REQUEST['per_page'],25));

  include_once('../header.php');

  $my_table->tableprint(false);

  include_once('../footer.php');

?>
