<?

  if(isset($_REQUEST['filter']) && (substr($_REQUEST['filter'],0,9) == 'category=')) {
    header("Location: $abs_url/node/view.php?filter_type=category&view_item=" . substr($_REQUEST['filter'],9) . "&sort=" . $_REQUEST['sort'] . "&direction=" . $_REQUEST['direction'] . "&per_page=" . $_REQUEST['per_page'] . "&page_num=" . $_REQUEST['page_num']);
    exit;
  }
  if(isset($_REQUEST['filter']) && (substr($_REQUEST['filter'],0,4) == 'pid=')) {
    header("Location: $abs_url/node/view.php?filter_type=pid&view_item=" . substr($_REQUEST['filter'],4) . "&sort=" . $_REQUEST['sort'] . "&direction=" . $_REQUEST['direction'] . "&per_page=" . $_REQUEST['per_page'] . "&page_num=" . $_REQUEST['page_num']);
    exit;
  }


  $current_top="node";
  $current_sub="view";

  require_once('../common.php');

  $page_num = set_default($_REQUEST['page_num'], 1);
  $per_page = set_default($_REQUEST['per_page'],25);

  $sort = set_default($_GET['sort'], 'mac');
  $direction = strtolower(set_default($_GET['direction'], 'asc'));

  $limit_clause = '';
  if ((! isset($_REQUEST['filter'])) || ($_REQUEST['filter'] == '')) {
    $limit_clause = "limit " . (($page_num-1)*$per_page) . "," . $per_page;
  }

  if (array_key_exists('filter_type', $_REQUEST)) {
    $my_table=new table("node view " . $_REQUEST['filter_type'] . '=' . $_REQUEST['view_item'] . " order by $sort $direction " . $limit_clause);
    $my_table->set_default_filter($_REQUEST['filter_type'] . '=' . $_REQUEST['view_item']);
    if (! isset($_REQUEST['filter'])) {
      $result_count = PFCMD("node count " . $_REQUEST['filter_type'] . '=' . $_REQUEST['view_item']);
      if ($result_count[1] >= 0) {
        $my_table->set_result_count($result_count[1]);
      }
    }
  } else {
    $view_item = set_default($_REQUEST['view_item'], 'all');
    $my_table=new table("node view $view_item order by $sort $direction $limit_clause");
    if ((! isset($_REQUEST['filter'])) || ($_REQUEST['filter'] == '')) {
      $result_count = PFCMD("node count $view_item");
      if ($result_count[1] >= 0) {
        $my_table->set_result_count($result_count[1]);
      }
    }
  }



  $my_table->set_editable(true);
  $is_printable=true;

  include_once('../header.php');

  $my_table->set_violationable(true);
  $my_table->set_linkable(array( array('pid', 'person/lookup.php'), array('mac', 'node/lookup.php'), array('dhcp_fingerprint','configuration/fingerprint.php') ));
  $my_table->set_hideable(array('lastskp', 'user_agent', 'last_dhcp', 'lastskip', 'last_arp', 'last_arp', 'port', 'switch', 'vlan'));

  $my_table->set_page_num($page_num);
  $my_table->set_per_page($per_page);

  if ((! isset($_REQUEST['filter'])) || ($_REQUEST['filter'] == '')) {
    $my_table->set_sql_sort_and_limit(true);
  }

  $my_table->tableprint(false);

  include_once('../footer.php');

?>
