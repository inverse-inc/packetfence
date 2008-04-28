<?php
  session_start();
  header('Content-type: text/css');

  $background    = "white";
  $body_text     = "black";

  $small  = '8';
  $medium = '10';
  $large  = '14';

  switch($_SESSION['ui_prefs']['font_size']){
      case "small":
        $size=$small;
        break;
      case "large":
        $size=$large;
        break;
      default:
        $size=$medium;
        break;
  }

  $header_font   ="black";
  $link_hover    ="white";

  $top_nav_font  ="#444";
  $bground1      ="#dddddd";
  $bground2      ="#bbbbbb";
  $bground3      ="#f7f7f7";

  $row_hover     ="#cccccc";

?>

#graph{
	margin:20px;
	text-align:center;
}

img {
	border:none;
}

BODY {
	color:<?=$body_text?>;
	background-color: <?=$background?>;
	padding: 0 5%;
	margin:0;
	font-family: arial, geneva, lucida, sans-serif;
        font-size:<?=$size?>pt;
}

a:link, a:visited {
	text-decoration:none;
	font-weight:bold;
/*	color: <?=$body_text?>;*/
	color: <?=$top_nav_font?>;

}

a.no_hover:hover{
	color:<?=$top_nav_font?>;
}

a:hover {
	color:<?=$link_hover?>;
}


div.header A{
	font-weight:bold;
	color:<?=$top_nav_font?>;
}

div.header a:hover{
 	color:<?=$link_hover?>;
}


div.header A.active{
       color: white;
}


div.topnav {
	margin:0;
        padding: 0 0 0 20px;
	white-space: nowrap;
}
	
div.topnav UL {
	white-space: nowrap;
	list-style: none;
	margin: 0;
	padding: 0;
	border: none;
	width:100%;
} 

div.topnav LI {	
	white-space: nowrap;
	display: block;
	margin: 0;
	padding: 0;
	float:left;
	width:auto;
	}
	
div.topnav A {
	display:block;
	color:<?=$top_nav_font?>;
	background:<?=$bground1?>;
	width:auto;
	text-decoration:none;
	margin:0;
	padding: 5px 10px;
	border-left: 1px solid #fff;
	border-top: 1px solid #fff;
	border-right: 1px solid #aaa;
        font-size:<?=$size+2?>pt;
	}
	
div.topnav A:active, div.topnav LI A.current {
	color:<?=$link_hover?>;
	background:<?=$bground2?>;
	}

div.topnav A:hover {
	color:<?=$link_hover?>
	}

div.subnav {
	white-space: nowrap;
	position:relative;
	margin:0;
	}

td.subnav{
	white-space: nowrap;
	background:<?=$bground2?>;
}

div.logout{
	white-space: nowrap;
	width:auto;
	margin-right:6px;
	margin-top:3px;
	float:right;
	color:<?=$body_text?>;
        font-size:<?=$size?>pt;
}

div.subnav UL {
	white-space: nowrap;
	list-style: none;
	margin: 0 0 0px 13px;
	padding: 0px;
	} 

div.subnav LI {
	position:relative;
	display: block;
	margin: 0;
	padding: 0;
	float:left;
	width:auto;
	}

div.subnav A:visited{
	color:white;
}


div.subnav A  {
	color:white;
	background:<?=$bground2?>;
	display:block;
	width:auto;
	text-decoration:none;
	margin:0;
	padding: 3px 10px;
        font-size:<?=$size+2?>pt;
	}

div.subnav A:active, div.subnav LI A.current {
	color:<?=$top_nav_font?>;
        background:<?=$bground1?>;
	border-left: 1px solid #fff;
	border-top: 1px solid #fff;
	border-right: 1px solid #aaa;
	}


div.subnav A:hover {
/*	color:<?=$top_nav_font?>;*/
	color:<?=$link_hover?>
	}


	
div.subnav BR, div.topnav BR {
	clear:both;
	}

#annex table{
	border-collapse:collapse;
        background:<?=$bground2?>;
}

#annex td{
        padding:0px;         
}


#content {
	font-size:<?=$size?>pt;
	height:100%;
	width: 100%;
	background-color:<?=$bground1?>;
}


#content A:hover {
color:<?=$link_hover?>;
	border: none;
	}

#content a.no_hover:hover {
	color:<?=$top_nav_font?>;
}

#content table.data_table { 
	border-collapse:collapse;
 	margin-left: auto;
	margin-right: auto;
	margin-bottom:15px;
	font-size:<?=$size+2?>pt;
}

td.content{
	background:<?=$bground1?>;
}

#content td{
	padding-right: 2px;
}


#footer table{
	border: 1px solid #aaa;
        font-size:<?=$size+2?>pt;
	background:<?=$bground2?>;
}

#footer A{
	color:<?=$link_hover?>;
}

#footer A.inactive{
	color:<?=$top_nav_font?>;
}


#footer A.active{
	color:white;
}

#footer a:hover {
	color:<?=$link_hover?>;
}

#footer select{
	background-color:<?=$bground1?>;
}

#result_count{
       font-size:<?=$size+1?>pt;
       text-align: center;
       font-weight:bold;
       color: black;
       padding:10px;
}

tr.header{
	color: <?=$top_nav_font?>;
	font-weight:bold;
}

td.header{
	background: <?=$bground2?>;
	padding:3px;
	border-top: 1px solid #fff;
        border-bottom: 1px solid #aaa;
        border-left: 1px solid #fff;
        border-right: 1px solid #aaa;
	text-align:center;
}


tr.even{
    background:<?=$bground1?>;
}

tr.odd{
       background:<?=$bground3?>;
}

#add table{
        padding: 5px;
        margin: 15px;
	border-top: 1px solid #fff;
	border-left: 1px solid #fff;
        border-bottom: 1px solid #aaa;
        border-right: 1px solid #aaa;
        background:<?=$bground3?>;
}

#add td{
	text-align:right;
	white-space:nowrap;
}

body.add{
	background:<?=$bground1?>;
}

.help_heading{
	background:<?=$bground1?>;
	color:white;
}

.help_content{
      background:<?=$bground2?>;
}


#login table{
	width:550px;
	height:500px;
	border: 1px solid <?=$bground2?>;
/*	cell-spacing:20px; */
	border-spacing:0;
	background: <?=$bground3?>;

}

.over {
	background: <?=$row_hover?>;
}

#status table{
	margin-top: 13px;
	border-collapse:collapse;	
}


#status tr.content{
	background: <?=$bground3?>;
}

#status td.system{
	text-align:center;
	padding:10px;
	border-right: 1px solid #aaa;
}


#status td.services{
	padding:10px;
}

#status td.startservice{
        padding:5px;
 	background:#70BE73;
}

#status td.stopservice{
        padding:5px;
 	background:#EB4D33;
}

#history table{
        font-size:<?=$size+1?>pt;
}

#history table.main{
	margin:8px;
	padding:10px;
        font-size:<?=$size+2?>pt;
	border: 1px solid <?=$bground2?>;
	background: <?=$bground3?>;
	}

#history a:hover {
	color:<?=$bground2?>;
}

#history td.contents{
	border-left: 1px solid #aaa;
	padding-left: 10px;
}

#history tr.title{
        text-align: right;
        font-size:<?=$size+1?>pt;
}

#history tr.heading{
        text-align: center;
        font-weight:bold;
        font-size:<?=$size+2?>pt;
}

ul#subnavlist { display:none; }
ul#subnavlist li { float: none; }

ul#subnavlist li a{
	padding: 0px;
	margin: 0px;
}

ul#navlist li:hover ul#subnavlist  {
	display: block;
	position: absolute;
	padding-top: 5px;
}

ul#navlist li:over ul#subnavlist  {
	display: block;
	position: absolute;
	padding-top: 5px;
}


ul#navlist li:hover ul#subnavlist li a{
	white-space:nowrap;
	display: block;
	border:1px solid #aaa;
	padding: 2px;
	width:150px;
}

#pf_status{
	margin-top:20px;
}

#pf_status table.main{
	margin:20px;
	padding:20px;
	border:1px solid #aaa;
	background:<?=$bground3?>;
}

#pf_status tr.header{
       background:<?=$bground2?>;
}

#pf_status tr.even{
       background:<?=$bground1?>;
}

#pf_status tr.odd{
       background:<?=$bground3?>;
}

#pf_status span.title{
	font-size:large;
}

#pf_status span.subtitle{
	text-align:center;
}

#vital_desc{
	display:inline-block;
	width:100px;
}

#pf_status td.vitals_desc{
	white-space:nowrap;
	padding-right:10px;
}


#vital_data{
	width:170px; 
	text-align:right; 
	display:inline;
}


#pf_status table.stats{
	border:1px solid black;
	border-collapse:collapse;
	margin-bottom:20px;
	width:100%;
}

#pf_status td.header{
	text-align:center;
	height:25px;
	width: 30%;
	white-space: nowrap;
	padding-left:5px;
	border:1px solid black;
	font-weight:bold;
}

#pf_status td.left{
	white-space: nowrap;
	height:25px;
	white-space: nowrap;
	padding-left:5px;
}

#pf_status{
	padding-left:5px;
	padding-right:5px;
}

#pf_status td.vitals_data{
	width:100%;
	text-align:right;
}

#pf_status td.right{
	width:33%;
	border-right:1px solid black;
	white-space: nowrap;
	text-align:right;
	height:25px;
	padding-right:5px;
}


#error{
	padding:10px;
	text-align:center;
	background:#FF7575;
}

#message_box{
	margin:10px;
	margin-left:5%;
	margin-right:5%;
	padding:10px;
	border:1px solid #aaa;
	background:#f7f7f7;
	text-align:center;
	vertical-align:middle;
}

#message_box a:hover{
	color:#aaa;
}

tr.admin_left{
	background: <?=$bground2?>;
	border:1px solid #aaa;
	padding:5px;
}

#vital_desc{
	vertical-align:top;
}

#percent_bar{          
        border:1px solid black;
        width: 100px;
        display:inline-block;
        position: relative;
        height:16px;
}             

#percent_bar div{    
        height: 100%;
        display:inline-block;
        position:absolute;
	left:0px;
        top:0px;            
}

#percent_bar span{
        position:absolute;
        width:100px;
        text-align:center;
	left:0px;
	top:0px;
}

