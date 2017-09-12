/* -*- Mode: javascript; indent-tabs-mode: nil; js-indent-level: 2 -*- */

$(function () {
  /* Register tracker tooltips */
  $('#tracker [rel=tooltip]').tooltip({placement: 'bottom'});

  if (typeof initStep == 'function') initStep();
  if (typeof registerExits == 'function') registerExits();
});
