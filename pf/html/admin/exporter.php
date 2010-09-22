<?
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
 * @licence     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

include('common.php');
session_start();

if(isset($_SESSION['table']))
  $my_table=unserialize($_SESSION['table']);


if($_POST){
  ## FILENAME ##
  if($my_table->create_cmd)
    $filename = preg_replace("/\s+/", "_", $my_table->create_cmd).'.csv';
  else
    $filename = 'packetfence.csv';

  ## HEADERS ##
  foreach($my_table->headers as $header){
    if($_POST[$header]) {
      $my_headers[]=$header;
      $my_pretty_headers[]=pretty_header("$_POST[current_top]-$_POST[current_sub]",$header);
    }
  }


  ## ROWS ##
  foreach($my_table->rows as $row){
    unset($temp_row);

    foreach($my_headers as $header)
      $temp_row[]="\"".$row[$header]."\"";

    $my_rows[]=$temp_row;
  }

  $csv_output.=implode(",",$my_pretty_headers)."\n";

  foreach($my_rows as $my_row)
    $csv_output.=implode(",",$my_row)."\n";

  CSVify($csv_output, "application/text", "$filename");
  exit;
}



?>
<html>
<head>
  <title>PF::Export</title>
  <link rel="shortcut icon" href="/favicon.ico">
  <link rel="stylesheet" href="style.css" type="text/css"> 
</head>
<body class="popup">

<div id=content>
<h1>Select the fields you want to export</h1>
<form action=exporter.php method=post>
<input type="hidden" name="current_top" value="<? print $_GET[current_top] ?>">
<input type="hidden" name="current_sub" value="<? print $_GET[current_sub] ?>">
<table class=data_table>
  <tr>
<?
for($i=0; $i<count($my_table->headers); $i++){
  if($my_table->headers[$i]=="Edit")
    continue;
  print "<td align=center><input type=checkbox checked selected name=\"".$my_table->headers[$i]."\"></td>\n";
}

print "</tr><tr>\n";

for($i=0; $i<count($my_table->headers); $i++){
  if($my_table->headers[$i]=="Edit")
    continue;
  print "<td class=header align=center><b>".pretty_header("$_GET[current_top]-$_GET[current_sub]", $my_table->headers[$i])."<b></td>\n";
}

print "</tr><tr class=data>\n";

for($i=0; $i<count($my_table->headers); $i++){
  if($my_table->headers[$i]=="Edit")
    continue;
  foreach($my_table->rows as $row){
    if(isset($row[$my_table->headers[$i]])){
      $filler=$row[$my_table->headers[$i]]; 
      break;
    }
  }
  print "<td> $filler </td>";
  unset($filler);
}


?>
<!----
  </tr>
  <tr height=50>
    <td><img src=images/excel_icon.gif></td>
    <td><img src=images/html_icon.gif></td>
    <td><img src=images/excel_icon.gif></td>
  </tr>
  <tr>
    <td><input type=radio name=output value=CSV></td>
    <td><input type=radio name=output value=HTML></td>
    <td><input type=radio name=output value=TXT></td>

  </tr>
---!>
<tr height=30>
  <td align=right colspan=<?=count($my_table->headers)?>><input type=submit value=Export></td>
</tr>
</table>
</form>
</div>
</body>
</html>
