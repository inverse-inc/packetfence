/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

document.addEventListener('DOMContentLoaded', function () {
  'use strict';

  setInterval(function () {
    ajax(
      'post', // method
      getPortalUrl('/sponsor/check'), // url
      null, // data
      function () { // success
        window.location = getPortalUrl("/signup");
      }
    );
  }, 5000);
});
