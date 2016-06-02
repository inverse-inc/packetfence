<?php
  error_log("Giving token to user");
  $length = 10;

  $randomString = substr(str_shuffle("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"), 0, $length);

?>
<h1>ACME Token system</h1>

<p>Here is your generated token: <b><?php echo $randomString ?></b>. Please keep it for future reference.</p>

<div>
<a href="http://YOUR_PORTAL_HOSTNAME/captive-portal?next=next">Click here to continue the registration process</a>
</div>
