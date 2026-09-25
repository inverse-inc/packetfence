/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

document.addEventListener('DOMContentLoaded', function () {
  'use strict';

  var container = document.getElementById('waiting');
  var checkUrl = (container && container.getAttribute('data-check-url')) || '/sponsor/check';

  setInterval(function () {
    ajax(
      'post', // method
      getPortalUrl(checkUrl), // url
      null, // data
      function () { // success
        window.location = getPortalUrl("/signup");
      }
    );
  }, 5000);
});
