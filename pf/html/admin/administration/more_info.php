<?
  include("../common.php");
?>
<head>
  <title>PF::Config::Help</title>
  <link rel="stylesheet" href="../style.php" type="text/css">
</head>

<?
if(!isset($_GET['option']))
  die("No option selected");

if(!preg_match("/\!|\@|\#|\$|\%|\^|\&|\*|\:|\;|\"\|\'/", $_GET['option']))
  die("Invalid option!");

$lines=PFCMD("config help {$_GET['option']}");

$title=array_shift($lines);
$default=array_shift($lines);
$message=implode(" ", $lines);


print "<div class=\"help_heading\" align=\"center\"><font size=5>$title</font></div>";
print "<div class=\"help_content\"><font size=3>$default<br><Br></font></div>";
print "<div class=\"help_content\"><font size=3>$message</font></div>";


?>
