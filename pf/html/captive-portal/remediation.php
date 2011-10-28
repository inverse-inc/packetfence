<?php
/**
 * index.php
 *
 * Shows remediation information to the user (called by redir.cgi).
 * Supports a preview mode for Administrators to preview a violation.
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
 * @author      Dominik Gehl <dgehl@inverse.ca>
 * @copyright   2008-2011 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php    GPL
 *
 * TODO: next step is to migrate this file into proper Perl/TT 
 *
 */

  header('Content-type: text/html; charset=utf-8');
  # if we view this page through Web Admin vhost it means we are in preview mode
  if ($_SERVER["VHOST"] == "ADMIN") {

    # they must be authenticated, the below will take care of it
    include('../admin/common.php');

    $preview = true;
    $template_path = $_SERVER['DOCUMENT_ROOT'] . "/../captive-portal/violations";

    # populating with fake data
    $user_data['ip'] = "127.0.0.1";
    $user_data['mac'] = "ff:ff:ff:ff:ff:ff";
  } else {

    # lib import
    include('../admin/common/helpers.inc');

    # normal mode
    $preview = false;
    $template_path = $_SERVER['DOCUMENT_ROOT'] . "/violations";

    # loading user-data
    $user_data['ip'] = $_SERVER['REMOTE_ADDR'];
    # Client IP Lookup if Proxy-Bypass is used
    if ($user_data['ip'] == '127.0.0.1') {
        if (isset($_SERVER['HTTP_X_FORWARDED_FOR'])) {
            $user_data['ip'] = $_SERVER['HTTP_X_FORWARDED_FOR'];
        }
    }

    $PFCMD=dirname(dirname($_SERVER['DOCUMENT_ROOT'])) . '/bin/pfcmd';
    $command = "history $user_data[ip]";
    exec("ARGS=".escapeshellarg($command)." $PFCMD 2>&1", $output, $total);

    $keys = explode('|',array_shift($output));
    $vals = explode('|',array_shift($output));

    for($i=0; $i< count($keys); $i++){
      $user_data[$keys[$i]]=$vals[$i];
    }
  }

  # grab informations from configuration
  $logo_src = get_configuration_value('general.logo');
  # FIXME we only support the first locale for now
  list($locale) = explode(',', get_configuration_value('general.locale'));
  $locale = trim($locale);

  # i18n
  setlocale(LC_ALL, $locale . ".UTF-8");
  bindtextdomain("packetfence", "/usr/local/pf/conf/locale");
  textdomain("packetfence");

  $template = $_GET['template'];
  # verify template's existence
  if (!file_exists("$template_path/$template.php") || preg_match("/[\'|\"|\/]/", $template)) {
      die("An error occured on this page, please contact the Helpdesk.");
  }

  include("$template_path/$template.php");

  $preview ? $title = "Preview: Quarantine Established!" : $title = "Quarantine Established!";

  include("templates/remediation.html");

?>
