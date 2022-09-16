/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

document.addEventListener('DOMContentLoaded', function () {
    const qrcode = document.getElementById('qrcode');
    const otp = qrcode.getAttribute('data-otp');
    const username = qrcode.getAttribute('data-username');
    new QRCode(qrcode, `otpauth://totp/${username}.packetfence?secret=${otp}`);
});
