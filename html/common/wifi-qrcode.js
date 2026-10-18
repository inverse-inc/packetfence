/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

document.addEventListener('DOMContentLoaded', function () {
    const qrcode = document.getElementById('wifi-qrcode');
    if (!qrcode) {
        return;
    }
    // Special characters must be backslash escaped in the WIFI: URI scheme
    const escape = (value) => value.replace(/[\\;,:"]/g, (c) => '\\' + c);
    const ssid = escape(qrcode.getAttribute('data-ssid'));
    const psk = escape(qrcode.getAttribute('data-psk'));
    new QRCode(qrcode, `WIFI:T:WPA;S:${ssid};P:${psk};;`);
});
