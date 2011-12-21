<?php
/**
 * common.php: The Web Admin interface's main library
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
 * @author      Francois Gaudreault <fgaudreault@inverse.ca>
 * @copyright   2008-2011 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

require_once($_SERVER['DOCUMENT_ROOT'] . "/check_login.php");

# these value to string are duplicated from lib/pf/config.pm
# changes here should be reflected there
$connection_type = array(
  'Wireless-802.11-EAP'   => 'Wireless 802.1X (WPA Enterprise)',
  'Wireless-802.11-NoEAP' => 'Wireless MAC Authentication',
  'Ethernet-EAP'          => 'Wired 802.1x',
  'Ethernet-NoEAP'        => 'Wired MAC Authentication',
  'SNMP-Traps'            => 'Wired SNMP',
  'Inline'                => 'Inline',
  ''                      => 'Unknown'
);

if($sajax){
  require($_SERVER['DOCUMENT_ROOT'] . "/common/sajax/Sajax.php");
}

  class table{
    var $headers;
    var $rows;
    var $page_num;
    var $per_page;
    var $editable;
    var $violationable;
    var $scannable;
    var $create_cmd;
    var $count_cmd;
    var $linkable;
    var $hidden_links;
    var $is_hideable;
    var $filter;
    var $default_filter;
    var $default_sort_header;
    var $default_sort_direction;
    var $is_hidden;
    var $key;
    var $result_count;
    var $sql_sort_and_limit;

    function set_linkable($links){
      foreach($links as $link)
        $this->linkable[$link[0]]=$link[1];
    }

    function set_hideable($links){
     if(!isset($this->is_hidden))
        $this->is_hidden=true;

      $this->is_hideable=true;
      foreach($links as $link){
        $this->hidden_links[$link]=1;
      }
    }

    function set_page_num($page_num){ 
      $this->page_num=$page_num;
    }

    function set_editable($value){ 
      //$this->headers[]="Actions";
      $this->editable=$value;
      if($_GET[action]=="edit")
        $this->is_hidden=false;
    }

    function set_violationable($value){ 
      $this->violationable=$value;
    }

    function set_scannable($value){ 
      $this->headers[]="scan";
      $this->scannable=$value;
    }

    function set_per_page($per_page){ 
      $this->per_page=$per_page;
    }

    function set_result_count($count) {
      $this->result_count=$count;
    }

   function set_default_sort($header,$direction="DESC"){
      $this->default_sort_header=$header;
      $this->default_sort_direction=$direction;
   }

   function set_sql_sort_and_limit($sql) {
      $this->sql_sort_and_limit = $sql;
   }

   function set_default_filter($filter){
      $this->default_filter=$filter;
   }

   function set_count_cmd($count_cmd){
      $this->count_cmd=$count_cmd;
   }

   /**
    * Returns the number of displayed column in the table. 
    */
   function get_displayable_column_count(){
      // adding 1 because of the clone, edit, delete column on the left
      return count($this->headers) + 1;
   }

   function refresh(){

     $new_this = new table($this->create_cmd);
     # if counting rows was done using a special command, we need to carry it over
     if(isset($this->count_cmd) && $this->count_cmd != '') {
       $new_this->set_count_cmd($this->count_cmd);
     }

     # copy over all members of new table to current table
     foreach (get_object_vars($new_this) as $key => $value)
       $this->$key = $value;  

     # re-count number of rows if required
     if(isset($this->count_cmd) && $this->count_cmd != '') {
       $this->count_result();
     }

     $this->set_editable(true);
   }

    function get_key(){
      global $current_top;
      global $current_sub;
    
      if($current_top == 'status' && $current_sub == 'reports'){
        global $_GET;
        $sub = "$current_top-$current_sub-$_GET[type]";   
      } 

      if(!$current_sub){
        $menu = "$current_top-view";
      }
      else{
        $menu = "$current_top-$current_sub";
      }
      
      $header_meta=meta($menu);
      if($header_meta){
        foreach($header_meta as $meta){  
          if(preg_match("/^(.*)\*$/", $meta[0], $matches)){
                $this->key = $matches[1];
          }
        }
      }
    }

    function table($command){
      $this->per_page = 25;
      $this->page_num = 1;
      $content=PFCMD($command);   
      $this->create_cmd=$command;
      $this->headers=explode("|", $content[0]);      
      $this->get_key();
      $this->result_count = -1;
      $this->sql_sort_and_limit = false;

      for($i=1; $i<=count($content); $i++){
        if(isset($content[$i]) && $content[$i]!=""){
          $data=explode("|", $content[$i]);
          for($a=0; $a<count($this->headers); $a++)
            $row[$this->headers[$a]]=$data[$a];         
          $this->rows[]=$row;
        }
      }   
    } // End constructor    

    function tablefilter($filter){
      $this->filter=$filter;
      foreach($this->rows as $row){
        foreach($row as $key => $cell){
          if (stristr($cell, trim($filter)) ||
               ($key == 'dhcp_fingerprint' && $_SESSION['fingerprints'][$cell] && stristr($_SESSION['fingerprints'][$cell], trim($filter))) ||
               ($key == 'vid' && $_SESSION['violation_classes'][$cell] && stristr($_SESSION['violation_classes'][$cell], trim($filter)))
          ) {
            $filtered_array[]=$row;
            break; 
          }
        }
      }
      if(count($filtered_array)==0){
        $this->is_empty=true;
      }
    return $filtered_array;
    }


    function tableprint($with_add){
      global $current_top;
      global $current_sub;
      global $_GET;
      global $no_filter;
      global $extra_goodness;
      $sort = $_GET['sort'];
      $direction = $_GET['direction'];
      $per_page = $_GET['per_page'];
      $filter = $_REQUEST['filter'];
      $action = $_GET['action'];
      $item = $_GET['item'];
      $commit = $_POST['commit'];
      $abs_url =$_REQUEST['abs_url']; 
      $time_filter = $_REQUEST['time_filter'];
      $starttime = $_REQUEST['starttime'];
      $stoptime = $_REQUEST['stoptime'];

      if(isset($this->hidden_links)){
        if(array_key_exists($sort, $this->hidden_links)){
          $this->is_hidden=false;
        }
      }

      if (isset($this->default_filter) || (isset($filter) && $filter != '')) {
        if (!isset($filter) || $filter == '') {
          $filter = $this->default_filter;
        }
      }

      if (isset($filter) && $filter != "" && substr($filter, 0, 9) != 'category=' && substr($filter, 0, 4) != 'pid=' )
        $this->rows=$this->tablefilter($filter); 


      print $extra_goodness;

      print "<table class='data_table' align='center' width='95%'>\n";
      print "<thead>\n";

      print "<tr>\n";
      print "<td colspan=\"".$this->get_displayable_column_count()."\" id=\"search\">\n";
      if($this->is_hideable){
        if($this->is_hidden){
          print "<span id='show_icon' style='display:visible;'><a href='javascript:hideCells(\"\");'><img src='../images/show.gif' alt='Show Info'><br><font size=1>Show Info</font></a></span>";
          print "<span id='hide_icon' style='display:none;'><a href='javascript:hideCells(\"none\");'><img src='../images/hide.gif' alt='Hide Info'><br><font size=1>Hide Info</font></a></span>";
        } else {
          print "<span id='show_icon' style='display:none;'><a href='javascript:hideCells(\"\");'><img src='../images/show.gif' alt='Show Info'><br><font size=1>Show Info</font></a></span>";
          print "<span id='hide_icon' style='display:visible;'><a href='javascript:hideCells(\"none\");'><img src='../images/hide.gif' alt='Hide Info'><br><font size=1>Hide Info</font></a></span>";
        }
      }

      ## FILTER ANNEX ##
      if(!$with_add && !$no_filter && !($current_top=="scan" && $current_sub=="scan")){
        if($current_top == 'status' && $current_sub == 'reports'){
          global $type;
          $t = "<input type='hidden' name='type' value='".trim($type)."'>";
        }
        if (isset($this->default_filter) || (isset($filter) && $filter != '')) {
          if (!isset($filter) || $filter == '') {
            $last_filter = $this->default_filter;
          } else {
            $last_filter=$filter;
          }
        } else {
          $last_filter="             -Filter-";
        }

        print "<span id=\"searchform\">\n";
        print "<form name='filter' action='/$current_top/$current_sub.php' method='GET'>\n";
        print $t;
        print "<table>\n";
        print "<tr>\n";
        print "<td></td><td align=center><a href='javascript:if (document.filter.filter.value != \"             -Filter-\") { document.filter.submit();}'><img src='images/search.png' alt='Search'></a></td>\n";
        print "<td><input name=\"filter\" onfocus=\"this.value=''\" type=\"text\" value=\"$last_filter\"></td>\n";
        print "<td width=\"15\" align=\"center\"><a href=\"$current_top/$current_sub.php?per_page=$per_page\">x</a></td>\n";
        print "</tr>\n";
        if(!isset($time_filter)) print "    <tr><td></td><td colspan=2></td></tr>\n  </table>\n";

          ## TIME FILTER ##
          if(isset($time_filter)){
            if(!$starttime)
              $starttime='-Start Date-';
            if(!$stoptime)
              $stoptime='-Stop Date-';
            print "</form>\n";
            print "  <FORM name='timeform' action='/$current_top/$current_sub.php?filter=$filter'>";
            print "<table>\n";
            print "<tr>\n";
            print "  <td></td>\n";
            print "  <td><input name='starttime' id='starttime' value='$starttime'></td>\n";
            show_calendar('starttime');
            print "  <td></td>\n";  
            print "</tr>\n";
            print "<tr>\n";
            print "  <td></td>\n";
            print "  <td><input name='stoptime' id='stoptime' value='$stoptime'></td>\n";
            show_calendar('stoptime');
            print "  <td></td>\n";
            print "</tr>\n";
            print "<tr height='30'>";
            print "  <td valign='bottom'></td>";
            print "  <td align='right'>";
            print "  <input type='submit' value='Submit'>";
            print "  </td>";
            print "</tr>";
            print "</table>\n";

          }
        print "</form>\n";
        print "</span>\n";

      }
      print "</td></tr>";

      print "  <tr class='header'>\n";
      if($this->is_empty()){
        print "<td><div id='message_box'>No results</div></td></tr></table>";
        return; 
      }

      if($this->editable) {
        print "    <td class='action'>&nbsp;</td>\n"; 
      }
      if($this->scannable) {
        print "    <td&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;></td>\n"; 
      }

      if(!$current_sub){
        $sub = "$current_top-view";
      }
      else{
        $sub = "$current_top-$current_sub";
      }

      if($current_top == 'status' && $current_sub == 'reports'){
        $sub = "$current_top-$current_sub-$_REQUEST[type]";
      }                   

      $menu = set_default($sub, "$current_top-view");

      $header_meta=meta($menu);

      foreach($this->headers as $header){ 
        $pretty_header="";

        if($header_meta){
          foreach($header_meta as $meta){
            if (($meta[0] == $header) || ($meta[0] == ($header . "*"))) {
              $pretty_header=$meta[1];
            }
          }
        }

        if(!$pretty_header){
          $pretty_header=ucfirst($header);
        }

        if (isset($this->default_sort_direction) || (isset($direction) && $direction != '')) { 
          if (!isset($sort) || $sort == '') {
            $direction = $this->default_sort_direction;
          }
        }

        if($direction=="DESC"){
          $on_direction="ASC";
          $off_direction="DESC";
        } else{
          $on_direction="DESC";
          $off_direction="ASC";
       } 

       global $get_args;
       $xtra_args = build_args($get_args);

       isset($this->hidden_links[$header]) && $this->is_hidden == true ? $hide_tag = "id='id".++$q."' style='display:none;'" : $hide_tag = "";

       if($sort==$header)
         print "    <td class='header' $hide_tag><div class='header'><a class='active' href='$current_top/$current_sub.php?filter=" . urlencode($filter) . "&amp;sort=$header&amp;direction=$on_direction&amp;per_page=$per_page&$xtra_args'>$pretty_header</a></div></td>\n";
       else
         print "    <td class='header' $hide_tag><div class='header'><a href='$current_top/$current_sub.php?filter=" . urlencode($filter) . "&amp;sort=$header&amp;direction=$off_direction&amp;per_page=$per_page&$xtra_args'>$pretty_header</a></div></td>\n";
      }

      print "  </tr>\n";
      print "</thead>\n";
       
    if(!$this->sql_sort_and_limit) {
      if (isset($this->default_sort_header) || (isset($sort) && $sort != '')) {
        if (!isset($sort) || $sort == '') {
          $sort = $this->default_sort_header;
        }
        foreach($this->rows as $val){
          $sortarray[]=$val[$sort];
        }
        if($direction=="ASC")
          array_multisort($sortarray, SORT_ASC, $this->rows);
        if($direction=="DESC")
          array_multisort($sortarray, SORT_DESC, $this->rows);
      }
    }
 
  ## SET PAGE DEFAULTS ##
  if(!$this->per_page)
    $this->per_page=25;

  if(!$this->page_num)
    $this->page_num=1;

  if(!$this->sql_sort_and_limit) {
      $start=($this->page_num - 1)*$this->per_page;
  } else {
      $start=0;
  }
  $stop=$start+$this->per_page-1;

  print "<tbody>\n";
  for($i=$start; $i<=$stop; $i++){
    if($i>=count($this->rows))
      break;

  ## ROW HIGHLIGHTING ##
  print "<tr class=\"data\">\n";

  ## EDITING A ROW ##
  if($action=="edit" && !$commit && $item==$i){
    print "<form action='/$current_top/$current_sub.php?filter=$filter&amp;sort=$sort&amp;direction=$direction&amp;page_num=$this->page_num&amp;per_page=$this->per_page&amp;action=$action&amp;item=$item' method='post'>\n";
    $a=-1;

    foreach($this->rows[$i] as $cell){
      $key=$this->headers[++$a];

       ## FOR AUTOSIZING ##
       $default_min=5;
       $default_max=15;
       $size_array=array();
       foreach($this->rows as $row)
         $size_array[]=strlen($row[$key]);
       $size=max(max($size_array), $default_min);
       $size=min($size, $default_max);

       if(in_array($key, $this->headers))
         print "<td><input size='$size' type='text' value='$cell' name='val$a'></td>\n";
       else
         print "<td>$cell</td>"; 
    }

    if($this->rows[$item+1])
      $value=implode("\t", $this->rows[$item+1]);

    print "<input type='hidden' name='original' value='". htmlentities($value, ENT_QUOTES) ."'>";
    print "<input type='hidden' name='commit' value='true'>";
    print "<td width='50'><div id='submit'><input type='submit' value='Submit'></div></td>\n";
    print "</form>";
  }

  else{
    $a=-1;
    $key_item='';
           
    foreach($this->rows[$i] as $cell){
      $key=$this->headers[++$a];

      if($key == $this->key){
        $key_item=$cell;
      }
    }

           if(isset($this->editable)){
             print "  <td class=\"action\">\n";
             if (($current_top == 'configuration') && ($current_sub=='interfaces')) {
               print "  <a href=\"javascript:popUp('/$current_top/" . $current_sub . "_edit.php?item=" . $this->rows[$i]['interface'] . "',500,500)\" title='Edit this record'><img src='/images/famfamfam_silk_icons/page_edit.png' alt=\"[ Edit ]\"></a>\n";
               print "  <a href=\"javascript:popUp('/$current_top/" . $current_sub . "_add.php?item=" . $this->rows[$i]['interface'] . "',500,500)\" title='Clone this record'><img src='/images/famfamfam_silk_icons/page_add.png' alt=\"[ Add ]\"></a>\n";
               print "<form action='/$current_top/$current_sub.php?filter=$filter&amp;sort=$sort&amp;direction=$direction&amp;page_num=$this->page_num&amp;per_page=$this->per_page' method='post'>";
               print "  <input type='hidden' name='action' value='delete'>\n";
               print "  <input type='hidden' name='commit' value='true'>\n";
               print "  <input type='hidden' name='original' value='".implode("\t", $this->rows[$i])."'>\n";
               print "  <input class=\"button\" type='image' src='/images/famfamfam_silk_icons/page_delete.png' align=bottom title='Delete this record' onClick=\"return confirm('Are you sure you want to delete the interface " . $this->rows[$i]['interface'] . " ?');\">\n";
               print "  </form>";
             } elseif (($current_top == 'configuration') && ($current_sub=='networks')) {
               print "  <a href=\"javascript:popUp('/$current_top/" . $current_sub . "_edit.php?item=" . $this->rows[$i]['network'] . "',500,500)\" title='Edit this record'><img src='/images/famfamfam_silk_icons/page_edit.png' alt=\"[ Edit ]\"></a>\n";
               print "  <a href=\"javascript:popUp('/$current_top/" . $current_sub . "_add.php?item=" . $this->rows[$i]['network'] . "',500,500)\" title='Clone this record'><img src='/images/famfamfam_silk_icons/page_add.png' alt=\"[ Add ]\"></a>\n";
               print "<form action='/$current_top/$current_sub.php?filter=$filter&amp;sort=$sort&amp;direction=$direction&amp;page_num=$this->page_num&amp;per_page=$this->per_page' method='post'>";
               print "  <input type='hidden' name='action' value='delete'>\n";
               print "  <input type='hidden' name='commit' value='true'>\n";
               print "  <input type='hidden' name='original' value='".implode("\t", $this->rows[$i])."'>\n";
               print "  <input class=\"button\" type='image' src='/images/famfamfam_silk_icons/page_delete.png' align=bottom title='Delete this record' onClick=\"return confirm('Are you sure you want to delete the network " . $this->rows[$i]['network'] . " ?');\">\n";
               print "  </form>";
             } elseif (($current_top == 'configuration') && ($current_sub=='switches')) {
               print "  <a href=\"javascript:popUp('/$current_top/" . $current_sub . "_edit.php?item=" . $this->rows[$i]['ip'] . "',500,500)\" title='Edit this record'><img src='/images/famfamfam_silk_icons/page_edit.png' alt=\"[ Edit ]\"></a>\n";
               print "  <a href=\"javascript:popUp('/$current_top/" . $current_sub . "_add.php?item=" . $this->rows[$i]['ip'] . "',500,500)\" title='Clone this record'><img src='/images/famfamfam_silk_icons/page_add.png' alt=\"[ Add ]\"></a>\n";
               if (($this->rows[$i]['ip'] != '127.0.0.1') && ($this->rows[$i]['ip'] != 'default')) {
                 print "<form action='/$current_top/$current_sub.php?filter=$filter&amp;sort=$sort&amp;direction=$direction&amp;page_num=$this->page_num&amp;per_page=$this->per_page' method='post'>";
                 print "  <input type='hidden' name='action' value='delete'>\n";
                 print "  <input type='hidden' name='commit' value='true'>\n";
                 print "  <input type='hidden' name='original' value='".implode("\t", $this->rows[$i])."'>\n";
                 print "  <input class=\"button\" type='image' src='/images/famfamfam_silk_icons/page_delete.png' align=bottom title='Delete this record' onClick=\"return confirm('Are you sure you want to delete the switch " . $this->rows[$i]['ip'] . " ?');\">\n";
                 print "  </form>";
               }
             } elseif (($current_top == 'node') && ($current_sub=='categories')) {
               // NODE CATEGORIES 
           print "  <a href=\"javascript:popUp('/$current_top/" . $current_sub . "_edit.php?item=" . $this->rows[$i]['category_id'] . "',500,500)\" title='Edit this record'><img src='/images/famfamfam_silk_icons/page_edit.png' alt=\"[ Edit ]\"></a>\n";
           print "  <a href=\"javascript:popUp('/$current_top/" . $current_sub . "_add.php?item=" . $this->rows[$i]['category_id'] . "',500,500)\" title='Clone this record'><img src='/images/famfamfam_silk_icons/page_add.png' alt=\"[ Add ]\"></a>\n";
               if ($this->rows[$i]['category_id'] != '1') {
                 print "<form action='/$current_top/$current_sub.php?filter=$filter&amp;sort=$sort&amp;direction=$direction&amp;page_num=$this->page_num&amp;per_page=$this->per_page' method='post'>";
                 print "  <input type='hidden' name='action' value='delete'>\n";
                 print "  <input type='hidden' name='commit' value='true'>\n";
                 print "  <input type='hidden' name='original' value='".implode("\t", $this->rows[$i])."'>\n";
                 print "  <input class=\"button\" type='image' src='/images/famfamfam_silk_icons/page_delete.png' align=bottom title='Delete this record' onClick=\"return confirm('Are you sure you want to delete the category " . $this->rows[$i]['name'] . "?');\">\n";
                 print "  </form>";
               }
             } elseif (($current_top == 'configuration') && ($current_sub=='floatingnetworkdevice')) {
               // FLOATING DEVICES
               print "  <a href=\"javascript:popUp('/$current_top/" . $current_sub . "_add.php?item=" . $this->rows[$i]['floatingnetworkdevice'] . "',500,500)\" title='Clone this record'><img src='/images/famfamfam_silk_icons/page_add.png' alt=\"[ Add ]\"></a>\n";
               if ($this->rows[$i]['floatingnetworkdevice'] != 'stub') {
                 print "  <a href=\"javascript:popUp('/$current_top/" . $current_sub . "_edit.php?item=" . $this->rows[$i]['floatingnetworkdevice'] . "',500,500)\" title='Edit this record'><img src='/images/famfamfam_silk_icons/page_edit.png' alt=\"[ Edit ]\"></a>\n";
                 print "<form action='/$current_top/$current_sub.php?filter=$filter&amp;sort=$sort&amp;direction=$direction&amp;page_num=$this->page_num&amp;per_page=$this->per_page' method='post'>";
                 print "  <input type='hidden' name='action' value='delete'>\n";
                 print "  <input type='hidden' name='commit' value='true'>\n";
                 print "  <input type='hidden' name='original' value='".implode("\t", $this->rows[$i])."'>\n";
                 print "  <input class=\"button\" type='image' src='/images/famfamfam_silk_icons/page_delete.png' align=bottom title='Delete this record' onClick=\"return confirm('Are you sure you want to delete the floating network device " . $this->rows[$i]['floatingnetworkdevice'] . "?');\">\n";
                 print "  </form>";
               }
             } elseif (($current_top == 'configuration') && ($current_sub=='violation')) {
               print "  <a href=\"". $this->rows[$i]['url'] . "\" title='Preview remediation page' target='_blank'><img src='/images/famfamfam_silk_icons/page_world.png' alt=\"[ Preview ]\"></a>\n";
               print "  <a href=\"javascript:popUp('/$current_top/" . $current_sub . "_edit.php?item=" . $this->rows[$i]['vid'] . "',600,500)\" title='Edit this record'><img src='/images/famfamfam_silk_icons/page_edit.png' alt=\"[ Edit ]\"></a>\n";
               print "  <a href=\"javascript:popUp('/$current_top/" . $current_sub . "_add.php?item=" . $this->rows[$i]['vid'] . "',600,500)\" title='Clone this record'><img src='/images/famfamfam_silk_icons/page_add.png' alt=\"[ Add ]\"></a>\n";
               if (!is_protected_vid($this->rows[$i]['vid'])) {
                 print "<form action='/$current_top/$current_sub.php?filter=$filter&amp;sort=$sort&amp;direction=$direction&amp;page_num=$this->page_num&amp;per_page=$this->per_page' method='post'>";
                 print "  <input type='hidden' name='action' value='delete'>\n";
                 print "  <input type='hidden' name='commit' value='true'>\n";
                 print "  <input type='hidden' name='original' value='".implode("\t", $this->rows[$i])."'>\n";
                 print "  <input class=\"button\" type='image' src='/images/famfamfam_silk_icons/page_delete.png' align=bottom title='Delete this record' onClick=\"return confirm('Are you sure you want to delete the violation " . $this->rows[$i]['vid'] . " ?');\">\n";
                 print "  </form>";
               }
             } else {
               print "  <a href=\"javascript:popUp('/$current_top/edit.php?item=$key_item',500,450)\" title='Edit this record'><img src='/images/edit.png' alt=\"[ Edit ]\"></a>\n";
               if($this->violationable){
                 print "  <a href='violation/add.php?MAC=".$this->rows[$i]['mac']."'><img src='/images/trap.png' border='0' title='Add Violation' alt='[ Add Violation ]'></a>\n";
               }
               print "<form action='/$current_top/$current_sub.php?filter=$filter&amp;sort=$sort&amp;direction=$direction&amp;page_num=$this->page_num&amp;per_page=$this->per_page&amp;action=$action&amp;item=$item' method='post'>";
               print "  <input type='hidden' name='action' value='delete'>\n";
               print "  <input type='hidden' name='commit' value='true'>\n";
               print "  <input type='hidden' name='original' value='".htmlentities(implode("\t", $this->rows[$i]), ENT_QUOTES)."'>\n";
               print "  <input class=\"button\" type='image' src='/images/delete.png' align=bottom title='Delete this record' onClick=\"return confirm('Are you sure you want to delete ".htmlentities($this->rows[$i][$this->key], ENT_QUOTES)."?');\">\n";
               print "  </form>";
             }
             print "</td>\n";
           }
       
           # FIXME: this is broken, nessus/scanner.php doesn't exist
           if($this->scannable){
             print "<td width='45' align='right'>\n";
             $host=$this->rows[$i]['mac'];
             print "  <A HREF=\"javascript:popUp('nessus/scanner.php?host=$host')\">";
             print "  <input class=\"button\" type='image' align='center' src='/images/delete.png' onClick=\"return confirm('Scan this host?');\"></a>\n";
             print "</td>\n";
           }

           $a=-1;
           foreach($this->rows[$i] as $cell){
             # XSS prevention
             $cell = htmlentities($cell, ENT_QUOTES);

             $key=$this->headers[++$a];

             if($key == $this->key){
               $key_item=$cell;
             }
             isset($this->hidden_links[$key]) && $this->is_hidden == true ? $hide_tag = "id='id".++$q."' style='display:none;'" : $hide_tag = "";

             if(isset($this->linkable[$key])){
               strstr($this->linkable[$key], '?') ? $break = '&' : $break = '?';

               if($key == 'dhcp_fingerprint' && $_SESSION['fingerprints']["$cell"]){
                 print "    <td $hide_tag><a href='".$this->linkable[$key].$break."view_item=$cell'>".$_SESSION['fingerprints']["$cell"]."</a></td>\n";
               }
               else if($key == 'vid' && $_SESSION['violation_classes']["$cell"]){
                 print "    <td $hide_tag><a href='".$this->linkable[$key].$break."view_item=$cell'>".$_SESSION['violation_classes']["$cell"]." </a></td>\n";
               } 
               else if (($key == 'url') && (array_key_exists('vid', $this->rows[$i]))) {
                 print "    <td $hide_tag><a href='".$this->linkable[$key].$break."vid=" . $this->rows[$i]['vid'] . "'>" . ((strlen($cell) > 30) ? (substr($cell, 0, 30) . ' ...') : $cell) . "</a></td>\n";

               # HACK to support linking categories with space in their names
               } else if ($current_top == 'node' && $current_sub == 'categories') {
                 print "    <td $hide_tag><a href='".$this->linkable[$key].$break."view_item=\"$cell\"'>" . ((strlen($cell) > 30) ? (substr($cell, 0, 30) . ' ...') : $cell) . "</a></td>\n";

               }
               else{
                 print "    <td $hide_tag><a href='".$this->linkable[$key].$break."view_item=$cell'>" . ((strlen($cell) > 30) ? (substr($cell, 0, 30) . ' ...') : $cell) . "</a></td>\n";
               }
             }
             else{  
               print "    <td $hide_tag>" . ((strlen($cell) > 30) ? (substr($cell, 0, 30) . ' ...') : $cell) . "</td>\n";
             }
           }
                  
        }
        print "  </tr>\n"; 
      }

      print "</tbody>\n";
      print "</table>\n";
    
      if(!$with_add){
        if ($this->result_count == -1) {
          $this->result_count = count($this->rows);
        }
        $this->result_count == 1 ? $word='result' : $word='results';
        print "<div id='result_count'>(".$this->result_count." $word)</div>\n";
      } 

   }  // End tableprint


    function print_pager(){
      global $current_top;
      global $current_sub;
      global $get_args;
      global $_GET;
      $sort = $_GET['sort'];
      $direction = $_GET['direction'];
      $filter = $_REQUEST['filter'];

      $xtra_args = build_args($get_args);

      if ($this->result_count == -1) {
        $this->result_count = count($this->rows);
      }
      if($this->per_page)
        $num_pages=ceil($this->result_count/$this->per_page);
      $next_page=$this->page_num+1;
      $last_page=$this->page_num-1;

      if($num_pages>1) { // don't print the pager if there is only one page
      
        for($i=1; $i<=$num_pages; $i++){
          if($i!=1) {
            if (($this->page_num - $i < 5) && ($this->page_num - $i >= -5)) {
              print " - ";
            }
          } else {
            if($last_page!=0) 
              if ($this->page_num -5 > 0) {
                print "<a class='inactive' href='$current_top/$current_sub.php?sort=$sort&amp;direction=$direction&amp;page_num=1&amp;per_page=$this->per_page&amp;filter=$filter&$xtra_args'><< </a>";
              }
              print "<a class='inactive' href='$current_top/$current_sub.php?sort=$sort&amp;direction=$direction&amp;page_num=$last_page&amp;per_page=$this->per_page&amp;filter=$filter&$xtra_args'>< </a>";
          } 
          if($this->page_num==$i) 
            print "<a class='active' href='$current_top/$current_sub.php?sort=$sort&amp;direction=$direction&amp;page_num=$i&amp;per_page=$this->per_page&amp;filter=$filter&$xtra_args'>$i</a>";
          else
            if (abs($this->page_num - $i) <= 5) {
              print "<a class='inactive' href='$current_top/$current_sub.php?sort=$sort&amp;direction=$direction&amp;page_num=$i&amp;per_page=$this->per_page&amp;filter=$filter&$xtra_args'>$i</a> ";
            }
        }
        if($next_page<=$num_pages) {
          print "<a class='inactive' href='$current_top/$current_sub.php?sort=$sort&amp;direction=$direction&amp;page_num=$next_page&amp;per_page=$this->per_page&amp;filter=$filter&$xtra_args'> ></a>";
          if ($num_pages - $this->page_num > 5) {
            print "<a class='inactive' href='$current_top/$current_sub.php?sort=$sort&amp;direction=$direction&amp;page_num=$num_pages&amp;per_page=$this->per_page&amp;filter=$filter&$xtra_args'> >></a>";
          }
        }
        print "<br>";
      }
      $per_pages=array('25', '25', '50', '100', '500', '1000');
      
      if($this->per_page!=1001){   # Because of report/history bug
        for($a=1; $a<=count($per_pages); $a++){
          if($this->result_count>$per_pages[$a-1]){
            if($this->per_page==$per_pages[$a])
              print "<a class='active' href='$current_top/$current_sub.php?sort=$sort&amp;direction=$direction&amp;per_page=$per_pages[$a]&amp;filter=" . urlencode($filter) . "&$xtra_args'>$per_pages[$a] </a>";
            else   
              print "<a href='$current_top/$current_sub.php?sort=$sort&amp;direction=$direction&amp;per_page=$per_pages[$a]&amp;filter=" . urlencode($filter) . "&$xtra_args'>$per_pages[$a] </a>";
          }
        }
      }
    } // END print_pager


    function is_empty(){
      if(count($this->rows)==0)
        return true;
      else return false;
    }  // End is_empty


    /*
     * Asks pfcmd to give us a count based on table's count_cmd
     * I'm sorry it's a bit ugly but it's the best I could do in the context
     */
    function count_result() {
      $result_count = PFCMD($this->count_cmd);
      if ($result_count[1] >= 0) {
        $this->set_result_count($result_count[1]);
      }
    }

  }  // End Class table


### FUNCTIONS ####

function PrintSubNav($menu){
    global $current_top;
    global $current_sub;

    $sub_navs=meta($current_top);    
    $dropdowns = array('graphs', 'reports');

    print "<!-- Begin SubNav -->\n";
    print "      <div class='subnav'>\n";
    print "        <ul id='navlist'>\n";

    foreach($sub_navs as $sub_nav) {
      if(in_array($sub_nav[0], $dropdowns)) {
        $current_sub == $sub_nav[0] ? $id="current" : $id = '';

        print "            <li><a href='$current_top/$sub_nav[0].php?menu=true' class='$id'>$sub_nav[1]</a>\n";
        print "              <ul id='subnavlist' style='z-index:2;'>\n";

        $meta_array=meta("status-$sub_nav[0]"); 
        foreach($meta_array as $link){
          print "                <li width=100%><a href='$current_top/$sub_nav[0].php?type=$link[0]'>$link[1]</a></li>\n";
        }

        print "              </ul>\n";
        print "            </li>\n";
      }  
      else if($current_sub==$sub_nav[0]) {
        print "         <li class='active'><a href='$current_top/$sub_nav[0].php' class='current'>$sub_nav[1]</a></li>\n";

      # TODO This should be refactored at some point
      } else if( $current_top == "person" && $sub_nav[0] == "guests" ) {
        print "         <li><a href='/guests/manage' target='_blank'>$sub_nav[1]</a></li>\n";

      # TODO I know, I know this is hackish but how else am I supposed to do this in less than a couple of hours?
      } else if( $current_top == "configuration" && $sub_nav[0] == "soh" ) {
        print "         <li><a href='/soh' target='_blank'>$sub_nav[1]</a></li>\n";

      } else {
        print "          <li><a href='$current_top/$sub_nav[0].php'>$sub_nav[1]</a></li>\n";
      }
    }

    print "         </ul>\n";
    print "       </div>\n";
    print "       <!-- End SubNav -->\n\n";
  }


  function PrintTopNav(){
    global $current_top;

    $root_menus=meta('root'); 

    print "<!-- Begin TopNav -->\n";
    print "      <div class='topnav'>\n";
    print "       <span class='logout'>\n";
    print "         <a href='login.php?logout=true'><img border='0' src='images/dude2.gif' alt=''> ".ucfirst($_SESSION['user'])." Logout</a>\n";
    print "       </span>\n";
    print "        <ul>\n";
    foreach($root_menus as $menu) {
      if($current_top==$menu[0])
        print "          <li class='active'><a href='$menu[0]/' class='current'>$menu[1]</a></li>\n";
      else
        print "          <li><a href='$menu[0]/'>$menu[1]</a></li>\n";
    }
    print "        </ul>\n";
    print "      </div>\n";
    print "      <!-- End TopNav -->\n\n";
  } // END PrintTopNav

  function CSVify($text, $type = 'application/text', $filename) {
    header("Content-type: ".$type);
    header("Content-Disposition: attachment; filename=".$filename);
    print $text;
    exit;
  } // end CSVify

  function PrintAdd($heading_info, $direction){
    global $current_top;
    global $current_sub;
    global $_REQUEST;

    foreach($heading_info as $heading){
      $headings[]=$heading[0];
      if (($current_top == 'node') && ($current_sub == 'add') && ($heading[0] == 'Status') ) {
        if (preg_match("/input type='text' name='(val\d+)'/", $heading[1], $regmatches)) {
          $value_string = "<select name='" . $regmatches[1] . "'>";
          # TODO: if printSelect would return a string instead of print directly this would be less ugly
          $node_statuses = get_node_status_for_dropdown();
          foreach ($node_statuses as $status_id => $status_name) {
              $value_string .= "<option value='$status_id'>$status_name</option>";
          }
          $value_string .= "</select>";
          $values[] = $value_string;
        } else {
          $values[]=$heading[1];
        }

      } elseif (($current_top == 'node') && ($current_sub == 'add') && ($heading[0] == 'Category') ) {

        if (preg_match("/input type='text' name='(val\d+)'/", $heading[1], $regmatches)) {
          # TODO: if printSelect would return a string instead of print directly this would be less ugly
          $value_string = "<select name='" . $regmatches[1] . "'>";
          $nodecategories = get_nodecategories_for_dropdown();
          foreach ($nodecategories as $cat_id => $cat_name) {
              $value_string .= "<option value='$cat_id'>$cat_name</option>";
          }
          $value_string .= "</select>";
          $values[] = $value_string;
        } else {
          $values[]=$heading[1];
        }

      } else {
        $values[]=$heading[1];
      }
    }
    print "<div id='add'>\n";
    print "<form action='/$current_top/$current_sub.php' method='POST'>\n";
    print "<input type='hidden' name='count' value='".count($headings)."'>\n";
    print "<input type='hidden' name='action' value='add'>\n";
    print "<input type='hidden' name='commit' value='true'>\n";
    print "<table class='add'>\n";

    switch($current_top){
      case "node";
      $img = 'node.png';
      break;

      case "person";
      $img = 'person.png';
      break;

      case "violation";
      $img = 'violation.png';
      break;

      default:
      $img = 'famfamfam_silk_icons/page_add.png';
      break;
    }

    if($direction=="vert"){
      print "<tr><td rowspan=20 valign=top><img src='images/$img' alt=\"\"></td></tr>";

      if($_REQUEST['action'] == 'add'){
        $add_info = PFCMD("$current_top view $_REQUEST[val0]");
        if($add_info[1]){ 
          print "<tr><td colspan=2><b>Added Record</b></td></tr>";
          $parts = explode('|', $add_info[1]);
          //for($i=0; $i<count($parts); $i++){
          for($i=0; $i<1; $i++){
            print "<tr><td>$headings[$i]</td><td>$parts[$i]</td></tr>";
          }        
        }
        else{
          print "<tr><td><b><font color=red>Unable to add record $_REQUEST[val0]</b></font></td></tr>";
        }
        print "<tr height=8px><td style='border-bottom:1px solid black;' colspan=4></tr></tr>";
      }

      for($i=0; $i<count($headings); $i++){
        print "<tr>\n";
        print "  <td>$headings[$i]</td>\n";
        print "  <td>$values[$i]</td>\n";
        print "</tr>\n";
      }
      print "<tr>\n";
      print "  <td></td>\n";
      print "  <td align='right'><input class='button' type='submit' value='Add'></td>\n";
      print "</tr>\n";

      print "</table>\n";
    }

    if($direction=="horiz"){
      print "<tr><td rowspan=20 valign=top><img src='images/$img'></td></tr>";

      print "  <tr>\n";

      for($i=0; $i<count($headings); $i++){
        print "<td>$values[$i]</td>\n";
      }
      print "  <td><input class='button' type='submit' value='Add'></td></tr>\n";
      print "</table>\n";
    }
   
    print "</form>\n"; 
    print "</div>\n";
  } // end PrintAdd

  function PFCMD($command){
    global $logger;
    global $debug_log;

    $PFCMD=dirname(dirname($_SERVER['DOCUMENT_ROOT'])) . '/bin/pfcmd';
    exec("ARGS=".escapeshellarg($command)." $PFCMD 2>&1", $output, $total);

    $logger->debug("I ran command: " . escapeshellarg("ARGS=$command"). " $PFCMD\nReturned:\n" . print_r($output,true));
    if($_SESSION['ui_prefs']['ui_debug'] == 'true'){
      $debug_log .= "I ran command: " . escapeshellarg("ARGS=$command"). " $PFCMD\nReturned:\n<pre>" . print_r($output,true) . "</pre>\n<br>";
    }

   
    #$ENV['ARGS']=$command; 
    #exec("$PFCMD 2>&1", $output, $total);

    if(stristr($output[0], 'Usage: pfcmd')){
      return false;
    }

    # HACK: when the output of pfcmd has a "line 999" in it, we assume it's an error and we display it
    foreach($output as $line){
      if(preg_match("/line\s+\d+/", $line)){
        $errors[]=$line;
      }
    }

    if($errors){
      global $_error;
      $_error = "<b>Error: Problems executing 'PFCMD $command'</b><br><pre>". implode('<br>', $errors)."</pre>";
      return false;
    }

    return $output;
  }

  function meta($menu){
    return $_SESSION['menus']["$menu"];
  } //end meta

  function get_headings($current_top){
    $i=-1;
 
    $meta_array=meta("$current_top-add");
    foreach($meta_array as $data){

      if(preg_match("/^\-/", $data[0]))
        continue;
  
      $i++;
      
      ## DESCRIPTION ##
      if(preg_match("/^\*/", $data[0]))
        $heading="*".$data[1];
      else
        $heading=$data[1];
 
      ## FOR PULLDOWNS ##
      if(preg_match("/\(.*\)/", $data[0])){
         $options=preg_split("/\(|\)|,/", $data[0]);
         $options=array_slice($options, 1, count($options)-2);
   
         $menu="<select name='val$i'>\n";
         foreach($options as $option)
           $menu.="  <option value='$option'>$option\n";
         $menu.="</select>"; 
      }

      else
        $menu="<input type='text' name='val$i'>";  

    $return_array[]=array($heading, $menu);   
    }

  return $return_array;
  } // end get_headings

  function testprint($var){
    print "<div style='border:1px dashed #bbbbbb;background:#f7f7f7;margin:10px;padding:10px;'><pre>";
    print_r($var);
    print "</pre></div>";
  }

  function helper_menu($current_top, $current_sub, $current, $draw_menu, $additional){
    $o = array();
    if($draw_menu){
      $additional = "<br>$additional";
      $meta_array=meta("$current_top-$current_sub");
      if($meta_array){
        foreach($meta_array as $link){
          $link[0] == $current ? $links[]="<a href='$current_top/$current_sub.php?menu=true&type=$link[0]'><u>$link[1]</u></a>" : $links[]="<a href='$current_top/$current_sub.php?menu=true&type=$link[0]'>$link[1]</a>"; 
        }
       $o[] =  implode(" | ", $links);
      }
    }
    if($draw_menu || $additional)
      return "<div id='message_box'>".implode("\n", $o)."$additional</div>";
  } // end helper_menu

  function set_default(){
    foreach(func_get_args() as $arg){
      if($arg){ return $arg; }
    }
    return false;
  }

  function pretty_header($menu, $header){
    $pretty_header = ucfirst($header);
    foreach($_SESSION[menus][$menu] as $submenu){        
      if(preg_match("/^$header\*?$/", $submenu[0])){ 
        return $pretty_key = $submenu[1]; 
      } 
    }
    return $header;
  }

  function save_prefs_to_file(){
    if($_SESSION['user'] && $_SESSION['ui_prefs']){
      $filename = dirname(dirname($_SERVER['DOCUMENT_ROOT'])) . "/conf/users/" . $_SESSION['user'];
      if (!$handle = fopen($filename, 'w+')) {
         echo "Cannot open file ($filename)";
         exit;
      }

      if (fwrite($handle, serialize($_SESSION['ui_prefs'])) === FALSE) {
        echo "Cannot write to file ($filename)";
        exit;
      }
      fclose($handle);
    }
  }

  function save_global_prefs_to_file(){
    if($_SESSION['ui_global_prefs']){
      $filename = dirname(dirname($_SERVER['DOCUMENT_ROOT'])) . "/conf/ui-global.conf";
      if (!$handle = fopen($filename, 'w+')) {
         echo "Cannot open file ($filename)";
         exit;
      }

      if (fwrite($handle, serialize($_SESSION['ui_global_prefs'])) === FALSE) {
        echo "Cannot write to file ($filename)";
        exit;
      }
      fclose($handle);
    }
  }

  function build_args($args){
    if(!$args){
      return false;
    }
    foreach($args as $key => $val){
      $get_str.="$key=$val&";
    }
    return preg_replace("/&$/", '', $get_str);
  }

  function get_global_conf(){
    $global_conf = dirname(dirname($_SERVER['DOCUMENT_ROOT'])) . '/conf/ui-global.conf';
    if(file_exists($global_conf)){
      $_SESSION['ui_global_prefs']=unserialize(file_get_contents($global_conf));
    }
    else{
      $defaults = array();
      if(!$DAT = fopen($global_conf, 'w')){
        print "Could not open file: $global_conf<br>";
      }
      else{
        if(fwrite($DAT, serialize($defaults) === FALSE)){
          print "Couldn't write to file: $global_conf<br>";
        }
        fclose($DAT);
      }
    }
  }

  function update_fingerprints(){
    $fingerprints = PFCMD('update fingerprints');
    $oui = PFCMD('update oui');
    return implode('<br>', $fingerprints)."<br>".implode('<br>', $oui);
  } 

  function share_fingerprints($new_unknowns){
    global $abs_url, $current_top, $current_sub;

    if(!$new_unknowns){
      $my_table = new table("report unknownprints");
      $new_unknowns = set_default($my_table->rows, array());
    }
    if (! is_array($new_unknowns)) {
      $new_unknowns = array();
    }
    $new = array();
    foreach($new_unknowns as $new_unknown){
      $new[$new_unknown['dhcp_fingerprint']] = $new_unknown['vendor'] . ":" . $new_unknown['computername'] . ":" . $new_unknown['user_agent'];
    }

    # These next few lines kept track of what fingerprints have been submitted.
    if (isset($_SESSION['ui_global_prefs']['shared_fingerprints'])) {
      $current = $_SESSION['ui_global_prefs']['shared_fingerprints'];
    } else {
      $current = array();
    }
    $diff = array_diff_assoc($new, $current);

    if(count($diff)>0){
     $_SESSION['ui_global_prefs']['shared_fingerprints']=array_merge($current, $diff);
      save_global_prefs_to_file();
      foreach($diff as $fprint => $details){
        $content.= "$fprint:$details\n";
      }

      $msg .= "<form name='share_fingerprints' method='POST' action='http://www.packetfence.org/fingerprintsv2.php?ref=$abs_url/$current_top/$current_sub.php'>";
      $msg .= "  <input type='hidden' name='fingerprints' value='$content'>";
      $msg .= "</form>";
      $msg .= "<script>document.share_fingerprints.submit()</script>";
    }
    else{
      $msg .= "No new unknown fingerprints to share.";
    }
    return $msg;
  }

  function share_useragents($new_unknowns){
    global $logger;
    global $abs_url, $current_top, $current_sub;

    if(!$new_unknowns){
      $my_table = new table("report unknownuseragents");
      $new_unknowns = set_default($my_table->rows, array());
    }
    if (! is_array($new_unknowns)) {
      $new_unknowns = array();
    }
    $new = array();
    foreach($new_unknowns as $new_unknown){
      $new[$new_unknown['user_agent']] = array(
          'browser' => $new_unknown['browser'],
          'os' => $new_unknown['os'],
          'computername' => $new_unknown['computername'],
          'dhcp_fingerprint' => $new_unknown['dhcp_fingerprint'],
          'description' => $new_unknown['description']
      );
    }

    # These next few lines kept track of what fingerprints have been submitted.
    if (isset($_SESSION['ui_global_prefs']['shared_useragent_fingerprints'])) {
      $current = $_SESSION['ui_global_prefs']['shared_useragent_fingerprints'];
    } else {
      $current = array();
    }
    $diff = array_diff_assoc($new, $current);

    if(count($diff)>0){
      $_SESSION['ui_global_prefs']['shared_useragent_fingerprints']=array_merge($current, $diff);
      save_global_prefs_to_file();
      $content = base64_encode(gzcompress(serialize($diff)));
      $logger->debug("ready to send the following: $content");

      $msg .= "<form name='share_useragent_fingerprints' method='POST' action='http://www.packetfence.org/useragents.php?ref=$abs_url/$current_top/$current_sub.php'>";
      $msg .= "  <input type='hidden' name='useragent_fingerprints' value='$content'>";
      $msg .= "</form>";
      $msg .= "<script>document.share_useragent_fingerprints.submit()</script>";
    }
    else{
      $msg .= "No new unknown User-Agent fingerprints to share.";
    }
    return $msg;
  }

  function printSelect($values, $type, $default = false , $extra = false){
    if(!is_array($values)){
      print "<select $extra>\n";
      print "  <option value='0'>No Options\n";
      print "</select>";
      return false;
    }

    print "<select $extra>\n";
    foreach($values as $key => $val){
      if(strtolower($type) == 'hash'){   
        $default == $key ? $selected='SELECTED' : $selected = '';
        print "  <option value='$key' $selected>$val\n";
      }
      else{
        $default == $val ? $default='SELECTED' : $default = '';
        print "  <option value='$val' $default>$val\n";     
      }
    }
    print "</select>";
    return true;
  }

  function printMultiSelect($values, $type, $defaults = false , $extra = false){
    if(!is_array($values)){
      print "<select $extra>\n";
      print "  <option value='0'>No Options\n";
      print "</select>";
      return false;
    }

    // setting selected values expects an array so if we got a scalar we convert to array
    if(!is_array($defaults)) {
        $defaults = array($defaults);
    }

    print "<select $extra>\n";
    if (strtolower($type) == 'hash') {
      foreach ($values as $key => $val) {
        in_array($key, $defaults) ? $selected='SELECTED' : $selected = '';
        print "  <option value='$key' $selected>$val\n";
      }
    } else {
      foreach ($values as $key => $val) {
        in_array($val, $defaults) ? $selected='SELECTED' : $selected = '';
        print "  <option value='$val' $default>$val\n";
      }
    }
    print "</select>";
    return true;
  }

  function pf_error($severity, $error, $file, $line, $errcontext){
    $error_types = array('User Warning', 'User Notice', 'Warning', 'Notice', 'Core Warning', 'Compile Warning', 'User Error', 'Error', 'Parse', 'Core Error', 'Compile Error');
    
    $formname = "form_$error_$line";

    print "<form name='$formname' action='http://www.packetfence.org/bug_report.php' method='post'>";
    print "  <input type='hidden' name='referrer' value='https://{$errcontext[_SERVER][HTTP_HOST]}{$errcontext[_SERVER][SCRIPT_NAME]}'>";
    print "  <input type='hidden' name='context' value='".serialize($errcontext)."'>";
    print "  <input type='hidden' name='error' value='{$error_types[$severity]}: $error in $file on line $line'>";
    print "</form>";

    $error_message .= "<a href='#' onClick=\"document.$formname.submit(); return false;\"><img src='../images/bug.png' title='Report Bug' alt='Report Bug' style='border:none; margin-right:5px;'></a>";
    $error_message .= "<b>{$error_types["$severity"]}</b>:  $error in <b>$file</b> on line <b>$line</b><br>";

    print $error_message;
  } //end pf_error

  function show_calendar($id){
    print "<script type='text/javascript'>
             Calendar.setup(
             {
               inputField  : '$id',               // ID of the input field
               ifFormat    : '%Y-%m-%d %H:%M:00', // the date format
               button      : '$id',               // ID of the button
               timeFormat  : \"24\",
               showsTime   : true
             }
             );
           </script>";
  }

  function show_calendar_with_button($field,$button) {
    print "<script type='text/javascript'>
             Calendar.setup(
             {
               inputField  : '$field',            // ID of the input field
               ifFormat    : '%Y-%m-%d %H:%M:00', // the date format
               button      : '$button',           // ID of the button
               timeFormat  : \"24\",
               showsTime   : true
             }
             );
           </script>";
  }

  function show_calendar_with_button_without_time($field,$button) {
    print "<script type='text/javascript'>
             Calendar.setup(
             {
               inputField  : '$field',   // ID of the input field
               ifFormat    : '%Y-%m-%d', // the date format
               button      : '$button',  // ID of the button
               timeFormat  : \"24\",
               showsTime   : false
             }
             );
           </script>";
  }

