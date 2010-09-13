<?php
/**
 * @licence http://opensource.org/licenses/gpl-2.0.php GPL
 */

  require_once('../common.php');

  $current_top="configuration";
  $current_sub="switches";

  $view_item = set_default($_REQUEST['view_item'], 'all');

  $my_table=new table("switchconfig get $view_item");
  include_once('../header.php');

  $is_printable=true;
  $my_table->set_editable(true);
  $my_table->set_hideable(array('SNMPVersion', 'SNMPCommunityRead', 'SNMPCommunityWrite', 'SNMPVersionTrap', 'SNMPCommunityTrap', 'cliTransport', 'cliUser', 'cliPwd', 'cliEnablePwd', 'wsTransport', 'wsUser', 'wsPwd', 'customVlan1', 'customVlan2', 'customVlan3', 'customVlan4', 'customVlan5', 'macSearchesMaxNb', 'macSearchesSleepInterval', 'VoIPEnabled', 'voiceVlan', 'SNMPEngineID', 'SNMPUserNameRead', 'SNMPAuthProtocolRead', 'SNMPAuthPasswordRead', 'SNMPPrivProtocolRead', 'SNMPPrivPasswordRead', 'SNMPUserNameWrite', 'SNMPAuthProtocolWrite', 'SNMPAuthPasswordWrite', 'SNMPPrivProtocolWrite', 'SNMPPrivPasswordWrite', 'SNMPUserNameTrap', 'SNMPAuthProtocolTrap', 'SNMPAuthPasswordTrap', 'SNMPPrivProtocolTrap', 'SNMPPrivPasswordTrap'));
  $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
  $my_table->set_per_page(set_default($_REQUEST['per_page'],25));

  $my_table->tableprint(false);

  include_once('../footer.php');

?>
