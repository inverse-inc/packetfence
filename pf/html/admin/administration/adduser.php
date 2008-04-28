<?

  require_once('../common.php');

  $current_top="administration";
  $current_sub="adduser";

  include_once('../header.php');

  if($_POST['username'] && $_POST['password1'] && $_POST['password2']){
     if(preg_match("/(;|\&|\"|\')/", $_POST['username'])){
       print "Error: Username contains invalid characters";
       exit;
     }
     if(preg_match("/(;|\'|\"|\&)/", $_POST['password1'])){
       print "Error: password contains invalid characters";
       exit;
     }


     if($_POST['password1'] != $_POST['password2'])
       print "Passwords do not match!";
     else{
	$filename = "/usr/local/pf/conf/users/$_POST[username]";
        if(file_exists($filename)){
	  print "Error: User $_POST[username] already exists!";
	}
	else{
  	  exec("/usr/bin/htpasswd -b /usr/local/pf/conf/admin.conf $_POST[username] $_POST[password1]");
          $defaults = array('font-size' => 'medium', 'homepage' => 'status/dashboard.php');
  	  if (!$handle = fopen($filename, 'w+')) {
            echo "Cannot open file ($filename)";
            exit;
          }

          if (fwrite($handle, serialize($defaults)) === FALSE) {
            echo "Cannot write to file ($filename)";
            exit;
          }
          fclose($handle);        
          print "User $_POST[username] added";
       }
    }       
  }

?>

  <div id=history>
  <form action=administration/adduser.php name=history method=POST>
  <table class=main>
    <tr><td rowspan=20 valign=top><img src='images/adduser.png'></td></tr>      
    <tr>
      <td>Username</td>
      <td><input type=text name=username></td>
    </tr>
    <tr>
      <td>Password</td>
      <td><input type='password'  name='password1'></td>
    </tr>
    <tr>
      <td>Password (confirm)</td>
      <td><input type='password' name='password2'></td>
    </tr>
    <tr>
      <td colspan=2 align=right><input type=submit value='Add User'></td>
    </tr>
  </table>
  </form>  
  </div>

<?

  print "</table>";

  include_once('../footer.php');

?>

