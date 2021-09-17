/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
$(function(){
    jQuery('#qrcode').qrcode("otpauth://totp/[% username %].packetfence?secret=[% otp %]");
});
