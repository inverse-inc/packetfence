<?

  require_once('../common.php');

  $current_top="administration";
  $current_sub="remediation";

  include_once('../header.php');
 
  $abs_url="https://$HTTP_SERVER_VARS[HTTP_HOST]";

  $remediation_conf = dirname(dirname($_SERVER['DOCUMENT_ROOT'])) . '/conf/ui-global.conf';

  if($_POST){
    if(!file_exists($remediation_conf)){
      print "<div id='error'>Error:  Please create file, '$remediation_conf', and make sure it is writeable by user 'pf'.</div>"; 
    }

    else{
      $global_conf = unserialize(file_get_contents($remediation_conf));
      $global_conf['remediation'] = $_POST;
      $handle = fopen($remediation_conf, 'w');
      fwrite($handle, serialize($global_conf));
      fclose($handle);
      print "<div id='message_box'> Updated settings</div>";
    }
  }

  if(file_exists($remediation_conf)){
    $global_conf = unserialize(file_get_contents($remediation_conf));
    $current = $global_conf['remediation'];
  }

  if($_GET['set_default']){
    unset($current);
    print "<div id='message_box' style='background:#FFE6E6;'><b>Press 'submit' to return apperance to original settings.</b></div>";
  }

  $title_font_color = set_default($current['title_font_color'], 'black');
  $title_font_size = set_default($current['title_font_size'], '25pt');
  $title_font = set_default($current['title_font'], 'Sans-serif');

  $logo_src = set_default($current['logo_src'], "content/images/biohazard-sm.gif");

  $body_background_color = set_default($current['body_background_color'], '#F7F7F7');
  $body_border_color = set_default($current['body_border_color'], '#AAAAAA');
  $body_font_size = set_default($current['body_font_size'], '13pt');
  $body_font_color = set_default($current['body_font_color'], 'black');
  $body_font = set_default($current['body_font'], 'Sans-serif');

  $list_background_color = set_default($current['list_background_color'], '#FFE6E6');
  $list_border_color = set_default($current['list_border_color'], '#990000');
  $list_font_color = set_default($current['list_font_color'], 'black');
  $list_font = set_default($current['list_font'], 'Sans-serif');

  $fonts = array('Serif' => 'Serif', 'Sans-serif' => 'Sans-Serif', 'Cursive' => 'Cursive', 'Fantasy' => 'Scripty', 'Monospace' => 'Monospace', 'Impact' => 'Impact');

?>

<script type='text/javascript'>
  function preview(){
    // LIST ATTRIBUTES
    var tags = document.web_preview.getElementsByTagName('ol');
    for(i=0; i<tags.length; i++){
      tags[i].style.backgroundColor = document.web_style.list_background_color.value;
      tags[i].style.borderColor     = document.web_style.list_border_color.value;
      tags[i].style.color	    = document.web_style.list_font_color.value;
      tags[i].style.fontFamily	    = document.web_style.list_font.value;
    }
  
    // BODY ATTRIBUTES
    document.getElementById('div_body').style.backgroundColor=document.web_style.body_background_color.value;
    document.getElementById('div_body').style.borderColor=document.web_style.body_border_color.value;
    document.getElementById('div_body').style.color=document.web_style.body_font_color.value;
    document.getElementById('div_body').style.fontSize=document.web_style.body_font_size.value;
    document.getElementById('div_body').style.fontFamily=document.web_style.body_font.value;

    // TITLE ATTRIBUTES
    document.getElementById('title').style.color=document.web_style.title_font_color.value;
    document.getElementById('title').style.fontSize=document.web_style.title_font_size.value;
    document.getElementById('title').style.fontFamily=document.web_style.title_font.value;

    // LOGO
    document.getElementById('logo').src=document.web_style.logo_src.value;

  }
</script>

<table style='margin:20px;'>
  <tr>
    <td style='padding:10px; background: #F7F7F7; border:1px solid #aaaaaa; vertical-align:top;width:150px;'>
      <form name='web_style' action='<?=$current_top?>/<?=$current_sub?>.php' method='POST'>
        Title Font Color <input type='text' name='title_font_color' value='<?=$title_font_color?>' onBlur='preview();'><br>
        Title Font Size <input type='text' name='title_font_size' value='<?=$title_font_size?>' onBlur='preview();'><br>
	Title Font<br> <? printSelect($fonts, HASH, $title_font, "name='title_font' onChange='preview();'");?><br><br>


        Body Background Color <input type='text' name='body_background_color' value='<?=$body_background_color?>' onBlur='preview();'><br>
        Body Border Color <input type='text' name='body_border_color' value='<?=$body_border_color?>' onBlur='preview();'><br>
        Body Font Color <input type='text' name='body_font_color' value='<?=$body_font_color?>' onBlur='preview();'><br>
        Body Font Size <input type='text' name='body_font_size' value='<?=$body_font_size?>' onBlur='preview();'><br>
	Body Font<br> <? printSelect($fonts, HASH, $body_font, "name='body_font' onChange='preview();'");?><br><br>


        List Background Color <input type='text' name='list_background_color' value='<?=$list_background_color?>' onBlur='preview();'><br>
        List Border Color <input type='text' name='list_border_color' value='<?=$list_border_color?>' onBlur='preview();'><br>
        List Font Color <input type='text' name='list_font_color' value='<?=$list_font_color?>' onBlur='preview();'><br>
 	List Font<br> <? printSelect($fonts, HASH, $list_font, "name='list_font' onChange='preview();'");?><br><br>

        Logo Location <input type='text' name='logo_src' value='<?=$logo_src?>' onBlur='preview();'><br><br>

       <input type='button' value='Reset to Default' onClick="window.location='<?=$current_top?>/<?=$current_sub?>.php?set_default=true';">
       <input type='button' value='Preview' onClick='preview();'>
       <input type='submit' value='Submit'>
      </form>
    </td>
    <td style='border:1px solid #aaaaaa; background: white; padding:10px;'>
      <form name='web_preview' method='post'>
      <?=file_get_contents("https://localhost/content/index.php?template=failed_scan")?>
      </form>
    </td>
  </tr>
</table>

<script>preview();</script>

<?

  include_once('../footer.php');

?>
