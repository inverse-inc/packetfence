<? 

function get_group($user) {
  return 'admin';
}

function check_input($input){
  if(preg_match("/^[a-zA-Z0-9\:\,\(\)]/", $input) && strlen($input) <= 15){
    return true; 
  }        
  else{
    print "Invalid parameter: $input<br>";
    return false;           
  }
} 

//function validate_user($user,$pass,$hash='') {
//  include("/usr/local/pf/conf/admin_ldap.conf");
//
//  if ($hash != '') {
//    return $hash;
//  }
//
//  $ldap = ldap_connect($ldap_host);
//  if (!$ldap) {
//    return false;
//  }
//  $bind = ldap_bind($ldap, $ldap_bind_dn, $ldap_bind_pwd);
//  if (!$bind) {
//    return false;
//  }
//  $result = ldap_search($ldap, $ldap_user_base, "$ldap_user_key=$user", array("dn"));
//  $info = ldap_get_entries($ldap, $result);
//  if (!$result) {
//    return false;
//  }
//  if ($info["count"] != 1) {
//    return false;
//  }
//  $user_dn = $info[0]["dn"];
//  $bind = ldap_bind($ldap, $user_dn, $pass);
//  if (!$bind) {
//    return false;
//  }
//  return md5($pass);
//}

function validate_user($user, $pass, $hash = ''){
  $file = file('/usr/local/pf/conf/admin.conf');
  foreach($file as $line){
    $line = rtrim($line);
    $info = explode(":", $line);
    if ($user == $info[0]) {
      if(!$hash){
        $hash = crypt($pass, $info[1]);
      }
      if($info[1] == $hash){
        return $hash;
      }
    }
  }
  return false;
}

$abs_url="https://$HTTP_SERVER_VARS[HTTP_HOST]"; 

if(!function_exists('session_start')){
  die("<div id='error'>Error: Your version of PHP does not have session support.  Session support is needed for this application</div>");
}

if (! is_writeable(session_save_path())) {
	  die("<div id='error'>Error: Your PHP session.save_path is not writable.</div>");
}

session_start(); 

// To test for cookie enabled browsers
setcookie ('test', 'test');

if(isset($_GET['logout']) || isset($_GET['ip_mismatch'])){
  session_unset();
  session_destroy();
}

else {
  if(isset($_SESSION['user']) && isset($_SESSION['passw'])) {
    if(validate_user($_SESSION['user'], '', $_SESSION['passw'])){
      if(is_readable("/usr/local/pf/conf/users/$_SESSION[user]")){
        $_SESSION['ui_prefs']=unserialize(file_get_contents("/usr/local/pf/conf/users/$_SESSION[user]")); 
        $homepage = $_SESSION['ui_prefs']['homepage'];
      }
      if(!$homepage){
        $homepage = 'status/dashboard.php';
      }
      $_GET['p'] ? header("Location: $abs_url$_GET[p]") : header("Location: $abs_url/$homepage");
      exit;
    }
    else{
      header("Location: $abs_url/login.php");
      exit;
    }
  }

  if (isset($_POST['username'], $_POST['password']) && check_input($_POST['username']) && check_input($_POST['password'])) {
    $hash = validate_user($_POST['username'], $_POST['password']);
    if(!$hash || !isset($_COOKIE['test'])){
      $failed = true;
    } else {
      $_SESSION['user'] = $_POST['username'];
      $_SESSION['group'] = get_group($_SESSION['user']);
      $_SESSION['passw'] = $hash;
      $_SESSION['last_active'] = time();
      $_SESSION['ip_addr'] = $_SERVER['REMOTE_ADDR'];
      if(is_readable("/usr/local/pf/conf/users/$_SESSION[user]")){
        $_SESSION['ui_prefs']=unserialize(file_get_contents("/usr/local/pf/conf/users/$_SESSION[user]")); 
      }
      if(is_readable("/usr/local/pf/conf/users/$_SESSION[user]")){
        $_SESSION['ui_prefs']=unserialize(file_get_contents("/usr/local/pf/conf/users/$_SESSION[user]")); 
        $homepage = $_SESSION['ui_prefs']['homepage'];
      }
      else{
        $homepage = 'status/dashboard.php';
      }
      isset($_GET['p']) ? header("Location: $abs_url$_GET[p]") : header("Location: $abs_url/$homepage");
      exit;
    }
  }
}

?>

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">

<html>

<head>
  <title>// packetfence //</title>
  <base href="<?=$abs_url?>/">
  <link rel="shortcut icon" href="/favicon.ico">
  <link rel="stylesheet" href="style.php" type="text/css">  
</head>

<body onload="document.login.<?=(isset($failed) ? "password" : "username")?>.focus();">

<br><br><br>

<div id="login" align=center>
  <form method="post" name="login" action="<? print "$_SERVER[PHP_SELF]?p="	. (array_key_exists('p', $_GET) ? $_GET['p'] :'');?>">
  <table>
    <tr height=30%>
      <td colspan=4 align=center><img src="/common/packetfence.png" alt="[ PacketFence ]"></td>
    </tr>
    <tr>
      <td colspan=4 align=center>
      <?	
	if(isset($_GET['ip_mismatch'])){
	  print "<div id='error'>Error!  Your IP address has changed since you logged on.  Please log in again.</div>"; 
	}

	if(isset($failed)){
	  if(!isset($_COOKIE['test'])){
	    print "<div id='error'>Error! Your browser does not have cookies enabled.  Cookies are required for using the PacketFence GUI.</div>";
	  }
	  else{
  	    echo "Invalid Username/Password";
  	  }
        }
        if (isset($_GET['logout'])){
   	  echo "Logged Out<br>";
	}
	else if(isset($_GET['expired'])){
	  echo "Your session has expired";
	}
      ?>	
      </td>
    </tr>
    <tr valign=bottom>
      <td width=25%></td>
      <td width=25% align=center>Username</td>
      <td width=25%align=left><input type="text" name="username" maxlength="20" value="<?=(isset($_POST['username']) ? $_POST['username'] : "")?>"></td>
      <td width=25%></td>
    </tr>
    <tr>
      <td></td>
      <td align=center>Password</td>
      <td align=left><input type="password" maxlength="20" name="password"></td>
      <td></td>
    </tr>
    <tr height=30% valign=top>
      <td></td>
      <td></td>
      <td align=right><input type="submit" value="Login"></td>
      <td></td>
    </tr>
    <tr bgcolor=#dddddd style='border-top:1px solid black;'>
      <td style='border-top:1px solid #bbbbbb; text-align:right;padding-right:10px;' colspan=4><font color=black><i>500 shades of gray, and growing!</i></td>
    </tr>
  </table>
  </form>
</div>

</html>
