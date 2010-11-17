<?php
/**
 * TODO short desc
 *
 * TODO long desc
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
 * USA.
 * 
 * @author      Olivier Bilodeau <obilodeau@inverse.ca>
 * @copyright   2008-2010 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

  set_error_handler('pf_error', (E_ALL & ~E_NOTICE & ~E_STRICT));

  session_start(); 
  $timeout = 3600;  // session timeout in seconds
  $abs_url="https://$HTTP_SERVER_VARS[HTTP_HOST]";

  require_once 'common/helpers.inc';
  require_once 'common/adminperm.inc';
  require_once 'Log.php';
  // TODO port hard-coded path to get_pf_path
  $logger_file = &Log::factory('file', '/usr/local/pf/logs/admin_debug_log');
  //$disp_conf = array('error_prepend' => '<div style="border: 1px solid #aaa; background: #FFE6BF; padding:5px;">',
  //                   'error_append' => '</div>');
  //$logger_disp = &Log::factory('display', '', '', $disp_conf, PEAR_LOG_INFO);
  $logger = &Log::singleton('composite', '', '', '', PEAR_LOG_INFO);
  $logger->addChild($logger_file);
  //$logger->addChild($logger_disp);

  $debug_log = '';
  if($_SESSION['ui_prefs']['ui_debug'] == 'true'){
    $ui_debug = true;
    //$logger_disp->setMask(Log::MAX(PEAR_LOG_DEBUG));
    $logger_file->setMask(Log::MAX(PEAR_LOG_DEBUG));
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

    ## Node Categories Caching
    nodecategory_caching();

    ## UI Pref Caching
    if(file_exists(dirname(dirname($_SERVER['DOCUMENT_ROOT'])) . "/conf/users/" . $_SESSION['user'])){
            $_SESSION['ui_prefs']=unserialize(file_get_contents(dirname(dirname($_SERVER['DOCUMENT_ROOT'])) . "/conf/users/" . $_SESSION['user']));
            get_global_conf();
    }

    # Admin Permission Caching
    parse_and_cache_permission_file();
  } // end caching

