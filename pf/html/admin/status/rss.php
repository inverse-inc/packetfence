<?

  include('../common.php');
  
  $my_table = new table('person view all');

  ## Fudgification
  unset($my_table->rows, $my_table->headers);
  $my_table->rows[0]=array('joe','desc','something else');
  $my_table->rows[1]=array('bob','desc','something else');
  $my_table->rows[2]=array('henry','desc','something else');
  $my_table->headers[0]=array('name', 'desc', 'extra');
  

  $my_table->print_rss();

?>
