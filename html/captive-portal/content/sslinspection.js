/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

document.addEventListener('DOMContentLoaded', function () {
  'use strict';

  document.getElementById('test').addEventListener('click', function () {
    document.getElementById('testFailure').classList.add('hide');
    ajax(
      'get', // method
      'https://packetfence.org/ssl-test/', // url
      null, // data
      function () { // success
        window.location.href = "/captive-portal?next=next";
      },
      function () { // failure
        document.getElementById('testFailure').classList.remove('hide');
      }
    );
    return false;
  });
});

