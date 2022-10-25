/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

function initTimerbar() {
  var timerbar = document.querySelector('.c-timerbar');
  var time = window.waitTime || 25;
  var delay = time / 20;
  var loaded = 0;

  var loader = document.createElement('div');
  timerbar.appendChild(loader);

  function incrCount() {
    loader.setAttribute('class', '');
    loader.classList.add('loaded-' + loaded);
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
