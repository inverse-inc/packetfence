<?php
/**
 * @licence http://opensource.org/licenses/gpl-2.0.php GPL
 */

require_once('../common.php');

$current_top="administration";
$current_sub="version";

include_once('../header.php');

?>

  <div id=history>
  <table class=main>
    <tr>
      <td><?=meta("pf-version")?></td>
    </tr>
    <tr>
      <td><?=meta("db-version")?></td>
    </tr>
  </table>
  </form>  
  </div>

<?

include_once('../footer.php');

?>

