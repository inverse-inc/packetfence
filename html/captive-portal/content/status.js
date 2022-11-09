/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

document.addEventListener('DOMContentLoaded', function () {
  'use strict';
  var paused = false;
  (function () {

    var varsEl = document.getElementById('variables');
    var vars = JSON.parse(variables.textContent || variables.innerHTML);

    if (vars.expiration) {
      // Initialization of the countdown
      document.getElementById('expiration').innerHTML = countdown(vars.expiration * 1000, null, countdown.DAYS|countdown.HOURS|countdown.MINUTES, 2).toString();
      // Timer to update the countdown
      var timerId = countdown(
        vars.expiration * 1000,
        function(ts) {
          var secs = Math.round(ts.value / 1000);
          if (secs >= 0) {
            // No more time
            window.location = "/status?ts=" + ts.value;
            return;
          }
          if (secs > -60 || secs % 60 == 0) {
            // Countdown below 1 minute or on a minute; verify network access
            ajax(
              'get', // method
              '/status?ts=' + ts.value, // url
              null, // data
              function () { // success
                if (paused) {
                  window.location = "/status?ts=" + ts.value;
                  return;
                }
                document.getElementById('expiration').innerHTML = ts.toString();
              },
              function () { // failure
                paused = true;
                document.getElementById('expiration').parentNode.style.display = 'none';
                document.getElementById('pause').style.display = 'block';
              }
            );
          }
        },
        countdown.DAYS|countdown.HOURS|countdown.MINUTES|countdown.SECONDS,
        2
      );
    }
    else if (vars.time_balance) {
      document.getElementById('timeleft').innerHTML = countdown(
        new Date().getTime() + vars.time_balance * 1000,
        null,
        countdown.DAYS|countdown.HOURS|countdown.MINUTES,
        2
      ).toString();
    }

    var popup = document.getElementById('popup')
    if (popup) {
      Array.prototype.slice.call(popup.querySelectorAll('a[target="_new"]'))
        .forEach(function (node) {
          node.addEventListener('click', function (event) {
            event.stopPropagation();
            var newwindow = window.open("/status", "status_popup", "height=220,width=300");
            if (window.focus)
              newwindow.focus();
            return false;
          });
        });
    }

  })();
});
