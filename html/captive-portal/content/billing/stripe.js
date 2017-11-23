/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

$(function() {

  var varsEl = document.getElementById('variables');
  var vars = JSON.parse(variables.textContent || variables.innerHTML);
  
  function stripeResponseHandler(status, response) {
    var $form = $('#payment-form');
    
    if (response.error) {
      // Show the errors on the form
      $form.find('.payment-errors p').text(response.error.message);
      $form.find('.payment-errors').removeClass('hide');
    }
    else {
      // response contains id and card, which contains additional card details
      var token = response.id;
      // Insert the token into the form so it gets submitted to the server
      $form.append($('<input type="hidden" name="stripeToken" />').val(token));
      // and submit
      $form.get(0).submit();
    }
  }

  if (typeof Stripe !== 'undefined' ) {
    // This identifies your website in the createToken call below
    Stripe.setPublishableKey(vars.publishable_key);

    $('#payment-form').submit(function(event) {
      var $form = $(this);

      // Disable the submit button to prevent repeated clicks
      $form.find('button').prop('disabled', true);
      
      Stripe.card.createToken($form, stripeResponseHandler);

      // Prevent the form from submitting with the default action
      return false;
    });
  }
  else {
    var $form = $('#payment-form');
    $form.find('.payment-errors p').text('Unable to proceed with payment please contact your service provider');
    $form.find('.payment-errors').removeClass('hide');
  }

});
