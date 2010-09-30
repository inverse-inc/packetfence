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
 * @author      Dominik Gehl <dgehl@inverse.ca>
 * @copyright   2008-2010 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

  include("../common.php");
  include('../check_login.php');

  $type = set_default($_GET['type'], 'nodes');
  $span = set_default($_GET['span'], 'month');
  $size = set_default($_GET['size'], 'large');

  $jpgraph_dir = jpgraph_dir();  
  DEFINE('TTF_DIR', $_SERVER['DOCUMENT_ROOT'] . '/common/fonts/');

  include("$jpgraph_dir/jpgraph.php");

  require("$jpgraph_dir/jpgraph_line.php");
  require("$jpgraph_dir/jpgraph_bar.php");
  require("$jpgraph_dir/jpgraph_pie.php");
  require("$jpgraph_dir/jpgraph_pie3d.php");

  $types = array(
    'unregistered' => 'stacked', 
    'registered' => 'bar', 
    'violations' => 'bar', 
    'nodes' => 'stacked', 
    'os' => 'pie', 
    'os active' => 'pie', 
    'os all' => 'pie', 
    'osclass' => 'pie', 
    'osclass active' => 'pie', 
    'osclass all' => 'pie', 
    'bar' => 'bar',
    'ifoctetshistorymac' => 'stacked_without_fill',
    'ifoctetshistoryswitch' => 'stacked_without_fill',
    'ifoctetshistoryuser' => 'stacked_without_fill');

  if (($type == 'ifoctetshistoryuser')||($type == 'ifoctetshistorymac')) {
    $chart_data = get_chart_data("graph $type {$_GET['pid']} start_time={$_GET['start_time']},end_time=${_GET['end_time']}");
    
    # For graphs with one data point, make them bar graphs
    if(count($chart_data['x_labels']) == 1){
  	  $single_point = 'bar';
    }

    jpgraph($chart_data['chart_data'], $chart_data['x_labels'], set_default(set_default($single_point, $types[$type]), 'line'), $size, pretty_header('status-graphs', $type), $_GET['start_time'] . " - " . $_GET['end_time']);
   
  } elseif ($type == 'ifoctetshistoryswitch') {
    
    $chart_data = get_chart_data("graph $type {$_GET['switch']} {$_GET['port']} start_time={$_GET['start_time']},end_time=${_GET['end_time']}");
    
    # For graphs with one data point, make them bar graphs
    if(count($chart_data['x_labels']) == 1){
  	  $single_point = 'bar';
    }

    jpgraph($chart_data['chart_data'], $chart_data['x_labels'], set_default(set_default($single_point, $types[$type]), 'line'), $size, pretty_header('status-graphs', $type), $_GET['start_time'] . " - " . $_GET['end_time']);
   
    
  } else {

    $span == 'report' ? $chart_data = get_pie_chart_data("report $type") : $chart_data = get_chart_data("graph $type $span");
    
    # For graphs with one data point, make them bar graphs
    if(count($chart_data['x_labels']) == 1){
  	  $single_point = 'bar';
    }

    jpgraph($chart_data['chart_data'], $chart_data['x_labels'], set_default(set_default($single_point, $types[$type]), 'line'), $size, pretty_header('status-graphs', $type), "Per ".ucfirst($span));

  }

  function jpgraph($chart_data, $x_labels, $type = 'line', $size, $title, $subtitle){

	#extra sample data
	#$chart_data['registered nodes']=array(10,20,15,20,0,30,40,20,10);
	#$chart_data['aregistered nodes']=array(10,20,15,20,0,30,40,20,10);

 	if(!$chart_data){
		print file_get_contents("../images/graph_error.gif");
		return false;
	}

	if($size == 'small'){
	        $height = 300; $width = 450;
	}
 	else{
	  	$height = 400; $width = 600;
	}

        $colors=array('', '#0066B3', '#FF0000', 'darkolivegreen3', 'sienna', 'powderblue', 'olivedrab', 'orange', 'dodgerblue2', 'springgreen4');

	(count($chart_data) > 1 || $type == 'pie') ? $show_legend = true : $show_legend = false;

	if($show_legend){
        	$size == 'large' ? $cols = min(count($chart_data),$cols=3) : $cols = min(count($chart_data),$cols=2);
		if($type == 'pie'){
	        	$size == 'large' ? $cols = min(count($x_labels),$cols=3) : $cols = min(count($x_labels),$cols=2);
		}
		$spacer = ceil(count($chart_data)/$cols)*20;
		$height += $spacer*1.5;
	}

        $graph = new Graph($width, $height , "auto");

	if(count($x_labels)==1 && $type != 'bar'){  // to get around line graphs with one point
		array_unshift($x_labels, "0");
		foreach($chart_data as $key => $val){
			array_unshift($chart_data[$key], "0");	
		}
	}

	if($type == 'pie'){
	        $graph = new PieGraph($width, $height, "auto");
		$title=pretty_header('status-reports', 'osclass').' distribution';

	}

	$graph->title->Set(ucwords($title));
	if($subtitle != 'Per Report'){
  		$graph->subtitle->Set($subtitle);
	}

        $graph->SetScale("textlin");
        $graph->SetFrame(true);
	$show_legend ? $graph->SetMargin(60,40,10,$spacer+80) : $graph->SetMargin(60,40,10,60);

        $graph->ygrid->SetFill(true, '#FFC366@.5','#f7f7f7@.5');

        $graph->yaxis->HideZeroLabel();
        $graph->SetMarginColor("#f7f7f7"); 

        $color_num = 1;
        foreach ($chart_data as $group => $keys) {
		$values = $keys;
		if($type == 'line' || $type == 'stacked' || $type == 'stacked_without_fill'){
	                $$group = new LinePlot($values);
		}
		if($type == 'bar'){
	                $$group = new BarPlot($values);
		}
	
		if($type == 'pie'){
	                $$group = new PiePlot3D($values);
			$$group->SetCenter(.5, .38);
		}

                if ($color_num > count($colors) - 1) 
                        $color_num = 1;

                $this_color = $colors["$color_num"];
                $$group->SetColor($this_color);
		if($type == 'stacked' || $type == 'bar'){
	                $$group->SetFillColor($this_color);
		}
	
		if($type == 'line'){
	                $$group->mark->SetType(MARK_IMG_DIAMOND, 'gray', 0.2);
		}
	
		if($type != 'pie'){
			if($show_legend){	// to get rid of blank legends
        		        $$group->SetLegend(ucwords($group));
			}
		}

 	        if($type == 'pie'){
		        $$group->value->SetFont(FF_ARIAL,FS_NORMAL,8);
        	        $$group->SetLegends($x_labels);
		}

                $color_num++;
		$groups[]=$$group;
	 	if($type != 'stacked' && $type != 'bar' && $type != 'stacked_without_fill'){
	  	        $graph->Add($$group);
		}
       }                                 

       if(($type == 'stacked') || ($type == 'stacked_without_fill')) {
	        $accplot = new AccLinePlot($groups);
		$graph->Add($accplot);
       }
       if($type == 'bar'){
	        $accplot = new AccBarPlot($groups);
		$graph->Add($accplot);         
       }

        $graph->xaxis->SetTickLabels($x_labels);

	$size == 'large' ? $x = 20 : $x = 15;
	$interval = ceil(count($x_labels)/$x);

        $graph->xaxis->SetTextLabelInterval($interval);
        $graph->xaxis->SetLabelAngle(45);

        $graph->xaxis->SetFont(FF_ARIAL,FS_NORMAL,8);
        $graph->yaxis->SetFont(FF_ARIAL,FS_NORMAL,8);
        $graph->yaxis->title->SetFont(FF_ARIAL,FS_NORMAL);
        $graph->xaxis->title->SetFont(FF_ARIAL,FS_NORMAL);

        $graph->title->SetFont(FF_ARIAL,FS_NORMAL, 12);
        $graph->subtitle->SetFont(FF_ARIAL,FS_NORMAL, 9);

        $graph->legend->SetFont(FF_ARIAL,FS_NORMAL);
	if($show_legend){
        	$graph->legend->SetLayout(LEGEND_HOR); 
#		$graph->legend->Pos( 0.5,($height-($spacer+10))/$height,"center");
		$graph->legend->Pos( 0.5, 0.98, "center", "bottom");
		$graph->legend->SetColumns($cols);
	}


        $graph->img->SetAntiAliasing();

	$graph->Stroke();
}                                                         


function get_pie_chart_data($cmd){
	$cached_data = preg_replace("/\s+/", '_', $_SERVER['DOCUMENT_ROOT'] . "/tmp/jpgraph_cache/$cmd");

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

        $cached_data = preg_replace("/\s+/", '_', $_SERVER['DOCUMENT_ROOT'] . "/tmp/jpgraph_cache/$cmd");

        if(file_exists($cached_data)){
                $cache_time = set_default($_SESSION['ui_prefs']['cache_time'], 0) * 60;
                if(time() - filemtime($cached_data) < $cache_time){                        
                        return unserialize(file_get_contents($cached_data));
                }            
        }

	$output = PFCMD($cmd);

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

