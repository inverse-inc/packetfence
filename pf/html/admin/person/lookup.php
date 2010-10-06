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
 * @author      Dominik Gehl <dgehl@inverse.ca>
 * @copyright   2008-2010 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

require_once('../common.php');

$current_top="person";
$current_sub="lookup";

include_once('../header.php');

$view_item = set_default($_REQUEST['view_item'], '');

if($view_item){
  $person_lookup = PFCMD("lookup person $view_item");
  if($person_lookup[0] != $view_item){
    foreach($person_lookup as $extra){
      $parts = explode("|", $extra);
      $extra_info[$parts[0]]=$parts[1];
    }	
  }

  $person_view = new table("person view $view_item");

  if($person_view->rows[0]['pid'] == $view_item){
    $lookup['pid']  = $person_view->rows[0]['pid'];
    $lookup['firstname']  = $person_view->rows[0]['firstname'];
    $lookup['lastname']  = $person_view->rows[0]['lastname'];
    $lookup['email']  = $person_view->rows[0]['email'];
    $lookup['telephone']  = $person_view->rows[0]['telephone'];
    $lookup['company']  = $person_view->rows[0]['company'];
    $lookup['address']  = $person_view->rows[0]['address'];
    $lookup['notes'] = $person_view->rows[0]['notes'];

    $node_view = new table("node view pid=$view_item");
    if($node_view->rows){
      foreach($node_view->rows as $node){
        if($node['pid'] == $view_item){
	  unset($node['pid']);
          $lookup['macs'][$node['mac']] = $node;
          $lookup['macs'][$node['mac']]['OS Class'] = $_SESSION['fingerprints'][$node['dhcp_fingerprint']];
	
	  $vendor_lookup = PFCMD("lookup node $node[mac]");
	  foreach($vendor_lookup as $vendor){
            if(preg_match("/^Vendor\s+:\s+(.*)$/", $vendor, $matches)){
              $lookup['macs'][$node['mac']]['Vendor'] = $matches[1];
            }
	  }
        }
      }
    }

    if (array_key_exists('macs', $lookup)) {
      $violation_view = new table('violation view all');
      if($violation_view->rows){
        foreach($violation_view->rows as $violation){
          if(in_array($violation['mac'], array_keys($lookup['macs']))){
	    $mac = $violation['mac'];
	    unset($violation['mac']);
            $lookup['macs'][$mac]['violations'][] = $violation;
            $show_violations = true;
          }
        }
      }
    }
  }
  else{
    $lookup[] = "No results for '$view_item'";
  }

  if($show_violations){
    $PFCMD = pfcmd('class view all');
    array_shift($PFCMD);
    foreach($PFCMD as $line){
      $parts = preg_split("/\|/", $line);
      $violations[$parts[0]] = $parts[1];
    }
  }


}

function tab($tabs){
  return str_repeat("&nbsp;", $tabs*5);
}

function pretty_name($menu, $header){
  $pretty_name = $header;
  foreach($_SESSION[menus][$menu] as $submenu){
    if(preg_match("/^$header\*?$/", $submenu[0])){
      $pretty_name = $submenu[1];
    }
  }
  return $pretty_name;
}
?>

<div id="history">
  <table class="main">
    <tr>
      <td valign=top>
        <form action="person/lookup.php" method="post">
        <table>
          <tr>
            <td colspan="2"><b>Lookup a PID</b></td>
          </tr>
          <tr>
            <td>PID</td>
            <td><input type="text" name="view_item" value='<?=$view_item?>' ></td>
          </tr>
          <tr>
            <td colspan="2" align="right"><input type="submit" value="Lookup"></td>
          </tr>
        </table>
        </form>
      </td>
      <?if($view_item){ ?>
      <td class="contents">
        <table>
          <tr>
            <td>
            <?
         
	   if($lookup){
   	      foreach($lookup as $key => $val){
		if(is_array($val)){
		  print "<br><b>MACs associated with this PID:</b><br>";
		  foreach($val as $mac_key => $mac_val){
		      print "<table style='padding-left:15px;'>";
		      foreach($mac_val as $macinfo_key => $macinfo_val){
			if(is_array($macinfo_val)){
			  print "<tr><td colspan=2><br><b>Violations associated with this MAC:</b></td></tr></table>";
			  foreach($macinfo_val as $violation_key => $violation_val){
 		            print "<table style='padding-left:30px;'>";
			    foreach($violation_val as $violationinfo_key => $violationinfo_val){
			      if($violationinfo_val){
				if($violationinfo_key == 'vid')
  	  		          print "<tr><td>".pretty_name('violation-view', $violationinfo_key).":</td><td>".$violations["$violationinfo_val"]." ($violationinfo_val)</tr>";
				else
  	  		          print "<tr><td>".pretty_name('violation-view', $violationinfo_key).":</td><td>$violationinfo_val</tr>";
			      }
			    }
			  }
			  print "</table><br>";
			}	
			else{
			  if($macinfo_val){
                            switch ($macinfo_key) {
                              case 'connection_type':
  			        print "<tr><td>".pretty_name('node-view', $macinfo_key).":</td><td><span title='$macinfo_val'>$connection_type[$macinfo_val]</span></td></tr>";
                                break;

                              default: 
                                print "<tr><td>".pretty_name('node-view', $macinfo_key).":</td><td>$macinfo_val</td></tr>";
                            }
   			  }
			}
		      }
                    if(!is_array($lookup[macs][$mac_key][violations]))
    		      print "</table>";
		  }
		}
		else{
		  if($val){
	 	    print "<b>".ucfirst($key)."</b>: $val<br>";
                  }		
		  if($key == 'notes' && $extra_info){
 		    foreach($extra_info as $extra_val => $extra_key){
	 	      print "<b>".ucfirst($extra_key)."</b>: $extra_val<br>\n";
		    }
                  }
		}
	      }



	    }
            else
 	      print "No results found!";
            ?>
            </td>
          </tr>
        </table>
      </td>
      <?}?>
    </tr>
  </table>
</div>

<?php

include_once('../footer.php');

?>
