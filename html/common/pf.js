/**
 * PacketFence Javascript Library
 *
 * @author      Inverse inc. <info@inverse.ca>
 * @copyright   2005-2014 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

/**
   networkAccessCallback

   Called when access to the network outside registration or quarantine works
*/
var network_redirected = false;
function networkAccessCallback(destination_url) {

  network_redirected = true;

  // Trye to redirect browser in 3 seconds
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

function detectNetworkAccess(retry_delay, destination_url, external_ip) {
  "use strict";
  var errorDetected, loaded, netdetect, checker, initNetDetect;

  netdetect = $('#netdetect');
  netdetect.onerror = function() {
    errorDetected = true;
    loaded = false;
  };
  netdetect.onload = function() {
    errorDetected = false;
    loaded = true;
  };
  initNetDetect = function() {
    errorDetected = loaded = undefined;
    var netdetect = $('#netdetect');
    netdetect.src = "http://" + external_ip + "/common/network-access-detection.gif?r=" + Date.now();
    setTimeout(checker, retry_delay * 1000);
  };
  checker = function() {
    var netdetect = $('#netdetect');
    if (errorDetected === true) {
      initNetDetect();
    } else if (loaded === true) {
      networkAccessCallback(destination_url);
    } else {
      // Check the width or height of the image since we do not know if it is loaded
      if (netdetect.width || netdetect.height) {
        networkAccessCallback(destination_url);
      } else {
        initNetDetect();
      }
    }
  }
  initNetDetect();
}
