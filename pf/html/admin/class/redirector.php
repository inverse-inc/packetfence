<?

$abs_url="https://$HTTP_SERVER_VARS[HTTP_HOST]";

if($_GET['admin']){
	$admin = '&admin=yes';
}

header("Location: $abs_url$_GET[view_item]$admin");

?>
