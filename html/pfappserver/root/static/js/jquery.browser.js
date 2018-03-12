/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 2 -*- */

var userAgent = navigator.userAgent.toLowerCase();

// Figure out what browser is being used
// See https://code.jquery.com/jquery-1.3.js
jQuery.browser = {
  version: (userAgent.match( /.+(?:rv|it|ra|ie)[\/: ]([\d.]+)/ ) || [0,'0'])[1],
  safari: /webkit/.test( userAgent ),
  opera: /opera/.test( userAgent ),
  msie: /msie/.test( userAgent ) && !/opera/.test( userAgent ),
  mozilla: /mozilla/.test( userAgent ) && !/(compatible|webkit)/.test( userAgent )
};
