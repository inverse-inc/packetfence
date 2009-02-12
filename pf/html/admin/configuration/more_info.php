<?
  include("../common.php");
?>
<head>
  <title>PF::Config::Help</title>
  <link rel="stylesheet" href="../style.css" type="text/css">
</head>

<body class="popup">

<div id="content">
<?
if(!isset($_GET['option']))
  die("No option selected");

if(!preg_match("/\!|\@|\#|\$|\%|\^|\&|\*|\:|\;|\"\|\'/", $_GET['option']))
  die("Invalid option!");

$lines=PFCMD("config help {$_GET['option']}");

$title=array_shift($lines);
$default=array_shift($lines);
$message=implode(" ", $lines);

print "<h1>$title</h1>\n";
print "<p>$default</p>\n";
print "<p>$message</p>\n";


?>
