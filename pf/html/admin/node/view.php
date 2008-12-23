<?

  $current_top="node";
  $current_sub="view";

  require_once('../common.php');

  if (array_key_exists('filter_type', $_REQUEST)) {
    $my_table=new table("node view " . $_REQUEST['filter_type'] . '=' . $_REQUEST['view_item']);
    $my_table->set_default_filter($_REQUEST['filter_type'] . '=' . $_REQUEST['view_item']);
  } else {
    $view_item = set_default($_REQUEST['view_item'], 'all');
    $my_table=new table("node view $view_item");
  }
  $my_table->set_editable(true);
  $is_printable=true;

  include_once('../header.php');

  $my_table->set_violationable(true);
  $my_table->set_linkable(array( array('pid', 'person/lookup.php'), array('mac', 'node/lookup.php'), array('dhcp_fingerprint','class/fingerprint.php') ));
  $my_table->set_hideable(array('lastskp', 'user_agent', 'last_dhcp', 'lastskip', 'last_arp', 'last_arp', 'port', 'switch', 'vlan'));

  $my_table->set_page_num(set_default($_REQUEST['page_num'], 1));
  $my_table->set_per_page(set_default($_REQUEST['per_page'],25));

  $my_table->tableprint(false);

  include_once('../footer.php');

?>
