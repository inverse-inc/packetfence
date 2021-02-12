/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

$(function() {
  'use strict';

  $('#test').on('click', function() {
    $('#testFailure').addClass('hide');
    $.ajax({
      url: 'https://packetfence.org/ssl-test/',
      method: 'GET'
    })
      .done(function() {
        window.location.href = "/captive-portal?next=next";
      })
      .fail(function() {
        $('#testFailure').removeClass('hide');
      });
    return false;
  });

});

