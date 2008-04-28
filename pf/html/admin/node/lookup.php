<?php
require_once('../common.php');

$current_top="node";
$current_sub="lookup";

include_once('../header.php');

$view_item = set_default($_REQUEST['view_item'], '');

if($view_item){
  $lookup=PFCMD("lookup node $view_item");
}

?>

<div id="history">
  <table class="main">
    <tr>
      <td>
        <form action="node/lookup.php" method="post">
        <table>
          <tr>
            <td colspan="2"><b>Lookup a MAC</b></td>
          </tr>
          <tr>
            <td>MAC</td>
            <td><input type="text" name="view_item" value='<?=$view_item?>' ></td>
          </tr>
          <tr>
            <td colspan="2" align="right"><input type="submit" value="Lookup"></td>
          </tr>
        </table>
        </form>
      </td>
      <?if($view_item){ ?>
      <td class="contents">
        <table>
          <tr>
            <td>
            <?php
            if($lookup)
            foreach($lookup as $line)
              print "$line<br>";
            else
 	      print "No results found!";
            ?>
            </td>
          </tr>
        </table>
      </td>
      <?}?>
    </tr>
  </table>
</div>

<?

include_once('../footer.php');

?>
