<?
  require_once('../common.php');

  $current_top="class";
  $current_sub="violation";

  $view_item = set_default($_REQUEST['view_item'], 'all');

  $my_table=new table("class view $view_item");
  $my_table->set_linkable(array( array('url', 'class/redirector.php')));
  $is_printable=true;

  $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
  $my_table->set_per_page(set_default($_REQUEST['per_page'],25));

  include_once('../header.php');

  $my_table->tableprint(false);

  include_once('../footer.php');

?>
