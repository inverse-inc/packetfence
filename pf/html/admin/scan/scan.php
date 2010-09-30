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
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

$current_top="scan";
$current_sub="scan";

require_once('../common.php');


function print_time_options() {
  for ($i=0; $i<=23;$i++) {
    for ($ii=0; $ii<=50; $ii+=10) {
      printf ("                <option value=\"%d:%d\">%02d:%02d</option>\n", $i, $ii, $i, $ii); 
    }
  }
}

$my_table=new table("schedule view all");
$my_table->set_editable(true);

if (isset($page_num)) {
  $my_table->set_page_num($page_num);
}
if (isset($per_page)) {
  $my_table->set_per_page($per_page);
}

include_once('../header.php');

if(isset($_REQUEST[action]) && $_REQUEST[action]=='add'){
  ## HOSTS ##
  if(isset($_POST[host])) {
    #if (preg_match("/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}([-\/]\d+)?$/", $host)) {
    if (preg_match("/^(?:\d{1,3}\.){3}\d{1,3}([-\/]\d+)?$/", $_POST[host])) {
      $valid_hosts = $_POST[host];
    } else {
      $invalid_hosts = $_POST[host];
    }
  } else {
    $no_hosts=true;
  }

  ## TIME ##
  if($_POST[scan_freq]=="now" || !isset($_POST[scan_freq])) 
    $date="now";
  else{
    if($_POST[daily]){
      $time_ar=explode(":", $_POST[daily]);
      $date=$time_ar[1]." ".$time_ar[0]." * * *";
    } 
    if($_POST[weekly]){
      if($_POST[weekly_time])
        $time_ar=explode(":", $_POST[weekly_time]);
      else
        $time_ar[0]=$time_ar[1]=0;
      $date=$time_ar[1]." ".$time_ar[0]." * * ".$_POST[weekly];
    }
    if($_POST[monthly]){
      if($_POST[monthly_time])
        $time_ar=explode(":", $_POST[monthly_time]);
      else
        $time_ar[0]=$time_ar[1]=0;
      $date=$time_ar[1]." ".$time_ar[0]." ".$_POST[monthly]." * *";;
    }
  }

  if(!$date)
    $errors[]="No scan time has been selected<br>";
  if(isset($no_hosts))
    $errors[]="You have not specified any hosts to scan<br>";
  if(isset($invalid_hosts))
    $errors[]="The following host(s) are not written in the correct format: $invalid_hosts";

  if($errors){
    print "<font color=\"red\">There are errors in your schedule:<br><blockquote>";
    foreach($errors as $error)
      print $error;
    print "</blockquote></font>";
  }
  else{
    if($date=="now") {
      PFCMD("schedule now $valid_hosts");
    } else {
      PFCMD("schedule add $valid_hosts date=\"$date\"");
    }
    $my_table->refresh();
  }
}
?>

<div id="history">
<table class="main">
<tr>
  <td>
<form name=schedule action='scan/scan.php' method=POST>
<input type="hidden" name="action" value="add">
  <table>
    <tr>
      <td colspan=8>Add a Scan Schedule</td>
    </tr>
    <tr>
      <td colspan=8><center><font color="red">System scanning from the Web Admin is disabled</font></center></td>
    </tr>
    <tr class=title>
      <td><br><b><u>Host/Range</u></b></td>
    </tr>
    <tr>
      <td></td><td><input type=text size=20 name=host disabled></td> 
    </tr>
    <tr class=title>
      <td><br><b><u>Schedule</u></b></td>
    </tr>
    <tr>
      <td></td>
      <td>
        <table>
	  <tr>
            <td><input type=radio name=scan_freq value=now checked disabled></td>
	    <td colspan=2>Scan Now</td>
          </tr>
	  <tr>
            <td><input type=radio name=scan_freq value=schedule disabled></td>
	    <td colspan=2>Repeating Schedule</td>
          </tr>
          <tr class=title>
            <td></td><td></td><td>Time</td>
          </tr>
          <tr>
  	    <td></td>
	    <td>Daily</td>
	    <td>
              <select name="daily" onclick="document.schedule.scan_freq[1].checked=true" disabled>
                <option value="">---------</option>
<?php print_time_options() ?>
              </select>
            </td>
 	  </tr>    
          <tr class=title>
            <td></td><td></td><td>Day</td><td>Time</td>
          </tr>
          <tr>
  	    <td></td>
	    <td>Weekly</td>
	    <td>
              <select name=weekly onclick="document.schedule.scan_freq[1].checked=true" disabled>
                <option value="">---------</option>   
		<option value=7>Sun.</option>
		<option value=1>Mon.</option>
		<option value=2>Tue.</option>
		<option value=3>Wed.</option>
		<option value=4>Thu.</option>
		<option value=5>Fri.</option>
		<option value=6>Sat.</option>
              </select>
	    </td>
	    <td>
              <select name="weekly_time" onclick="document.schedule.scan_freq[1].checked=true" disabled>
                <option value="">---------</option>
<?php print_time_options() ?>
              </select>
            </td>
 	  </tr>    
          <tr class=title>
            <td></td><td></td><td>Date</td><td>Time</td>
          </tr>
          <tr>
  	    <td></td>
	    <td>Monthly</td>
	    <td>
              <select name=monthly onclick="document.schedule.scan_freq[1].checked=true" disabled>
                <option value="">---------</option>       
<?php
for ($i=1; $i<=28; $i++) {
  echo "                <option value=\"$i\">$i</option>\n";
}
?>
              </select>
	    </td>
 	    <td>
              <select name="monthly_time" onclick="document.schedule.scan_freq[1].checked=true" disabled>
                <option value="">---------</option>
		  <?php print_time_options() ?>
              </select>
            </td>
 	  </tr>    
        </table>
      </td>
    </tr>
    <tr>
      <td colspan=8 align=right><input type=submit value="Add Schedule" disabled></td>
    </tr>
  </table>
</form>
</td>
<td valign=top class=contents width=100%>
  <table width=100%>
    <tr>
      <td>Current Schedules</td>
    </tr>
    <tr>
      <td>
        <? 	  $my_table->tableprint(false); 	?>
      </td>
    </tr>
  </table>
</td></tr>
</table>
</div>
<?
include_once('../footer.php');
?>
