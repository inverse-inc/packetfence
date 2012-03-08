<?php
/**
 * Import nodes from a CSV file 
 *
 * a front-end to pfcmd import nodes <file>
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
 * @copyright   2010 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

  require_once('../common.php');

  $current_top="node";
  $current_sub="import";

  include_once('../header.php');

  if ($_FILES['node_import_file']) {
    # process input
    $tmpfname = tempnam(get_var_path(), "import_nodes_");
    if (move_uploaded_file($_FILES['node_import_file']['tmp_name'], $tmpfname)) {
        
        # TODO proper file type validation (inspect file)
        # send the file to pfcmd import nodes
        $import_result = PFCMD("import nodes ". $tmpfname);

        # delete the file
        unlink($tmpfname);

    } else {
        $logger->warning("malicious file upload attempt?");
        $error = "There is a problem with file uploading. Contact an administrator.";
    }
  }

  # TODO: upload form could be prettier (text alignment)
  ?>

<div id='add'>
<form action="node/import.php" method="POST" enctype="multipart/form-data">
  <table class="add">
    <tr>
       <td><b>Import MACs</b></td>
    </tr>
    <tr>
       <td>List of nodes to automatically register. One MAC per line.</td>
    </tr>
    <tr>
       <td><input type="file" name="node_import_file"></td>
    </tr>
    <tr>
       <td align="right"><input type="submit" value="Import nodes"></td>
    </tr>
    <tr>
       <td>Importing automatically registers the nodes with pid 1.</td>
    </tr>
  </table>
</form>
</div>

  <center>Warning: It is not recommended to import files with more than a couple hundreds of records over 
    the Web interface.<br/>
    Use the CLI instead (<code>pfcmd import nodes &lt;filename.csv&gt;</code>) 
    or split your file and import in multiple passes.
  </center>

  <?php
  if($_FILES['node_import_file']) { ?>
    <table>
      <tr>
        <td><pre><?php
        if($import_result) {
          print "Import result:<br>";
          foreach($import_result as $line)
            print "$line<br>";
        } else {
            print "Something went wrong. Error: $error";
        }
        ?>
        </pre>
        </td>
      </tr>
    </table> <?
  }

  include_once('../footer.php');

?>
