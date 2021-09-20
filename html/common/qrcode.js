/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
$(function(){
    const el = jQuery('#qrcode')
    const otp = el.attr('data-otp')
    const username = el.attr('data-username')
    el.qrcode(`otpauth://totp/${username}.packetfence?secret=${otp}`);
});
