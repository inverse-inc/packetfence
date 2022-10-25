/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

document.addEventListener('DOMContentLoaded', function () {
  'use strict';

  var delay,
      form = document.querySelector('form[data-autosubmit]');

  if (form) {
    // Submit the first form after the specified delay (ms)
    delay = parseInt(form.dataset.autosubmit);
    setTimeout(function () { form.submit(); }, delay);
  }
});
