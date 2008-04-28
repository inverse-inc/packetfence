<?

include("common/sajax/Sajax.php");

function get_proc_usage(){
  $a = rand(0,100);
  $b = rand(0,100);

  return "$a|$b";
}

sajax_init();
sajax_export('get_proc_usage');
sajax_handle_client_request();

?>

<script type='text/javascript'>
        <? sajax_show_javascript(); ?>

	x_get_proc_usage(set_proc_usage);

        function set_proc_usage(result){
		var parts = result.split("|");
		for(i=0; i<parts.length; i++){
			
		}
        }

</script>

<?
require_once('common.php');

?>

Proc 1 

<div style='border:1px solid black; width: 120px; height:14px; display:inline-block;'>
  <div style='background: red; height: 14px; width: 15px; display:inline-block;'></div>
</div>
