/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

$(function() {
  'use strict';

  var name,
      delay,
      $form = $('form[data-autosubmit]').first();

  if ($form.get(0)) {
    // Submit the first form after the specified delay (ms)
    name = $form.attr('name');
    delay = parseInt($form.data('autosubmit'));
    setTimeout($form.submit, delay);
  }
});
