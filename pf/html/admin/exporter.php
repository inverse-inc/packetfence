<?
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
    if($_POST[$header])
      $my_headers[]=$header;
  }


  ## ROWS ##
  foreach($my_table->rows as $row){
    unset($temp_row);

    foreach($my_headers as $header)
      $temp_row[]="\"".$row[$header]."\"";

    $my_rows[]=$temp_row;
  }

  $csv_output.=implode(",",$my_headers)."\n";

  foreach($my_rows as $my_row)
    $csv_output.=implode(",",$my_row)."\n";

  CSVify($csv_output, "application/text", "$filename");
  exit;
}



?>

<head>
  <title>// packetfence //</title>
  <link rel="shortcut icon" href="/favicon.ico">
  <link rel="stylesheet" href="style.php" type="text/css"> 
</head>
<body>

<br>

<div id=content style='border: 1px solid #aaa;height:150px;width:100%;'>
<form action=exporter.php method=post>
<table class=data_table>
  <tr height=30>
    <td align=center colspan=<?=count($my_table->headers)?>><b>Select the fields you want to export</b></td>
  </tr>
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
  print "<td class=header align=center><b>".$my_table->headers[$i]."<b></td>\n";
}

print "</tr><tr class=odd>\n";

for($i=0; $i<count($my_table->headers); $i++){
  if($my_table->headers[$i]=="Edit")
    continue;
  foreach($my_table->rows as $row){
    if($row[$my_table->headers[$i]]){
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

