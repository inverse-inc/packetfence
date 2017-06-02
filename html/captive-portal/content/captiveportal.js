/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

$(function() {
  'use strict';

  var dots,
      dotsParent = document.getElementById('dots'),
      cards = $('.card');

  initButtons();
  initDots();
  initSvgSprite();

  function initButtons() {
    // Don't propagate mouse clicks on disabled buttons and links
    $('.btn').on('click', function(event) {
      if ($(this).hasClass('disabled')) {
        event.stopPropagation();
        return false;
      }
    });

    // Show overlapping box with id defined from the data-box-show attribute
    $('.js-box-show').on('click', function(event) {
      var boxId = $(this).attr('data-box-show');
      $('#'+boxId).removeClass('hide');
      event.stopPropagation();
      return false;
    });

    // Hide box container
    $('.js-box-hide').on('click', function(event) {
      $(this).closest('.box').addClass('hide');
      event.stopPropagation();
      return false;
    });
  }

  function initDots() {
    var index, $card;

    if (cards.length > 1) {
      for (index = 0; index < cards.length; index++) {
        $card = $(cards[index]);
        cards[index].id = 'card-' + index;
        addDot(dotsParent,
               index,
               !$card.hasClass('card--hidden'),
               $card.hasClass('card--disabled'));
      }
      dots = dotsParent.children;
      initAup();
    }
  }

  function initSvgSprite() {
    $.get('/common/img/sprite.svg', function(data) {
      var div = document.createElement("div");
      div.innerHTML = new XMLSerializer().serializeToString(data.documentElement);
      document.body.insertBefore(div, document.body.childNodes[0]);
    });
  }

  function initAup() {
    var $aup, checkAccept;

    $aup = $('#aup');
    checkAccept = function() {
      var $aup, index, $dot, $card;
      $aup = $('#aup');
      if ($aup.get(0) && $aup.get(0).checked) {
        for (index = 0; index < dots.length; index++) {
          $dot = $(dots[index]);
          if ($dot.hasClass('dot--disabled')) {
            $dot.removeClass('dot--disabled');
            activateCard({data: index});
            return;
          }
        }
      }
      else {
        for (index = 0; index < cards.length; index++) {
          $card = $(cards[index]);
          if ($card.hasClass('card--disabled'))
            $(dots[index]).addClass('dot--disabled')
        }
      }
    };

    if ($aup) {
      $aup.on('click', checkAccept);
      checkAccept();
    }
  }
  
  function addDot(dotsParent, index, active, disabled) {
    var dot;

    dot = document.createElement('div');
    dot.id = 'dot-' + index;

    // Apply styles
    dot.className = 'dot';
    if (active)
      dot.className += ' dot--active';
    else if (disabled)
      dot.className += ' dot--disabled';

    dot.appendChild(document.createElement('div'));

    // Register click event listener
    $(dot).on('click', index, activateCard);

    dotsParent.appendChild(dot);
  }

  function activateCard(event) {
    var activeIndex, index, $card, $dot;

    activeIndex = event.data;

    if ($(dots[activeIndex]).hasClass('dot--disabled'))
      return;
    
    for (index = 0; index < cards.length; index++) {
      $card = $(cards[index]);
      $dot = $(dots[index]);
      if (index == activeIndex) {
        $card.removeClass('card--hidden');
        $dot.addClass('dot--active');
      }
      else {
        $card.addClass('card--hidden');
        $dot.removeClass('dot--active');
      }
    }

    $('html, body').animate({ scrollTop: '0px' });
  }
});
