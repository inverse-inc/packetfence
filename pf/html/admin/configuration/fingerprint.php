<?php
/**
 * @licence http://opensource.org/licenses/gpl-2.0.php GPL
 */

  require_once('../common.php');
 
  $current_top="configuration";
  $current_sub="fingerprint";

  include_once('../header.php');

  get_global_conf();

  ## Updating DHCP Fingerprints ##
  if($_REQUEST['update']){
    $msg = update_fingerprints();
  } 

  ## Sharing Fingerprints ##
  if($_REQUEST['upload']){
    if($msg){ $msg.="<br>"; }
    $msg .= share_fingerprints($my_table->rows);
  }
  if($_GET['gracias']){
    $msg .= "Thank you for sharing your unknown fingerprints!";
  }

  if($msg){
    $extra_goodness = "<div id='message_box'>$msg</div>";
  }
  else{
    $extra_goodness = "<div id='message_box'><table align=center><tr><td style='padding-right:20px;'>
		 	 <a href='$current_top/$current_sub.php?menu=$_GET[menu]&amp;type=$_GET[type]&amp;upload=true'><img src='images/up.png' alt='Share Unknown Fingerprints' title='Share Unknown Fingerprints'>Share Unknown Fingerprints</a>
		       </td><td>
   		         <a href='$current_top/$current_sub.php?menu=$_GET[menu]&amp;type=$_GET[type]&amp;update=true'><img src='images/update.png' alt='Update Fingerprints &amp; OUI Prefixes' title='Update Fingerprints &amp; OUI Prefixes'>Update Fingerprints &amp; OUI Prefixes</a>
		       </td></tr></table></div>";
  }


  $view_item = set_default($_REQUEST['view_item'], 'all');

  $my_table=new table("fingerprint view $view_item");

  $my_table->set_page_num(set_default($_REQUEST['page_num'],1));
  $my_table->set_per_page(set_default($_REQUEST['per_page'],100));

  $my_table->tableprint(false);

  include_once('../footer.php');

?>
