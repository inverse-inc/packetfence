/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

$(function() {
  'use strict';

  setInterval(function(){
    $.ajax({
      url : getPortalUrl('/sponsor/check'),
      method : 'POST',
    }).done(function(){
      window.location = getPortalUrl("/signup");
    });
  }, 5000);
});
