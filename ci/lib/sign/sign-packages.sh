#!/bin/bash
set -o nounset -o pipefail -o errexit

# Sign the packages found in RESULT_DIR with the GPG key stored in Psono.
# Required env: GPG_KEY_FINGERPRINT, GPG_USER_ID, PSONO_API_KEY_ID,
# PSONO_API_KEY_SECRET_KEY, PSONO_GPG_PRIVATE_KEY_SECRET_ID

RESULT_DIR=${RESULT_DIR:-result}

echo "=== Import GPG private key from Psono ==="
python3 addons/packetfence-perl/psono.py \
  --api_key_id="$PSONO_API_KEY_ID" \
  --api_key_secret_key="$PSONO_API_KEY_SECRET_KEY" \
  --secret_id="$PSONO_GPG_PRIVATE_KEY_SECRET_ID" \
  --return_value=password_notes \
| gpg --batch --pinentry-mode loopback --import
echo "GPG key imported successfully"
gpg --list-keys

echo "=== Sign Debian packages ==="
deb_count=0
for deb in $(find "$RESULT_DIR" -type f -name '*.deb'); do
  echo "Signing: $deb"
  dpkg-sig -k "$GPG_KEY_FINGERPRINT" --sign builder "$deb"
  dpkg-sig --list "$deb"
  deb_count=$((deb_count + 1))
done
echo "Signed $deb_count Debian package(s)"
if [ "$deb_count" -eq 0 ]; then
  echo "ERROR: no .deb files found in $RESULT_DIR" >&2
  exit 1
fi

echo "=== Regenerate .changes file checksums after signing ==="
for changes_file in $(find "$RESULT_DIR" -type f -name '*.changes'); do
  echo "Updating checksums in: $changes_file"
  python3 ci/lib/update-changes-checksums.py "$changes_file"
done

echo "=== Signing complete: $deb_count DEB ==="
