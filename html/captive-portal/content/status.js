/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

$(function() {
  'use strict';

  var paused = false;

  $(document).ready(function() {
    var varsEl = document.getElementById('variables');
    var vars = JSON.parse(variables.textContent || variables.innerHTML);

    if (vars.expiration) {
      // Initialization of the countdown
      $("#expiration").html(countdown(vars.expiration * 1000,
                                      null,
                                      countdown.DAYS|countdown.HOURS|countdown.MINUTES,
                                      2).toString());
      // Timer to update the countdown
      var timerId = countdown(
        vars.expiration * 1000,
        function(ts) {
          var secs = Math.round(ts.value/1000);
          if (secs >= 0) {
            // No more time
            window.location = "/status?ts=" + ts.value;
            return;
          }
          if (secs > -60 || secs % 60 == 0) {
            // Countdown bellow 1 minute or on a minute; verify network access
            $.ajax({
              url: "/status?ts=" + ts.value,
            })
              .done(function() {
                if (paused) {
                  window.location = "/status?ts=" + ts.value;
                  return;
                }
                $("#expiration").html(ts.toString());
              })
              .fail(function() {
                paused = true;
                $("#expiration").parent().hide();
                $("#pause").show();
              });
          }
        },
        countdown.DAYS|countdown.HOURS|countdown.MINUTES|countdown.SECONDS,
        2);
    }
    else if (vars.time_balance) {
      $("#timeleft").html(countdown(new Date().getTime() + vars.time_balance * 1000,
                                    null,
                                    countdown.DAYS|countdown.HOURS|countdown.MINUTES,
                                    2).toString());
    }

    $('#popup a[target="_new"]').on("click", function(event) {
      event.stopPropagation();
      var newwindow = window.open("/status", "status_popup", "height=220,width=300");
      if (window.focus) { newwindow.focus() }
      return false;
    });
  });
});
