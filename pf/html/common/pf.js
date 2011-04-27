/**
 * PacketFence Javascript Library
 *
 * @author      Olivier Bilodeau <obilodeau@inverse.ca>
 * @copyright   2011 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

/**
 fetchNodeStatus

 Sample usage:
 var response = fetchNodeStatus();
 if ( response != null && && response.status == "reg" && response.nbopenviolations == 0 ) {
   alert("you are authorized on the network");
 }
 */
function fetchNodeStatus() {

    // TODO prettier URL
    new Ajax.Request('/cgi-bin/register.cgi', {
      method: 'post',
      parameters: { mode: 'status', json: 'true' },
      requestHeaders: {Accept: 'application/json'},
    
      onSuccess: function(transport) {
        if (transport.responseJSON) {
          var response = transport.responseText.evalJSON(true);
          return response;
        }
      },

      onFailure: function(transport){ 
        // TODO return transport instead?
        return null;
      }

    });
} 

/**
 networkAccessCallback

 Called when access to the network outside registration or quarantine works
 */
var network_redirected = false;
function networkAccessCallback(destination_url, redirect_url) {

    network_redirected = true;

    // browser redirect
    // Firefox 3/4 needs a new forced destination and a little delay
    if (Prototype.Browser.Gecko) {
        performRedirect.delay(5, redirect_url);
        return;
    }

    // IE 8/9 takes a while (~20 seconds) so we warn the user
    if (Prototype.Browser.IE) {
        $('browser_notes').innerHTML = txt_ie;
        performRedirect.delay(5, destination_url);
        return;
    }

    // Chrome 10 / Safari 5 / IE9 (sometimes) flawless
    top.location.replace(destination_url);
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
 Opera 11 is broken (doesn't fire img's onload) we put in a special text to notice users
 http://my.cn.opera.com/community/forums/topic.dml?id=880632&t=1298063094
 */
function detectNetworkAccess(detectDiv, retry_delay, destination_url, redirect_url, external_ip) {
  
    // stop-condition
    if (!network_redirected) {
        // prepare image tag
        imgSrc = "http://" + external_ip + "/common/network-access-detection.gif";

        // put image tag in html content, onload will be fired if image loads successfully meaning network access works
        detectDiv.innerHTML = 
            "<img src=\"" + imgSrc + 
            "\"onload=\"networkAccessCallback('" + destination_url + "', '" + redirect_url + "')\">";

        // recurse
        detectNetworkAccess.delay(retry_delay, detectDiv, retry_delay, destination_url, redirect_url, external_ip);
    }
}

/**
 confirmToQuit

 When assigned to window.onbeforeunload this asks for a confirmation before leaving a page.
 See addConfirmToQuit().
 */
function confirmToQuit (e) {

  var message = "You have unsaved changes.",
  e = e || window.event;
  // For IE and Firefox
  if (e) {
    e.returnValue = message;
  }

  // For Safari
  return message;
}

/**
 addConfirmToQuit

 Call this when you have users to get a warning before leaving a page. 
 Add it to the onchange of form fields.
 */
function addConfirmToQuit() {
  window.onbeforeunload = confirmToQuit;
}

