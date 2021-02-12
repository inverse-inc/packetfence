/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

$(function() {
  'use strict';

  var varsEl = document.getElementById('variables');
  var vars = JSON.parse(variables.textContent || variables.innerHTML);

  window.waitTime = vars.waitTime;
  window.timerbarAction = function() {
    top.location.href = vars.destination_url;
  };

  // Initialize progress bar (requires timerbar.js)
  initTimerbar();
});
