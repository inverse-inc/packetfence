<?

  require_once('../common.php');

  $current_top="configuration";
  $current_sub="instructions";

  include_once('../header.php');
 
  $abs_url="https://$HTTP_SERVER_VARS[HTTP_HOST]";
  $preview = true;

  $classes = PFCMD('class view all');
  array_shift($classes);

  foreach($classes as $class){
    $parts = explode('|', $class);
    if($parts[8] != ''){
      $violations[$parts[0]] = $parts[1];
      $vid_types[$parts[0]] = $parts[8];
    }
  }
  asort($violations);

  in_array($_REQUEST['vid'], array_keys($violations)) ? $vid = $_REQUEST['vid'] : $vid = '1200001';
  $url = $vid_types[$vid];

  if(!$url){
    print "<table style='margin:20px;'>\n";
    print "<tr><td>\n";
    print "<div id='error'>Invalid VID '$vid' or URL is not defined for VID '$vid'</div>";
    print "</td></tr>\n";
    print "<tr><td>&nbsp;</td></tr>\n";
    print "<tr><td>&nbsp;</td></tr>\n";
    print "</table>\n";
    include_once('../footer.php');
    exit;
  }

  $template = dirname(dirname($_SERVER['DOCUMENT_ROOT'])) . "/html/user".preg_replace("/index.php\?template=/", 'violations/', $url).'.php';

  preg_match("/template=([a-zA-Z0-9_]+)(&admin=.+)?$/", $url, $matches);
  if(!$matches[1]){
    print "<table style='margin:20px;'>\n";
    print "<tr><td>\n";
    print "<div id='error'>Error: '$url' does not follow violation URL conventions, should be like: '/content/template=this_template&admin=yes'</div>";
    print "</td></tr>\n";
    print "<tr><td>&nbsp;</td></tr>\n";
    print "<tr><td>&nbsp;</td></tr>\n";
    print "</table>\n";
    include_once('../footer.php');
    exit;
  }
 
  if($matches[2]){
    $admin='yes';
  }

  $template = dirname(dirname($_SERVER['DOCUMENT_ROOT'])) . "/html/user/content/violations/$matches[1].php";

  if($_POST['update_content'] && !$_POST['preview']){

    if(!is_writeable($template)){
      print "<table style='margin:20px;'>\n";
      print "<tr><td>\n";
      print "<div id='error'>Cannot write to '$template', make sure it is writeable by user 'pf'</div>";
      print "</td></tr>\n";
      print "<tr><td>&nbsp;</td></tr>\n";
      print "<tr><td>&nbsp;</td></tr>\n";
      print "</table>\n";
      include_once('../footer.php');
      exit;
    }

    $msg = "<?\n\n";

    if($_POST['description_header']){
      $msg.='$description_header="'.sanitize($_POST['description_header']).'";'."\n\n";
    }
    if($_POST['description_text']){
      $msg.='$description_text="'.sanitize($_POST['description_text']).'";'."\n\n";
    }
    if($_POST['remediation_header']){
      $msg.='$remediation_header="'.sanitize($_POST['remediation_header']).'";'."\n\n";
    }
    if($_POST['remediation_text']){
      $msg.='$remediation_text="'.sanitize($_POST['remediation_text']).'";'."\n\n";
    }

    $msg .= "?>";

    if (!$handle = fopen($template, 'w+')) {
      print "<table style='margin:20px;'>\n";
      print "<tr><td>\n";
      print "<div id='error'>Cannot open file '$template'</div>";
      print "</td></tr>\n";
      print "<tr><td>&nbsp;</td></tr>\n";
      print "<tr><td>&nbsp;</td></tr>\n";
      print "</table>\n";
      include_once('../footer.php');
      exit;
    }
    if (fwrite($handle, $msg) === FALSE) {
      print "<table style='margin:20px;'>\n";
      print "<tr><td>\n";
      print "<div id='error'>Cannot write to file '$template'</div>";
      print "</td></tr>\n";
      print "<tr><td>&nbsp;</td></tr>\n";
      print "<tr><td>&nbsp;</td></tr>\n";
      print "</table>\n";
      include_once('../footer.php');
      exit;
    }
   
    fclose($handle);
    print "<div id='message_box'>Updated '$violations[$vid]' successfully!</div>";
  }

  if($_POST['preview']){
    $description_header = $_POST['description_header'];
    $description_text = $_POST['description_text'];
    $remediation_header = $_POST['remediation_header'];
    $remediation_text = $_POST['remediation_text'];
  }
  else{
    if(!@include($template)){
      print "<table style='margin:20px;'>\n";
      print "<tr><td>\n";
      print "<div id='error'>Error: Could not open template file '$template'</div>";
      print "</td></tr>\n";
      print "<tr><td>&nbsp;</td></tr>\n";
      print "<tr><td>&nbsp;</td></tr>\n";
      print "</table>\n";
      include_once('../footer.php');
      exit;
    }
  }
?>

<script type='text/javascript'>
  function edit(block){
    document.getElementById(block + '_box').style.display='block';
    document.getElementById(block + '_span').style.display='none';
  }

</script>

<table style='margin:20px;'>
  <tr>
    <td style='border:1px solid #aaa; background: white; padding:10px; vertical-align:top; width:150px;'>
      Select a Violation:<br>
      <form name='vid_select' method='get' action='<?=$current_top?>/<?=$current_sub?>.php'>
        <?printSelect($violations, 'HASH', $vid, "name='vid' onChange='document.vid_select.submit();'");?>
      </form>
    </td>
    <td style='border:1px solid #aaa; background: white; padding:10px;'>
      <form name='web_preview' method='post' action='<?=$current_top?>/<?=$current_sub?>.php'>
	<input type='hidden' name='vid' value='<?=$vid?>'>
	<table>
	  <tr><td>Description Header</td><td><input type='text' size=53 name='description_header' value='<?=$description_header?>'></td>
	  <tr><td>Description Text</td><td><textarea rows=6 cols=50  name='description_text'><?=$description_text?></textarea></td>

	  <tr><td>Remediation Header</td><td><input type='text' size=53 name='remediation_header' value='<?=$remediation_header?>'></td>
	  <tr><td>Remediation Text</td><td><textarea rows=6 cols=50  name='remediation_text'><?=$remediation_text?></textarea></td>
	</table>
	<div style='text-align:right;'><br><input type='submit' name='preview' value='Preview'><input type='submit' name='update_content' value='Update Page'></div>
      </form>
    </td>
  </tr>
    <?
      if($_POST['preview']){
	print "<tr><td id='preview' colspan=2 style='border:1px solid #aaa; background: white; padding:10px;'>";
        include(dirname(dirname($_SERVER['DOCUMENT_ROOT'])) . '/html/user/content/index.php');
	print "</td></tr>";
      }
    ?>
</table>

<?

  include_once('../footer.php');

  function sanitize($txt){
    $patterns = array("/(\\\)+/", '/"/', '/[$]/');
    $replacements = array('\\', '\"', '\\\$');
    return preg_replace($patterns, $replacements, $txt);
    #return preg_replace("/(\\\)+/", "\\", $txt);
  }


?>

