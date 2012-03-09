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
?>
<head>
  <title>PF::Config::Help</title>
  <link rel="stylesheet" href="../style.css" type="text/css">
</head>

<body class="popup help">

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
