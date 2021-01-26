/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

$(function() {
  'use strict';

  // check if windows 64 bits
  // swap the primary and alternate
  if (navigator.userAgent.indexOf("WOW64") != -1 ||
      navigator.userAgent.indexOf("Win64") != -1 ) {
    var new_primary = $('#alternate_download').getAttribute("href");
    if (new_primary != "") {
      $('#alternate_download').setAttribute('href', $('#primary_download').getAttribute('href'));
      $('#primary_download').setAttribute('href', new_primary);
    }
  }
});
