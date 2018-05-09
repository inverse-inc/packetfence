/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

$(function() {
  'use strict';

  var dots,
      dotsParent = document.getElementById('dots'),
      cards = $('.c-card');

  initButtons();
  initDots();
  initSvgSprite();
  initForm();

  function initButtons() {
    // Don't propagate mouse clicks on disabled buttons and links
    $('.c-btn').on('click', function(event) {
      if ($(this).hasClass('disabled')) {
        event.stopPropagation();
        return false;
      }
    });

    $('.form--single_submit').on('submit', function(e) {
      var $form = $(this);
      if ($form.data('submitted') === true) {
        e.preventDefault();
      }
      else {
        $form.data('submitted', true);
        $form.find('[type="submit"].btn').addClass('c-btn--disabled');
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
      $(this).closest('.o-box').addClass('hide');
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
               !$card.hasClass('c-card--hidden'),
               $card.hasClass('c-card--disabled'));
      }
      dots = dotsParent.children;
      initAup();
    }
  }

  function initSvgSprite() {
    $.get('/common/img/sprite.svg', function(data) {
      document.body.appendChild(data.documentElement);
    });
  }

  function initAup() {
    var $aup, checkAccept;

    $aup = $('#aup');
    checkAccept = function(event) {
      var $aup, index, activateIndex = false, $dot, $card;
      $aup = $('#aup');
      if ($aup.get(0) && (event || $aup.get(0).checked)) {
        // Since the checkbox is actually hidden, clicking the label always mark it as checked
        $aup.get(0).checked = true;
        // Visit the next disabled card
        for (index = 0; index < dots.length; index++) {
          $dot = $(dots[index]);
          if ($dot.hasClass('dot--disabled')) {
            $dot.removeClass('dot--disabled');
            activateIndex = index;
            break;
          }
        }
        if (activateIndex === false) {
          // .. or simply visit the next card
          activateIndex = parseInt($('.dot--active').get(0).id.substring(4)) + 1;
        }
        activateCard({data: activateIndex});
      }
      else {
        for (index = 0; index < cards.length; index++) {
          $card = $(cards[index]);
          if ($card.hasClass('c-card--disabled'))
            $(dots[index]).addClass('dot--disabled')
        }
      }
    };

    if ($aup) {
      $aup.on('click', checkAccept);
      checkAccept();
    }
  }
  
  function initForm() {
    var fieldsForm = false;
    $('form input, form select').each(function(f) {
      fieldsForm = $(this).closest('form');
      $(this).on('keyup change', function(e) {
        checkForm(fieldsForm);
      });
    });
    if (fieldsForm) checkForm(fieldsForm);

    // Add show/hide button to password field if the 'password-button' template is loaded
    $('input[type="password"]').each(function() {
      var $input = $(this);
      var $parent = $input.parent();
      var $tmp = $('[data-template="password-button"]').first();
      if ($tmp.length === 0) return; // template not found
      var $btn = $tmp.find('button').first();
      $input.after($tmp);
      $btn.before($input);

      $btn.click(function(event) {
        var change = "", label = "", state = "";
        if ($(this).data('state') === 'hide') {
          label = $(this).data('hide');
          state = 'show';
          change = "text";
        } else {
          label = $(this).data('show');
          state = 'hide';
          change = "password";
        }
        var rep = $("<input type='" + change + "' />")
            .attr("id", $input.attr("id"))
            .attr("name", $input.attr("name"))
            .val($input.val())
            .insertBefore($input);
        $input.remove();
        $input = rep;
        $(this).data('state', state);
        $(this).html(label);
        return false;
      });
    });
  }

  function checkForm($form) {
    var submitBtn = $form.find('[type="submit"]').first();
    if (submitBtn[0]) {
      var valid = true;
      $form.find('input:not([type=hidden]), select').each(function(f) {
        var minlength = $(this).attr('minlength') || 1;
        if (this.value.length < parseInt(minlength) ) {
          valid = false;
          return false;
        }
      });
      submitBtn.prop('disabled', !valid);
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
        $card.removeClass('c-card--hidden');
        $dot.addClass('dot--active');
      } else {
        $card.addClass('c-card--hidden');
        $dot.removeClass('dot--active');
      }
    }

    $('html, body').animate({ scrollTop: '0px' });
  }
});
