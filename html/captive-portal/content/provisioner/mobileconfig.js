/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

document.addEventListener('DOMContentLoaded', function () {
  'use strict';

  if (!navigator.userAgent.match('Safari') && navigator.userAgent.match('Macintosh')) {
    document.getElementById('addMessage').classList.remove('hide');
  }
});
