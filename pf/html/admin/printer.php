<?

  require_once('common.php');

?>

<html>         
<head>
  <title>// packetfence //</title>
  <link rel="shortcut icon" href="/favicon.ico">
</head>

<body>

<?
  if($_GET['img_src']){
    print "<img src='$_GET[img_src]'>";
  }


  else if($_SESSION['table']){
    $table = unserialize($_SESSION['table']);
    if($table->editable){
      array_pop($table->headers);
    }

    print "<div id='printer'>";
    $font_size = set_default($_GET['font_size'], 3);

    if($font_size < 5){
      print "<a href='".$_SERVER[REQUEST_URI]."&font_size=".($font_size+1)."'><img width='30px' border='0' src='images/big_font.gif' alt='Inbiggin Font'></a>";
    }    
    if($font_size > 1){
      print "<a href='".$_SERVER[REQUEST_URI]."&font_size=".($font_size-1)."'><img width='22px' border='0' src='images/small_font.gif' alt='Smallify Font'></a>";
    }    

    print "<table border=1 style='border-collapse:collapse;'>";
    print "<tr>";
    foreach($table->headers as $header){
      print "<td style='background:#ddd;padding:8px;text-align:center;font-weight:bold;'><font size='$font_size'>".pretty_header("$_GET[current_top]-$_GET[current_sub]", $header)."</font></td>";
    }
    print "</tr>";

    foreach($table->rows as $row){
      print "<tr>";
      foreach($row as $cell){
        print "<td style='padding:2px;'><font size='$font_size'>$cell</font></td>";
      }
      print "</tr>";
    }
  print "</table>";
  }



?>

<!--<script type="text/javascript">window.print();</script>-->
