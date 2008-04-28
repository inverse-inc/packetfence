<?

$sajax = "get_usage";

function get_usage(){

  $disk_usage = $load_1 = $load_2 = $load_3 = $mem_usage = $sql_queries = 0;

  ## CPU LOAD
  $loads = explode(" ", file_get_contents("/proc/loadavg"));  
  $load_1 = $loads[0];
  $load_2 = $loads[1];
  $load_3 = $loads[2];

  ## MEMORY USAGE
  $meminfo = file('/proc/meminfo');
  foreach($meminfo as $line){
    if(preg_match("/^MemTotal:\s+(\d+)/", $line, $matches)){
      $memtotal = $matches[1];
    }
    else if(preg_match("/^MemFree:\s+(\d+)/", $line, $matches)){
      $memfree = $matches[1];
    }
    
    if($memfree && $memtotal){
      $mem_usage = round(($memtotal-$memfree) / $memtotal * 100);
      continue;
    }
  }
  
  ## DISK USAGE
  exec('/bin/df -h /', $disk_output);
  foreach($disk_output as $line){
    if(preg_match("/(\d+)\%\s+\/$/", $line, $matches)){
      $disk_usage = $matches[1];
    }
  } 

  ## DATABASE ACTIVITY
  if($db_creds = get_db_creds()){

    $user = $db_creds['db_user'];
    $pass = $db_creds['db_pass'];

    if(!preg_match("/[\'|\"|\;]/", $user) && !preg_match("/[\'|\"|\;]/", $pass)){
      exec("/usr/bin/mysqladmin status -u$user -p$pass", $sql_output);
      if(preg_match("/Queries\sper\ssecond\savg:\s+(\d+\.\d+)/", $sql_output[0], $matches)){
        $sql_queries = $matches[1];
      }    
    }
  }
  else{
    $sql_queries = '?';
  }

  return "$disk_usage|$load_1|$load_2|$load_3|$mem_usage|$sql_queries";
}

function get_db_creds(){
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

  if($db_user && $db_pass)  
    return array('db_user' => $db_user, 'db_pass' => $db_pass);
  else
    return false;
}

?>
