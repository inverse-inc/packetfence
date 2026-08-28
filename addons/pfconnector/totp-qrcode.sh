#!/bin/bash

# Re-displays the QR code enrolling the TOTP seed that gates remote terminal
# access, from the otpauth URL persisted in conf/terminal_totp. The seed never
# leaves the host: this must be run locally on the connector.

TOTP_FILE="${PFCONNECTOR_TERMINAL_TOTP_FILE:-/usr/local/pfconnector-remote/conf/terminal_totp}"

if [ ! -s "$TOTP_FILE" ]; then
  echo "No TOTP seed found in $TOTP_FILE." >&2
  echo "It is generated when the packetfence-pfconnector-remote package is installed," >&2
  echo "or by the pfconnector-client on its first start. Start the connector service" >&2
  echo "and run this again." >&2
  exit 1
fi

OTPAUTH_URL=$(head -n 1 "$TOTP_FILE" | tr -d '[:space:]')

case "$OTPAUTH_URL" in
  otpauth://*) ;;
  *)
    echo "$TOTP_FILE does not contain an otpauth:// URL." >&2
    echo "To rotate the seed, delete the file and restart the packetfence-pfconnector-remote-combined service." >&2
    exit 1
    ;;
esac

echo "=================================================================="
echo "Opening a remote terminal on this connector from the PacketFence"
echo "admin interface requires a TOTP code. Enroll this connector in an"
echo "authenticator app:"
echo ""
if command -v qrencode > /dev/null 2>&1; then
  qrencode -t ansiutf8 "$OTPAUTH_URL"
  echo ""
else
  echo "(install the qrencode package to display this as a QR code)"
fi
echo "otpauth URL (kept in $TOTP_FILE):"
echo "$OTPAUTH_URL"
echo "=================================================================="
