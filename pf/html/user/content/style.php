<?php

  session_start();
  header('Content-type: text/css');

  $remediation_conf = '/usr/local/pf/conf/ui-global.conf';   

  if(file_exists($remediation_conf)){
    $global_conf = unserialize(file_get_contents($remediation_conf));  
    $current = $global_conf['remediation'];
  }  

  $title_font_color = set_default($current['title_font_color'], 'black');
  $title_font_size = set_default($current['title_font_size'], '25pt');
  $title_font = set_default($current['title_font'], 'Serif');

  $logo_src = set_default($current['logo_src'], "content/images/biohazard-sm.gif");

  $body_background_color = set_default($current['body_background_color'], '#F7F7F7');
  $body_border_color = set_default($current['body_border_color'], '#AAAAAA');
  $body_font_size = set_default($current['body_font_size'], '13pt');
  $body_font_color = set_default($current['body_font_color'], 'black');
  $body_font = set_default($current['body_font'], 'Serif');

  $list_background_color = set_default($current['list_background_color'], '#FFE6E6');
  $list_border_color = set_default($current['list_border_color'], '#990000');
  $list_font_color = set_default($current['list_font_color'], 'black');
  $list_font = set_default($current['list_font'], 'Serif');

//  $body_font_family = 'arial, geneva, lucida, sans-serif';

  function set_default($value, $default){               
    if(isset($value))
      return $value;
    else
      return $default;
  }
	
?>

#div_body{
        font-family: 	<?=$body_font?>;
	font-size:	<?=$body_font_size?>;
	color:		<?=$body_font_color?>;

	background: 	<?=$body_background_color?>;
	border: 	1px solid <?=$body_border_color?>;

	padding:	12px;
	margin-top:	10px;
	margin-bottom:	10px;
	margin-left:	auto;
	margin-right:	auto;

}

#header{
	width:		100%;
}

td.title{
	font-weight:	bold;
	font-size:	<?=$title_font_size?>;
	font-family:	<?=$title_font?>;
	color:	<?=$title_font_color?>;
	vertical-align: middle;
}

td.logo{
	vertical-align: middle;
}

#description{
	margin-top: 	20px;
	
}

#remediation{
	margin-top: 	20px;
}

#remediation ol{
	background:	<?=$list_background_color?>;
	border:		1px solid <?=$list_border_color?>;
	font-family:	<?=$list_font?>;
	color:		<?=$list_font_color?>;
	padding:	10px;
	list-style-position: inside;
}

#remediation li{
	padding:	1px;
}

	p.sub_header{
	font-weight: 	bold;
}

