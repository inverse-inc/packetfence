/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

$(function() {
  'use strict';

  if (!navigator.userAgent.match('Safari') && navigator.userAgent.match('Macintosh')) {
    $('#addMessage').closest('div.media').removeClass('hide');
  }
});
