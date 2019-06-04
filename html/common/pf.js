/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

/**
 * PacketFence Javascript Library
 *
 * @author      Inverse inc. <info@inverse.ca>
 * @copyright   2005-2017 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

/**
   networkAccessCallback

   Called when access to the network outside registration or quarantine works
 */
var network_redirected = false;
var network_logoff_popup = "";
function networkAccessCallback(destination_url) {

  network_redirected = true;

  //show a web notification
  if (txt_web_notification) showWebNotification(txt_web_notification, '/content/images/unlock.png');

  if(network_logoff_popup != "") window.open(network_logoff_popup);

  // Try to redirect browser in 3 seconds
  setTimeout(function() {
    performRedirect(destination_url);
  }, 3000);
}

/**
   performRedirect

   Simple wrapper to redirect the browser. The wrapper enables us to call the redirect with .delay().
 */
function performRedirect(destination_url) {
  top.location.replace(destination_url);
}

/**
   detectNetworkAccess

   Adding an image to a provided div in order to detect if network access outside registration or quarantine works.
   Will trigger networkAccessCallback() if image loads successfully.

   Browser support:
   Known to work with Internet Explorer 8 / 9, Firefox 3.6 / 4, Chrome 9 / 10, Safari 5.

   Firefox 3.5+: We are sending a special HTTP Header (X-DNS-Prefetch-Control off) to prevent the caching of DNS entries
   for more details see:
   - https://developer.mozilla.org/En/Controlling_DNS_prefetching
   - http://dev.chromium.org/developers/design-documents/dns-prefetching

   Opera 11 is broken (doesn't fire img's onload) we put in a special text to notice users
   http://my.cn.opera.com/community/forums/topic.dml?id=880632&t=1298063094
 */

Date.now = Date.now || function() { return +new Date; };

function detectNetworkAccess(retry_delay, destination_url, external_ip, image_path) {
  "use strict";
  var errorDetected, loaded, netdetect, checker, initNetDetect;

  netdetect = $('#netdetect');
  netdetect.error(function() {
    errorDetected = true;
    loaded = false;
  });
  netdetect.load(function() {
    errorDetected = false;
    loaded = true;
  });
  initNetDetect = function() {
    errorDetected = loaded = undefined;
    var netdetect = $('#netdetect');
    netdetect.attr('src',"http://" + external_ip + image_path + "?r=" + Date.now());
    setTimeout(checker, retry_delay * 1000);
  };
  checker = function() {
    var netdetect = $('#netdetect');
    if (errorDetected === true) {
      initNetDetect();
    }
    else if (loaded === true) {
      networkAccessCallback(destination_url);
    }
    else {
      // Check the width or height of the image since we do not know if it is loaded
      if (netdetect.width() || netdetect.height()) {
        networkAccessCallback(destination_url);
      } else {
        initNetDetect();
      }
    }
  }
  initNetDetect();
}

/**
   initWebNotifications

   Requests the necessary permissions to display Web Notifications if it's supported by the browser
 */
function initWebNotifications(){
  if (window.Notification){
    Notification.requestPermission(function(status) {
      // This allows to use Notification.permission with Chrome/Safari
      if (Notification.permission !== status) {
        Notification.permission = status;
      }
    });
  }
}

/**
   canWebNotifications

   Checks if the browser supports Web notifications and that the user has granted the permissions to show Web notifications
 */
function canWebNotifications(){
  if (window.Notification && Notification.permission === "granted") {
    return true;
  }
  return false;
}

/**
   showWebNotifications

   Displays a web notification if the user accepted it and if the browser supports it.
*/
function showWebNotification(message, icon){
  if (canWebNotifications()){
    try {
      var notification = new Notification(message, {icon:icon});
    } catch(err) {
      console.log("Error while creating notification...", err);
    }
  }  
}

/**
   getQueryParams

   Read a page's GET URL variables and return them as an associative array.
*/
function getQueryParams() {
  var vars = [], hash;
  var hashes = window.location.href.slice(window.location.href.indexOf('?') + 1).split('&');
  for(var i = 0; i < hashes.length; i++){
    hash = hashes[i].split('=');
    vars.push(hash[0]);
    vars[hash[0]] = hash[1];
  }
  return vars;
}

/**
  getPortalUrl

  Get a URL for the portal while taking in consideration the portal preview
*/

function getPortalUrl(url) {
  if(/\/portal_preview\//.test(window.location.href)) {
    return "/portal_preview"+url;
  }
  else {
    return url;
  }
}


$(function() {
  'use strict';

  /**
    Will record the destination URL on the server if the browser has a javascript interpreter
    This prevents the destination URL from being computed from an API call.
  */
  var wanted_destination_url = getQueryParams()["destination_url"];
  if (wanted_destination_url){
    $.post(
      "/record_destination_url",
      { destination_url: wanted_destination_url }
    );
  }

  $(document).on('keyup', '.tabbable',function(e){
    if(e.which==13 || e.which==32) {
      this.click()
    }
  });

  $('.disable-on-click').one('click', function(e){
    var target = $(e.target);
    target.click();
    target.attr("disabled", true);
  });
});

