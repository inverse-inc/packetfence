/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */


$(function() {

  var varsEl = document.getElementById('variables');
  var vars = JSON.parse(variables.textContent || variables.innerHTML);

  var stripe = Stripe(vars.publishable_key);
  var elements = stripe.elements();
  var card = elements.create("card");
  card.mount("#card-element");

  // Create a token when the form is submitted.
  var form = document.getElementById('payment-form');
  form.addEventListener('submit', function(e) {
    e.preventDefault();
    createToken();
  });

  function stripeTokenHandler(token) {
    // Insert the token ID into the form so it gets submitted to the server
    var form = document.getElementById('payment-form');
    var hiddenInput = document.createElement('input');
    hiddenInput.setAttribute('type', 'hidden');
    hiddenInput.setAttribute('name', 'stripeToken');
    hiddenInput.setAttribute('value', token.id);
    form.appendChild(hiddenInput);

    // Submit the form
    form.submit();
  }

  function createToken() {
    stripe.createToken(card).then(function(result) {
      if (result.error) {
        // Inform the user if there was an error
        var errorElement = document.getElementById('card-errors');
        errorElement.textContent = result.error.message;
      } else {
        // Send the token to your server
        stripeTokenHandler(result.token);
      }
    });
  };

});
