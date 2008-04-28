<?

include("../common/sajax/Sajax.php");

function get_proc_usage(){

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

  ## MYSQL ACTIVITY
  $user = 'pf';
  $pass = 'packet';

  if(!preg_match("/[\'|\"|\;]/", $user) && !preg_match("/[\'|\"|\;]/", $pass)){
    exec("/usr/bin/mysqladmin status -u$user -p$pass", $sql_output);
    if(preg_match("/Queries\sper\ssecond\savg:\s+(\d+\.\d+)/", $sql_output[0], $matches)){
      $sql_queries = $matches[1];
    }    
  }

  return "$disk_usage|$load_1|$load_2|$load_3|$mem_usage|$sql_queries";
}

sajax_init();
sajax_export('get_proc_usage');
sajax_handle_client_request();

?>

<script type='text/javascript'>
        <? sajax_show_javascript(); ?>

        x_get_proc_usage(set_proc_usage);

        function set_proc_usage(result){
                var parts = result.split("|");

                if(parts[0] > 100){
                        parts[0] = 100;
                }

                document.getElementById('disk_usage').style.width = parts[0];
                document.getElementById('disk_percent').innerHTML = parts[0] + '%';

                if(parts[0] <= 33){
                        document.getElementById('disk_usage').style.backgroundColor='#FFCCBF';
                }
                else if(parts[0] <= 66){
                        document.getElementById('disk_usage').style.backgroundColor='#FF9980';
                }
                else{
                        document.getElementById('disk_usage').style.backgroundColor='#FF3300';
                }

                document.getElementById('load_1').innerHTML = parts[1];
                document.getElementById('load_5').innerHTML = parts[2];
                document.getElementById('load_15').innerHTML = parts[3];

                if(parts[4] > 100){
                        parts[4] = 100;
                }

                document.getElementById('mem_usage').style.width = parts[4];
                document.getElementById('mem_percent').innerHTML = parts[4] + '%';

                if(parts[4] <= 33){
                        document.getElementById('mem_usage').style.backgroundColor='#FFCCBF';
                }
                else if(parts[4] <= 66){
                        document.getElementById('mem_usage').style.backgroundColor='#FF9980';
                }
                else{
                        document.getElementById('mem_usage').style.backgroundColor='#FF3300';
                }

                document.getElementById('sql_queries').innerHTML = parts[5] + ' / second';
        }

</script>

<?

require_once('../common.php');

?>


<table>
  <tr>
    <td class='vitals_desc'>Disk Usage</td>
    <td>
      <div style='border:1px solid black; width: 100px; display:inline-block; position: relative;'>
        <div id='disk_usage' style='height: 100%; display:inline-block; position:absolute; top:0px; z-index:-1;'></div>
        <div id='disk_percent' style='positon:absoulte; width: 100%; text-align:center; padding-top: 1px; padding-bottom: 1px;'></div>
      </div>

    </td>
  </tr><tr>
    <td class='vitals_desc'>Memory Usage</td>
    <td>
      <div style='border:1px solid black; width: 100px; display:inline-block; position: relative;'>
        <div id='mem_usage' style='height: 100%; display:inline-block; position:absolute; top:0px; z-index:-1;'></div>
        <div id='mem_percent' style='positon:absoulte; width: 100%; text-align:center; padding-top: 1px; padding-bottom: 1px;'></div>
      </div>
    </td>
  </tr><tr>
    <td class='vitals_desc'>SQL Queries</td>
    <td align=right>
      <span id='sql_queries' style='display:inline-block; margin-left:5px; vertical-align:bottom;'></span><br>
    </td>
  </tr><tr>
    <td class='vitals_desc'>Load Average</td>
    <td align=right>
      1 min: <span id='load_1' style='display:inline-block; margin-left:5px; vertical-align:bottom;'></span><br>
      5 min: <span id='load_5' style='display:inline-block; margin-left:5px; vertical-align:bottom;'></span><br>
      15 min: <span id='load_15' style='display:inline-block; margin-left:5px; vertical-align:bottom; a'></span><br>
    </td>
  </tr>
</table>
