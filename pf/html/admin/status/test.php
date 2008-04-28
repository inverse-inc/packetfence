<?

  $db_user = $db_pass = '';

  if(file_exists('/usr/local/pf/conf/pf.conf')){
    $lines = file('/usr/local/pf/conf/pf.conf');

    for($i=0; $i<count($lines); $i++){
      if(preg_match("/\[database\]/", $lines[$i])){
        for($i=$i+1; $i<count($lines); $i++){
          if(preg_match("/\[.+\]/", $lines[$i]) || $db_user && $db_pass){
            break;
          }
          else if(preg_match("/^pass=(.+)/", $lines[$i], $matches)){
	    $db_pass =  $matches[1];
	  } 
          else if(preg_match("/^user=(.+)/", $lines[$i], $matches)){
	    $db_user =  $matches[1];
	  } 
        }
      }
    }
  }

  if(file_exists('/usr/local/pf/conf/pf.conf.defaults') && !$db_user || !$db_pass){
    $db_user = $db_pass = '';

    $lines = file('/usr/local/pf/conf/pf.conf.defaults');

    for($i=0; $i<count($lines); $i++){
      if(preg_match("/\[database\]/", $lines[$i])){
        for($i=$i+1; $i<count($lines); $i++){
          if(preg_match("/\[.+\]/", $lines[$i]) || $db_user && $db_pass){
            break;
          }
          else if(preg_match("/^pass=(.+)/", $lines[$i], $matches)){
	    $db_pass =  $matches[1];
	  } 
          else if(preg_match("/^user=(.+)/", $lines[$i], $matches)){
	    $db_user =  $matches[1];
	  } 
        }
      }
    }
  }





  print "User: $db_user\n";
  print "Pass: $db_pass\n\n";

?>
