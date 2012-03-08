<?php
/**
 * printer.php
 *
 * Outputs table stored in session in a printer friendly format.
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
 * @author      Dominik Gehl <dgehl@inverse.ca>
 * @copyright   2008-2010, 2012 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

  require_once('common.php');

?>

<html>         
<head>
  <title>// packetfence //</title>
  <link rel="shortcut icon" href="/favicon.ico">
</head>

<body>

<?

  if($_SESSION['table']){
    $table = unserialize($_SESSION['table']);
    #if($table->editable){
    #  array_pop($table->headers);
    #}

    print "<div id='printer'>";
    $font_size = set_default($_GET['font_size'], 3);

    # Anti-XSS
    $font_size = htmlspecialchars($font_size, ENT_QUOTES | ENT_HTML401);
    $uri = htmlspecialchars($_SERVER[REQUEST_URI], ENT_QUOTES | ENT_HTML401);

    if($font_size < 5){
      print "<a href='$uri&font_size=".($font_size+1)."'>\n";
      print "  <img width='30px' border='0' src='images/big_font.gif' alt='Inbiggin Font'>\n";
      print "</a>\n";
    }
    if($font_size > 1){
      print "<a href='$uri&font_size=".($font_size-1)."'>\n";
      print "  <img width='22px' border='0' src='images/small_font.gif' alt='Smallify Font'>\n";
      print "</a>\n";
    }

    print "<table border=1 style='border-collapse:collapse;'>";
    print "<tr>";
    foreach($table->headers as $header){
      # TODO extract in CSS
      print "  <td style='background:#ddd;padding:8px;text-align:center;font-weight:bold;'>\n";
      print "    <font size='$font_size'>".pretty_header("$_GET[current_top]-$_GET[current_sub]", $header)."</font>\n";
      print "  </td>\n";
    }
    print "</tr>";

    foreach($table->rows as $row){
      print "<tr>";

      # Warning: some of the fancy lookups here are duplicated from common.php's big ass tableprint function
      # Make sure to maintain both. Actually why don't you redesign the thing to avoid this hack?
      foreach($row as $key => $cell){
        if ($key == 'dhcp_fingerprint' && $_SESSION['fingerprints']["$cell"]) {
          # TODO extract in CSS
          print "  <td style='padding:2px;'>\n";
          print "    <font size='$font_size'>".$_SESSION['fingerprints']["$cell"]."</font>\n";
          print "  </td>\n";
        } else if($key == 'vid' && $_SESSION['violation_classes']["$cell"]) {
          # TODO extract in CSS
          print "  <td style='padding:2px;'>\n";
          print "    <font size='$font_size'>".$_SESSION['violation_classes']["$cell"]."</font>\n";
          print "  </td>\n";
        } else {
          # TODO extract in CSS
          print "<td style='padding:2px;'><font size='$font_size'>$cell</font></td>\n";
        }
      }
      print "</tr>";
    }
    print "</table>";

  } else {
    print "No data";
  }

?>
