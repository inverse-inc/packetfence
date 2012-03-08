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
 * @author      Olivier Bilodeau <obilodeau@inverse.ca>
 * @copyright   2008-2010 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

$sajax = "get_usage";

function get_usage(){

  $disk_usage = $load_1 = $load_2 = $load_3 = $mem_usage = $sql_queries = 0;

  ## CPU LOAD
  $loads = explode(" ", file_get_contents("/proc/loadavg"));  
  $load_1 = $loads[0];
  $load_2 = $loads[1];
  $load_3 = $loads[2];

  ## MEMORY USAGE
  # now updated to remove memory in cache and buffers because clients kept saying they are running out of memory
  $meminfo = file('/proc/meminfo');
  foreach($meminfo as $line){
    if(preg_match("/^MemTotal:\s+(\d+)/", $line, $matches)){
      $memtotal = $matches[1];

    } else if(preg_match("/^MemFree:\s+(\d+)/", $line, $matches)){
      $memfree = $matches[1];

    } else if(preg_match("/^Buffers:\s+(\d+)/", $line, $matches)){
      $membuffers = $matches[1];

    } else if(preg_match("/^Cached:\s+(\d+)/", $line, $matches)){
      $memcache = $matches[1];
    }
    
    if($memfree && $memtotal && $membuffers && $memcache){
      $mem_usage = round(($memtotal-($memfree+$membuffers+$memcache)) / $memtotal * 100);
      continue;
    }
  }
  
  ## DISK USAGE
  # TODO: would be nice to have the space on the partition hosting mysql (if any) check for /var/lib/mysql
  exec('/bin/df -h /', $disk_output);
  foreach($disk_output as $line){
    if(preg_match("/(\d+)\%\s+\/$/", $line, $matches)){
      $disk_usage = $matches[1];
    }
  } 

  ## DATABASE ACTIVITY

  $user = get_configuration_value('database.user');
  $pass = get_configuration_value('database.pass');
  $host = get_configuration_value('database.host');

  if(!preg_match("/[\'|\"|\;]/", $user) && !preg_match("/[\'|\"|\;]/", $pass)){
    exec("/usr/bin/mysqladmin status -u$user -p$pass -h$host", $sql_output);
    if(preg_match("/Queries\sper\ssecond\savg:\s+(\d+\.\d+)/", $sql_output[0], $matches)){
      $sql_queries = $matches[1];
    }    
  }
  else{
    $sql_queries = '?';
  }

  return "$disk_usage|$load_1|$load_2|$load_3|$mem_usage|$sql_queries";
}

?>
