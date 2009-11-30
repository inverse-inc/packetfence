<?php
/**
 * @licence http://opensource.org/licenses/gpl-2.0.php GPL
 */

require_once('../common.php');

$current_top="node";
$current_sub="lookup";

include_once('../header.php');

$view_item = set_default($_REQUEST['view_item'], '');

if($view_item){
  $lookup=PFCMD("lookup node $view_item");
}

?>

<div id='add'>
<form action="node/lookup.php" method="get">
  <table class="add">
    <tr>
       <td colspan="3"><b>Lookup a MAC</b></td>
    </tr>
    <tr>
       <td>MAC</td>
       <td><input type="text" name="view_item" value='<?=$view_item?>' ></td>
       <td>(XX:XX:XX:XX:XX:XX)</td>
    </tr>
    <tr>
       <td colspan="3" align="right"><input type="submit" value="Lookup"></td>
    </tr>
  </table>
</form>
</div>

      <?if($view_item){ ?>
        <table>
          <tr>
            <td><pre><?php
            if($lookup)
            foreach($lookup as $line)
              print "$line<br>";
            else
 	      print "No results found!";
            ?>
            </pre>
            </td>
          </tr>
        </table>
      <?}?>
</div>

<?

include_once('../footer.php');

?>
