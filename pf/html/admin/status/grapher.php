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
 * @author      Francis Lachapelle <flachapelle@inverse.ca>
 * @author      Olivier Bilodeau <obilodeau@inverse.ca>
 * @author      Francois Gaudreault <fgaudreault@inverse.ca>
 * @author      Dominik Gehl <dgehl@inverse.ca>
 * @copyright   2008-2011 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

  include_once("../common.php");
  include_once('../check_login.php');

  $types = array(
    'unregistered' => 'line', 
    'registered' => 'line', 
    'violations' => 'line', 
    'nodes' => 'line', 
    'os' => 'pie', 
    'os active' => 'pie', 
    'os all' => 'pie', 
    'osclass' => 'pie', 
    'osclass active' => 'pie', 
    'osclass all' => 'pie', 
    'bar' => 'bar',
    'ifoctetshistorymac' => 'stacked_without_fill',
    'ifoctetshistoryswitch' => 'stacked_without_fill',
    'ifoctetshistoryuser' => 'stacked_without_fill',
    'connectiontype' => 'pie',
    'connectiontype active' => 'pie',
    'connectiontype all' => 'pie',
    'connectiontypereg' => 'pie',
    'connectiontypereg active' => 'pie',
    'connectiontypereg all' => 'pie',
    'ssid' => 'pie',
    'ssid active' => 'pie',
    'ssid all' => 'pie'
  );

function jsgraph($options) {
  $type = set_default($options['type'], 'nodes');
  $size = set_default($options['size'], 'large');
  $span = set_default($options['span'], 'month');

  if (($type == 'ifoctetshistoryuser')||($type == 'ifoctetshistorymac')) {
    $chart_data = get_chart_data("graph $type {$options['pid']} start_time={$options['start_time']},end_time={$options['end_time']}");

    # For graphs with one data point, make them bar graphs
    if(count($chart_data['x_labels']) == 1){
          $single_point = 'bar';
    }

    print _jsgraph($chart_data['chart_data'],
                   $chart_data['x_labels'],
                   set_default($single_point, $GLOBALS['types'][$type], 'line'),
                   $size,
                   pretty_header('status-graphs', $type),
                   $options['start_time'] . " - " . $options['end_time']);
   
  } elseif ($type == 'ifoctetshistoryswitch') {    
    $chart_data = get_chart_data("graph $type {$options['switch']} {$options['port']} start_time={$options['start_time']},end_time=${options['end_time']}");
    
    # For graphs with one data point, make them bar graphs
    if(count($chart_data['x_labels']) == 1){
          $single_point = 'bar';
    }

    _jsgraph($chart_data['chart_data'],
             $chart_data['x_labels'],
             set_default($single_point, $GLOBALS['types'][$type], 'line'),
             $size,
             pretty_header('status-graphs', $type),
             $options['start_time'] . " - " . $options['end_time']);
    
  } else {

    if ($span == 'report') {
        $chart_data = get_pie_chart_data("report $type");
        $title = pretty_header('status-reports', $type);
        if ($GLOBALS['types'][$type] == 'pie') {
            $title .= ' distribution';
        }
        $subtitle = '';
    } else {
        $chart_data = get_chart_data("graph $type $span");
        # For graphs with one data point, make them bar graphs
        if(count($chart_data['x_labels']) == 1){
            $single_point = 'bar';
        }
        $title = pretty_header('status-graphs', $type);
        $subtitle = "Per ".ucfirst($span);
    }

    print _jsgraph($chart_data['chart_data'],
                   $chart_data['x_labels'],
                   set_default($single_point, $GLOBALS['types'][$type], 'line'),
                   $size, $title, $subtitle);
  }
}

function _jsgraph($series, $labels, $type, $size, $title, $subtitle) {
  $id = preg_replace('/[^a-zA-Z]+/', '', $title.$subtitle);
  $js = "\n";
  if (count($labels) > 0) {
    $js .= '<div id="' . $id . '" class="chart"></div>';
    $js .= '<script type="text/javascript">';
    $js .= "graphs.set('$id', {type: '$type', title: '$title', subtitle: '$subtitle', size: '$size', labels: ['" . implode("', '", $labels) . "'], series: {";
    $series_json = array();
    foreach(array_keys($series) as $name) {
      array_push($series_json, "'$name': [" . implode(", ", $series[$name]) . "]");
    }
    $js .= implode(", ", $series_json);
    $js .= "}});";
    $js .= "</script>\n";
  }
  
  return $js;
}

function get_pie_chart_data($cmd){
        $cached_data = preg_replace("/\s+/", '_', get_cache_path() . "$cmd");

        if(file_exists($cached_data)){
                $cache_time = set_default($_SESSION['ui_prefs']['cache_time'], 0) * 60;
                if(time() - filemtime($cached_data) < $cache_time){
                        return unserialize(file_get_contents($cached_data));
                }
        }

        $rows = array_slice(PFCMD($cmd), 1, -1);

        foreach($rows as $row){
                $parts = explode('|', $row);
                $x_labels[$parts[0]]=1;
                $chart_data['values'][]=$parts[2];
        }

    if (count($rows) > 0) {
        $data = array('x_labels' => array_keys($x_labels), 'chart_data' => $chart_data);
    } else {
        $data = array();
    }

        if(is_writeable($cached_data)){
                $handle = fopen($cached_data, 'w');
                fwrite($handle, serialize($data));
                fclose($handle);
        }

        return $data;    
}

function get_chart_data($cmd){
        $cached_data = preg_replace("/\s+/", '_', get_cache_path() . "$cmd");

        if(file_exists($cached_data)){
                $cache_time = set_default($_SESSION['ui_prefs']['cache_time'], 0) * 60;
                if(time() - filemtime($cached_data) < $cache_time){
                        return unserialize(file_get_contents($cached_data));
                }
        }

        $output = PFCMD($cmd);

        if (!is_array($output)) return false;
        $headers = array_shift($output); 
        $parts = explode('|', $headers);
        for($i=0; $i<count($parts); $i++){
          $index[$parts[$i]]=$i;
        }

        foreach($output as $row){
                $parts = explode("|", $row);
                if(!$parts[$index[series]]) 
                        $parts[2] = 'series1';

                $mydate = $parts[$index['mydate']];

                // This is in place because strtotime('8/2005') doesn't return the right value, so we change it to 8/1/2005.
                if(preg_match("/^(\d{1,2})\/(\d{4})$/", $mydate, $matches)){
                        $mytime = strtotime("$matches[1]/01/$matches[2]"); 
                        $temp_x_labels["$mydate"] = $mytime;
                        # $x_labels["$mydate"] = $mytime;
                 }
                else{
                        $temp_x_labels["$mydate"] = strtotime($mydate);
                        # $x_labels[$mydate] = strtotime($mydate);
                }

                $x_labels = $temp_x_labels;
                #$x_labels[$parts[$index[mydate]]] = strtotime($parts[$index[mydate]]);
                $all_series[$parts[$index[series]]]=1;
                $data[$parts[$index[mydate]]][$parts[$index[series]]]=$parts[$index[count]];
        }
        if (isset($x_labels)) {
          @asort($x_labels);
        }

        ## To get multiseries graphs to line up
        if($data){
                foreach($data as $date => $val){
                        if(preg_match("/^(\d{1,2})\/(\d{4})$/", $date, $matches)){
                                $date = "$matches[1]/01/$matches[2]"; 
                        }

                        $time = strtotime($date);
                        foreach($all_series as $series => $blah){
                                if($val[$series]){
                                        $chart_data[$series][$time]=$val[$series];
                                        $sizes[$series] += $val[$series];
                                }
                                else{
                                        $chart_data[$series][$time]=0;
                                }
                        }
                }
        }
        
        ## sort based on key (date), and then remove key. 
        if (isset($all_series)) {
          foreach($all_series as $series => $blah){
                ksort($chart_data[$series]);
                foreach($chart_data[$series] as $val){
                        $ar[] = $val;
                }
                $chart_data[$series] = $ar;
                unset($ar);
          }
        }

        // Sort chart_data based on lowest sum for better graphs
        if (isset($sizes)) {
          asort($sizes);

          foreach($sizes as $key => $val){
                $sorted_chart_data[$key] = $chart_data[$key];
          }
        }

        if($x_labels && $chart_data){
                $data =  array('x_labels' => array_keys($x_labels), 'chart_data' => $sorted_chart_data);

                $handle = fopen($cached_data, 'w');         
                fwrite($handle, serialize($data));            
                fclose($handle);

                return $data;
        }
        return false;
}

?>

