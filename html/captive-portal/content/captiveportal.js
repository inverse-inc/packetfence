/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

document.addEventListener('DOMContentLoaded', function () {
  'use strict';

  var dots,
      dotsParent = document.getElementById('dots'),
      cards = Array.prototype.slice.call(document.getElementsByClassName('c-card'));

  initButtons();
  initDots();
  initSvgSprite();
  initForm();

  function initButtons() {
    // Don't propagate mouse clicks on disabled buttons and links
    Array.prototype.slice.call(document.getElementsByClassName('c-btn'))
      .forEach(function (node) {
        node.addEventListener('click', function (event) {
          if (node.classList.contains('disabled') || node.getAttribute('disabled')) {
            event.stopPropagation();
            return false;
          }
        });
      });

    Array.prototype.slice.call(document.getElementsByClassName('form--single_submit'))
      .forEach(function (node) {
        node.addEventListener('submit', function (event) {
          if (node.dataset.submitted === true) {
            event.preventDefault();
          }
          else {
            node.dataset.submitted = true;
            Array.prototype.slice.call(node.querySelectorAll('[type="submit"]'))
              .forEach(function (btn) {
                btn.classList.add('c-btn--disabled');
              })
          }
        });
      });

    // Show overlapping box with id defined from the data-box-show attribute
    Array.prototype.slice.call(document.getElementsByClassName('js-box-show'))
      .forEach(function (node) {
        node.addEventListener('click', function (event) {
          var boxId = node.getAttribute('data-box-show');
          document.getElementById(boxId).classList.remove('hide');
          event.stopPropagation();
          return false;
        })
      })

    // Hide box container
    Array.prototype.slice.call(document.getElementsByClassName('js-box-hide'))
      .forEach(function (node) {
        node.addEventListener('click', function (event) {
          event.stopPropagation();
          return false;
          closest(node, function (el) { return el.classList.contains('o-box'); }).classList.add('hide');
        })
      })
  }

  function initDots() {
    var index, card;

    if (cards.length > 1) {
      for (index = 0; index < cards.length; index++) {
        card = cards[index];
        cards[index].dataset.id = 'card-' + index;
        addDot(dotsParent,
               index,
               !card.classList.contains('c-card--hidden'),
               card.classList.contains('c-card--disabled'));
      }
      dots = dotsParent.children;
      initAup();
    }
  }

  function initSvgSprite() {
    ajax(
      'get',
      './common/img/sprite.svg',
      null,
      function (data) {
        document.body.appendChild(data.responseXML.documentElement);
      }
    );
  }

  function initAup() {
    var aup, checkAccept;

    aup = document.getElementById('aup');
    checkAccept = function (event) {
      var aup, index, activateIndex = false, dot, card;
      aup = document.getElementById('aup');
      if (aup && (event || aup.checked)) {
        // Since the checkbox is actually hidden, clicking the label always mark it as checked
        aup.checked = true;
        // Visit the next disabled card
        for (index = 0; index < dots.length; index++) {
          dot = dots[index];
          if (dot.classList.contains('dot--disabled')) {
            dot.classList.remove('dot--disabled');
            activateIndex = index;
            break;
          }
        }
        if (activateIndex === false) {
          // .. or simply visit the next card
          var id = document.getElementsByClassName('dot-active')[0].dataset.id;
          activateIndex = parseInt(id.substring(4)) + 1;
        }
        activateCard({data: activateIndex});
      }
      else {
        for (index = 0; index < cards.length; index++) {
          card = cards[index];
          if (card.classList.contains('c-card--disabled'))
            dots[index].classList.add('dot--disabled');
        }
      }
    };

    if (aup) {
      aup.addEventListener('click', checkAccept);
      checkAccept();
    }
  }

  function initForm() {
    var form = false;

    Array.prototype.slice.call(document.querySelectorAll('form input, form select'))
      .forEach(function (input) {
        form = closest(input, function (el) { return el.tagName.toLowerCase() === 'form' });
        var inputHandler = function () { checkForm(form); };
        input.addEventListener('keyup', inputHandler);
        input.addEventListener('change', inputHandler);
      });
    if (form)
      checkForm(form);

    // Add show/hide button to password field if the 'password-button' template is loaded
    Array.prototype.slice.call(document.querySelectorAll('input[type="password"]')).forEach(function (input) {
      var parent = input.parentNode;
      var template = document.querySelector('[data-template="password-button"]');
      if (!template)
        return; // template not found
      var button = template.querySelector('.c-btn');
      parent.insertAfter(template, input);
      parent.insertBefore(input, button);
      button.addEventListener('click', function (event) {
        var type = '', label = '', state = '';
        if (button.dataset.state === 'hide') {
          label = button.dataset.hide;
          state = 'show';
          type = 'text';
        }
        else {
          label = button.dataset.show;
          state = 'hide';
          type = 'password';
        }
        var rep = document.createElement('input');
        rep.setAttribute('type', type);
        rep.setAttribute('id', input.getAttribute('id'));
        rep.setAttribute('name', input.getAttribute('name'));
        rep.setAttribute('value', input.getAttribute('value'));
        parent.insertBefore(rep, input);
        parent.removeChild(input);
        button.dataset.state = state;
        button.innerHTML = label;
        return false;
      });
    });
  }

  function checkForm(form) {
    var submitBtn = form.querySelector('[type="submit"]');
    if (submitBtn) {
      var valid = true;
      Array.prototype.slice.call(form.querySelectorAll('input:not([type=hidden]), select'))
        .forEach(function (input) {
          var minLength = input.getAttribute('minlength') || 1;
          if (input.getAttribute('value').length < parseInt(minLength)) {
            valid = false;
            return false;
          }
        })
      submitBtn.setAttribute('disabled', !valid);
    }
  }

  function addDot(parent, index, active, disabled) {
    var dot = document.createElement('div');
    dot.dataset.id = 'dot-' + index;

    // Apply styles
    dot.classList.add('dot');
    if (active)
      dot.classList.add('dot--active');
    else if (disabled)
      dot.classList.add('dot--disabled');

    dot.appendChild(document.createElement('div'));

    // Register click event listener
    dot.addEventListener('click', function () { activateCard({ data: index }) });

    parent.appendChild(dot);
  }

  function activateCard(event) {
    var activeIndex, index, card, dot;

    activeIndex = event.data;

    if (dots[activeIndex].classList.contains('dot--disabled'))
      return;

    for (index = 0; index < cards.length; index++) {
      card = cards[index];
      dot = dots[index];
      if (index == activeIndex) {
        card.classList.remove('c-card--hidden');
        dot.classList.add('dot--active');
      }
      else {
        card.classList.add('c-card--hidden');
        dot.classList.remove('dot--active');
      }
    }

    window.scrollTo(0, 0);
  }
});
