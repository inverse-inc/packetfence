/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

$(function() {
  'use strict';

  var dots,
      dotsParent = document.getElementById('dots'),
      cards = document.getElementsByClassName('card');

  initDots();
  
  function initDots() {
    var index;

    if (cards.length > 1) {
      for (index = 0; index < cards.length; index++) {
        cards[index].id = 'card-' + index;
        addDot(dotsParent,
               index,
               !cards[index].classList.contains('card--hidden'),
               cards[index].classList.contains('card--disabled'));
      }
      dots = dotsParent.children;
      initAup();
    }
  }

  function initAup() {
    var index, aup, checkAccept;

    aup = document.getElementById('aup');
    checkAccept = function() {
      if (aup.checked) {
        for (index = 0; index < dots.length; index++) {
          if (dots[index].classList.contains('dot--disabled')) {
            dots[index].classList.remove('dot--disabled');
            activateCard(index);
            return;
          }
        }
      }
      else {
        for (index = 0; index < cards.length; index++) {
          if (cards[index].classList.contains('card--disabled'))
            dots[index].classList.add('dot--disabled')
        }
      }
    };

    if (aup) {
      if (aup.addEventListener)
        aup.addEventListener('click', checkAccept, false);
      else if (aup.attachEvent)
        aup.attachEvent('click', checkAccept);
      checkAccept();
    }
  }
  
  function addDot(dotsParent, index, active, disabled) {
    var dot, activateFcn;

    // Click event listener
    activateFcn = activateCard.bind(dot, index);

    dot = document.createElement('div');
    dot.id = 'dot-' + index;

    // Apply styles
    dot.className = 'dot';
    if (active)
      dot.className += ' dot--active';
    else if (disabled)
      dot.className += ' dot--disabled';

    // Register click event listener
    if (dot.addEventListener)
      dot.addEventListener('click', activateFcn, false);
    else if (dot.attachEvent)
      dot.attachEvent('click', activateFcn);

    dot.appendChild(document.createElement('span'));

    dotsParent.appendChild(dot);
  }

  function activateCard(activeIndex) {
    var index;

    if (dots[activeIndex].classList.contains('dot--disabled'))
      return;
    
    for (index = 0; index < cards.length; index++) {
      if (index == activeIndex) {
        cards[index].classList.remove('card--hidden');
        dots[index].classList.add('dot--active');
      }
      else {
        cards[index].classList.add('card--hidden');
        dots[index].classList.remove('dot--active');
      }
    }
  }
});
