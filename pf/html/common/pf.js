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
function networkAccessCallback(destination_url) {

    // browser redirect
    top.location.href = destination_url;
}

/**
 detectNetworkAccess

 Adding an image to a provided div in order to detect if network access outside registration or quarantine works.
 Will trigger networkAccessCallback() if image loads successfully.

 Known to work with Internet Explorer 8, Firefox 3.6, Chrome 9, Safari 5.
 Right now it doesn't work with Opera 11 and 11.01 because of a bug on their side:
 http://my.cn.opera.com/community/forums/topic.dml?id=880632&t=1298063094
 */
function detectNetworkAccess(detectDiv, retry_delay, destination_url, external_ip) {
  
  // prepare image tag
  imgSrc = "http://" + external_ip + "/common/network-access-detection.gif";

  // put image tag in html content, onload will be fired if image loads successfully meaning network access works
  detectDiv.innerHTML = "<img src=\"" + imgSrc + "\" onload=\"networkAccessCallback('" + destination_url + "')\">";

  // recurse
  detectNetworkAccess.delay(retry_delay, detectDiv, retry_delay, destination_url, external_ip);
}

