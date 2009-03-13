<?

$current_top="violation";
$current_sub="add";
require_once('../common.php');

include_once('../header.php');

  $headings=get_headings($current_top);
  $vids_pfcmd=PFCMD("class view all");

  foreach($vids_pfcmd as $line){
    $parts=preg_split("/\|/", $line);
    $vids[]=array('vid' => $parts[2], 'desc' => $parts[4]);
  }
  array_shift($vids);
  

  print "<div id='add'>\n";
  print "<form action='$current_top/$current_sub.php' method='post'>\n";
  print "<input type=hidden name=count  value=".count($headings).">\n";
  print "<input type=hidden name=action value=add>\n";
  print "<input type=hidden name=commit value=true>\n";
  
  print "<table class='add'>\n";
  print "<tr><td rowspan=20 valign=top><img src='images/violation.png'></td></tr>"; 

  if($_POST){
    $result = PFCMD("$current_top view all");

    if($result){
      foreach($result as $line){
        if(stristr($line, $_REQUEST['val0'])){
          $add_info=$line;
        }
      }
    }

    if($add_info){  // this needs a little more
      print "<tr><td colspan=2><b>Added Record</b></td></tr>";
    }
    else{
      print "<tr><td colspan=2><b><font color=red>Unable to add record $_REQUEST[val0]</b></font></td></tr>";
    }
    print "<tr height=8px><td style='border-bottom:1px solid black;' colspan=4></tr></tr>";
  }

  for($i=0; $i<count($headings); $i++){
    print "  <tr>\n";
    print "    <td>".$headings[$i][0]."</td>\n";
    switch($headings[$i][0]){
      case "MAC":
        print "    <td><input type='text' name='val$i' value='$_GET[MAC]'></td>\n";
        break;
    	
    	case "Status":
    	print "    <td>\n";
    	print "      <select name='val$i'>\n";
    	print "        <option value='open'>Open</option>\n";
    	print "        <option value='closed'>Closed</option>\n";
        print "      </select>\n";
        print "    </td>\n";
     	break;
     	  
     	case "Identifier":
    	print "    <td>\n";
    	print "      <select name='val$i'>\n";
        foreach($vids as $vid) {
          print "      <option value='$vid[vid]'>$vid[desc] ($vid[vid])</option>\n";
        }

     	print "      </select>\n";
     	print "    </td>\n";
     	break;

     	case "Notes";
     	print "    <td><textarea rows=2 cols=20 name=val$i></textarea></td>\n";
     	break;

        default:
	print "    <td>".$headings[$i][1]."</td>\n";
	break;
    }
    print "  </tr>\n";

  }
  print "  <tr>\n";
  print "    <td></td>\n";
  print "    <td align='right'>\n";
  print "      <input class='button' type='submit' value='Add'></td>\n";
  print "  </tr>\n";

  print "</table>\n";
   
  print "</form>\n"; 
  print "</div>\n";


include_once('../footer.php');

?>
