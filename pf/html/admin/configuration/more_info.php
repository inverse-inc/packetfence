<?php
/**
 * @licence http://opensource.org/licenses/gpl-2.0.php GPL
 */

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

$title=htmlspecialchars(array_shift($lines));
$default=htmlspecialchars(array_shift($lines));
$message='';
foreach ($lines as $line) {
    if ($message != '') {
        $message .= "<br>\n";
    }
    $message .= htmlspecialchars($line);
}

print "<h1>$title</h1>\n";
print "<p>$default</p>\n";
print "<p>$message</p>\n";


?>
