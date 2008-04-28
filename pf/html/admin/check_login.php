<?php

  set_error_handler('pf_error');

  session_start(); 
  $timeout = 3600;  // session timeout in seconds
  $abs_url="https://$HTTP_SERVER_VARS[HTTP_HOST]";

  if($_SESSION['ui_prefs']['ui_debug'] == 'true'){
    $ui_debug = true;
  }

  if(isset($_SESSION['ip_addr']) && $_SESSION['ip_addr'] != $_SERVER['REMOTE_ADDR']){
    header("Location: $abs_url/login.php?p=$_SERVER[REQUEST_URI]&ip_mismatch=true");
    exit;
  } 
  else if(! (isset($_SESSION['user']) && isset($_SESSION['passw']))){
    header("Location: $abs_url/login.php?p=$_SERVER[REQUEST_URI]");
    exit;
  }
  else if(time() - $_SESSION['last_active'] >= $timeout){
    session_destroy();
    unset($_SESSION);
    header("Location: $abs_url/login.php?p=$_SERVER[REQUEST_URI]&expired=true");
    exit;
  }
  else{
    $_SESSION['last_active'] = time();
  }

  ## MENU CACHING ##
  if(!isset($_SESSION['menus']['node'])){
    $menu_file = 'ui.conf';
    if ($_SESSION['group'] != 'admin') {
      $menu_file = 'ui-' . $_SESSION['group'] . '.conf';
    }
    $meta_all=PFCMD("ui menus file=$menu_file");
    foreach($meta_all as $meta){
      $meta_ar=preg_split("/\|/", $meta);

      switch(count($meta_ar)){
        case 2:
                $type="root";
                break;
        case 3:
                $type=$meta_ar[1];
                break;
        case 4:
                $type="$meta_ar[1]-$meta_ar[2]";
                break;
        case 5:
                $type="$meta_ar[1]-$meta_ar[2]-$meta_ar[3]";
                break;
      }

      $roots=preg_split("/:/", $meta_ar[ count($meta_ar)-1 ]);
      foreach($roots as $root)
        $_SESSION['menus'][$type][]=array_slice(preg_split("/=?'/", $root), 0, 2);
    }

    $version=PFCMD("version");
    $_SESSION['menus']['pf-version']=$version[0];
    $_SESSION['menus']['db-version']=$version[1];

    ## Fingerprint Caching
    if(!isset($_SESSION['fingerprints'])){
      $fingerprint_table=new table("fingerprint view all");
      if($fingerprint_table->rows){
        foreach($fingerprint_table->rows as $row){
          $_SESSION['fingerprints'][$row['fingerprint']] = $row['os'];
        }
      }
    }

    ## Violation Class Caching
    if(!isset($_SESSION['violation_classes'])){
      $violation_class_table=new table("class view all");
      if($violation_class_table->rows){
        foreach($violation_class_table->rows as $row){
          $_SESSION['violation_classes'][$row['vid']] = $row['description'];
        }
      }
    }

    ## UI Pref Caching
    if(file_exists("/usr/local/pf/conf/users/$_SESSION[user]")){
            $_SESSION['ui_prefs']=unserialize(file_get_contents("/usr/local/pf/conf/users/$_SESSION[user]"));
            get_global_conf();
    }
  } // end caching

?>
