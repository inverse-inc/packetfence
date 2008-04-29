<head>
  <title>Packetfence Bug Reporting</title>
</head>

<body style='font-family: arial, geneva, lucida, sans-serif; font-size: 4mm;'>

<img src='bug_logo.gif'>
<div style='padding:10px; width:600px; border: 1px solid #AAAAAA; background: #f7f7f7;'>

<?

  $referrer = $_REQUEST['referrer'];

  $error = $_POST['error'];
  if(!$error){
    $error = 'Unknown error';
  }

  ## If submitting the bug report
  if($_GET['submit']){
    $email = $_POST['email'];
    if(!$email){
      $email = "(email not provided)";
    }

    $msg[] = "A bug report has been filed by $email.";

    if($_POST['error']){
      $msg[] = "Error Mesasge: $_POST[error]";
    }

    if($_POST['notes']){
      $msg[] = "User Notes: $_POST[notes]";
    }

    if($_POST['context']){
      $msg[] = "Context:";
      $msg[] = print_r($_POST['context'], true);
    }

    if(!mail('bugs@packetfence.org', "PF Bug Report", implode("\n", $msg), "From: bugs@packetfence.org")){
      print "Could not send email";
      exit;
    }

    print "Thank you, your bug report has been submitted.<br><br>";
    if($referrer){
      print "You'll now be redirected to $referrer.";
    }
    else{
      print "Could not find a referring URL, please manually navigate to your Packetfence GUI.";
    }
    print "<meta http-equiv='refresh' content='4;url=$referrer'></div>";
    exit;
  }

  $context = unserialize(stripslashes($_POST['context']));
  if(!$context){
    $context = array("No context provided");
  }

  ## All the variables in the current scope that you don't want to report on
  $ignore_context = array('HTTP_SERVER_VARS', 'HTTP_ENV_VARS', '_ENV');

  foreach($ignore_context as $var){
    unset($context[$var]);
  }

?>

    <form name='bug_report' action='bug_report.php?submit=true&referrer=<?=$referrer?>' method='post'>

    <span style='padding:10px; display:block; margin-bottom: 10px; text-align:center;'>
      <b>Please review the following information before submitting a bug report.</b>
    </span>    

    <span style='padding:10px; display:block; background: white; border:1px solid #BBBBBB; margin-bottom: 10px;'>
      <b>Error Message:</b> <code><?=$error?></code>
      <input type='hidden' name='error' value='<?=$error?>'>
    </span>

    <span style='padding:10px; display:block; background: white; border:1px solid #BBBBBB; margin-bottom: 10px'>
      The box below contains information about the Packetfence GUI when the error occurred.  The data collected is 
generic variables that will be used to fix the problem.  If you would prefer not to submit certain data, delete it from the box below before you submit the 
bug report.
      <textarea name='context' rows=50 cols=78 wrap=off style='margin-top:20px; font-family: courier;'><? print_r($context); ?></textarea>
    </span>

    <span style='padding:10px; display:block; background: white; border:1px solid #BBBBBB; margin-bottom: 10px'>
      Details of how the bug occurred (series of events, browser used, etc.)
      <textarea rows=5 cols=78 name='notes' style='margin-top:10px;'></textarea>
    </span>

    <span style='padding:10px; display:block; background: white; border:1px solid #BBBBBB; margin-bottom: 10px'>
      Email address we can contact if there are furthur questions:
      <input type='text' name='email'>
    </span>

    <span style='padding-right:10px; display:block; text-align:right;'>
      <input type='button' value='Cancel' onClick="location.href='<?=$referrer?>';">
      <input type='submit' value='Submit Bug Report'>
    </span>

    </form>
</div>

</body>
