/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

  var varsEl = $('#variables');
  var vars = JSON.parse(varsEl.html());

  function sendPaymentDataToAnet() {
      var secureData = {}; authData = {}; cardData = {};

      // Extract the card number, expiration date, and card code.
      cardData.cardNumber = document.getElementById("cardNumberID").value;
      cardData.month = document.getElementById("monthID").value;
      cardData.year = document.getElementById("yearID").value;
      cardData.cardCode = document.getElementById("cardCodeID").value;
      cardData.fullName = document.getElementById("name").value;
      secureData.cardData = cardData;

      // The Authorize.Net Client Key is used in place of the traditional Transaction Key. The Transaction Key
      // is a shared secret and must never be exposed. The Client Key is a public key suitable for use where
      // someone outside the merchant might see it.
      authData.clientKey = vars.public_client_key;
      authData.apiLoginID = vars.api_login_id;
      secureData.authData = authData;

      // Pass the card number and expiration date to Accept.js for submission to Authorize.Net.
      Accept.dispatchData(secureData, responseHandler);

      // Process the response from Authorize.Net to retrieve the two elements of the payment nonce.
      // If the data looks correct, record the OpaqueData to the console and call the transaction processing function.
      function responseHandler(response) {
          if (response.messages.resultCode === "Error") {
              for (var i = 0; i < response.messages.message.length; i++) {
                  console.log(response.messages.message[i].code + ": " + response.messages.message[i].text);
              }
              var $form = $('#payment-form');
              $form.find('.payment-errors p').text('Unable to proceed with payment please contact your service provider');
              $form.find('.payment-errors').removeClass('hide');
          } else {
              processTransaction(response.opaqueData);
          }
      }
  }


  function processTransaction(responseData) {
      //create the form and attach to the document
      var transactionForm = document.createElement("form");
      transactionForm.setAttribute("method", "post");
      transactionForm.setAttribute("action", "/billing/" + vars.id + "/verify");
      document.body.appendChild(transactionForm);

      //create form "input" elements corresponding to each parameter
      dataDesc = document.createElement("input")
      dataDesc.hidden = true;
      dataDesc.value = responseData.dataDescriptor;
      dataDesc.name = "dataDesc";
      transactionForm.appendChild(dataDesc);

      dataValue = document.createElement("input")
      dataValue.hidden = true;
      dataValue.value = responseData.dataValue;
      dataValue.name = "dataValue";
      transactionForm.appendChild(dataValue);

      //submit the new form
      transactionForm.submit();
  }

