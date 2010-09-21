<?php
/**
 * TODO short desc
 *
 * TODO long desc
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
 * USA.
 * 
 * @author      Olivier Bilodeau <obilodeau@inverse.ca>
 * @copyright   2008-2010 Inverse inc.
 * @licence     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

  ## HEADERS FOR DOWNLOADING CSV ##
  if(isset($download) && $download==true){
    if($filter)
      $my_rows=$my_table->tablefilter($filter);
    else
      $my_rows=$my_table->rows;

    $csv_output.=implode(",",$my_table->headers)."\n";
    foreach($my_rows as $my_row)
      $csv_output.=implode(",",$my_row)."\n";
    CSVify($csv_output, "application/text", "$current_top.csv");
    die();
  }

  if($sajax){
    sajax_init();
    sajax_export($sajax);
    sajax_handle_client_request();  
  }


  ## PFCMD STUFF ##

  if(isset($_POST['commit'])){

    if($_POST['action'] == "delete"){
      $new_array=preg_split("/\t/", $_POST['original']);
      if (preg_match("/\s/", $new_array[0]))
        $new_array[0]  = '"'.$new_array[0].'"';
      if ($current_top == "scan") {
        $cmd = "schedule $_POST[action] $new_array[0]";
      } else if (($current_top == 'configuration') && ($current_sub=='interfaces')) {
        $cmd = "interfaceconfig delete $new_array[0]";
      } else if (($current_top == 'configuration') && ($current_sub=='networks')) {
        $cmd = "networkconfig delete $new_array[0]";
      } else if (($current_top == 'configuration') && ($current_sub=='switches')) {
        $cmd = "switchconfig delete $new_array[0]";
      } else if (($current_top == 'configuration') && ($current_sub=='floatingnetworkdevice')) {
        $cmd = "floatingnetworkdeviceconfig delete $new_array[0]";
      } else if (($current_top == 'configuration') && ($current_sub=='violation')) {
        $cmd = "violationconfig delete $new_array[0]";
      } else if (($current_top == 'node') && ($current_sub=='categories')) {
        $cmd = "nodecategory delete $new_array[0]";
      } else {
        $cmd="$current_top $_POST[action] $new_array[0]";
      }
    }

    if($_REQUEST['action'] == 'edit' || $_REQUEST['action'] == 'add'){
      $new_array=$orig_array=split("/\|/", $_POST['original']);
      $_POST['count'] ? $count = $_POST['count'] : $count = count($my_table->headers);

      for($i=0; $i<$count; $i++){
        $value="val$i";
        $new_array[$i]=$_POST[$value];
      }
      $headers=meta("$current_top-add");

      if($current_top=="scan")
        $headers=meta("scan-nessus");

      $a=-1;
      for($i=0; $i<count($headers); $i++){
	  if(preg_match("/^\-/", $headers[$i][0])){
	    continue;
	  }
          $a++;
          if(preg_match("/\*$/", $headers[$i][0]))
            if (preg_match("/\s/", $new_array[$a])){
              $key = '"'.$new_array[$a].'"';
	    }
            else{ 
              $key = $new_array[$a]; 
            }
          else
            $cmd[]=$headers[$i][0].'="'.$new_array[$a].'"';
      }

      $cmd=implode(",", $cmd);
      $cmd="$current_top $_REQUEST[action] $key $cmd";
    }

    $result=PFCMD($cmd);

    if($_REQUEST['action'] == 'edit' || $_REQUEST['action'] == 'delete'){
      $my_table->refresh(); 
    }
  }

  if ( (isset($_GET['size'])) && (in_array($_GET['size'], array('small', 'medium', 'large'))) ) {
    $_SESSION['txt_size']=$_GET['size'];
  }

?>

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">

<html>
<head>
  <title>PF::<?php echo ucfirst($current_top)?>::<?php echo ucfirst($current_sub)?></title>
  <base href="<?=$abs_url?>/">
  <link rel="shortcut icon" href="/favicon.ico">
  <link rel="stylesheet" href="style.css" type="text/css"> 

  <style type="text/css">@import url(<?=$abs_url?>/3rdparty/calendar/calendar-pf.css);</style>
  <script type="text/javascript" src="<?=$abs_url?>/3rdparty/calendar/calendar.js"></script>
  <script type="text/javascript" src="<?=$abs_url?>/3rdparty/calendar/lang/calendar-en.js"></script>
  <script type="text/javascript" src="<?=$abs_url?>/3rdparty/calendar/calendar-setup.js"></script>

  <script type="text/javascript">
    <?
      if($sajax){
       sajax_show_javascript();
       include("$current_top/sajax.js"); 
      }
    ?>

    function popUp(URL, height, width) {
      day = new Date();
      id = day.getTime();
      eval("page" + id + " = window.open(URL, '', 'toolbar=0,scrollbars=1,location=0,statusbar=0,menubar=0,resizable=1,width=' + width + ',height=' + height + '');");
    }

    function hideCells(mode) {
      if(mode == ""){
        document.getElementById("show_icon").style.display = "none";
        document.getElementById("hide_icon").style.display = "";
      }
      else{
        document.getElementById("hide_icon").style.display = "none";
        document.getElementById("show_icon").style.display = "";
      }

      var tags = document.getElementsByTagName("td");
      var regEx = eval("/^id[0-9]+$/");    
 
      for (var i=0; i < tags.length; i++) {   
        var thisID = tags[i].id;
        if (thisID.match(regEx) ) {   
          document.getElementById(thisID).style.display = mode;
        }
      }
    }
   
    sfHover = function() {
      var sfEls = document.getElementById("navlist").getElementsByTagName("LI");
      for (var i=0; i<sfEls.length; i++) {
        sfEls[i].onmouseover=function() {
	  this.className+=" sfhover";
	}
        sfEls[i].onmouseout=function() {
          this.className=this.className.replace(new RegExp(" sfhover\\b"), "");
        }
      }
    }

    if (window.attachEvent) window.attachEvent("onload", sfHover);
  </script>
</head>

<body>

<div id="container">

<table id="main" style="width:100%;" cellspacing="0" cellpadding="0">
  <tr colspan="2">
    <td valign="top">
      <a href="index.php"><img border="0" src="/common/packetfence.png" align="right" width="193" height="60" alt="[ Packetfence ]"></a>
    </td>
  </tr>
  <tr colspan="2">
    <td valign="bottom" width="100%">
      <?php PrintTopNav() ?>
    </td>
  </tr>
  <tr>
    <td class="subnav" colspan="2">
      <?php PrintSubNav($current_top) ?>
    </td>
  </tr>
  <tr>
    <td class="content" height="100%" valign="top" colspan="2">

<!-- Begin Content -->
<div id="content">

<?php
perform_access_control();
