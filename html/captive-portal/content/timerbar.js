/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

function initTimerbar() {
  var timerbar = $('.c-timerbar');
  var time = window.waitTime || 25;
  var delay = time / 20;
  var loaded = 0;

  timerbar.append($('<div>'));
  var loader = timerbar.find('div');

  function incrCount() {
    loader.removeClass();
    loader.addClass('loaded-' + loaded);
    if (loaded < 100) {
      loaded += 5;
      setTimeout(incrCount, delay * 1000);
    }
    else {
      if (window.timerbarAction)
        window.timerbarAction();
    }
  }

  incrCount();
}
