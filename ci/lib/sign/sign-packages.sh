#!/bin/bash
set -o nounset -o pipefail -o errexit

# Sign the packages found in RESULT_DIR with the GPG key stored in Psono.
# Required env: GPG_KEY_FINGERPRINT, GPG_USER_ID, PSONO_API_KEY_ID,
# PSONO_API_KEY_SECRET_KEY, PSONO_GPG_PRIVATE_KEY_SECRET_ID
# SIGN_RPM=no skips RPMs (and the check that at least one was found).

RESULT_DIR=${RESULT_DIR:-result}
SIGN_RPM=${SIGN_RPM:-yes}

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

rpm_count=0
if [ "$SIGN_RPM" = "yes" ]; then
  echo "=== Sign RPM packages ==="
  # Import the public key into RPM's keyring for verification
  gpg --batch --yes --output /tmp/pubkey.pub --armor --export "$GPG_USER_ID"
  rpm --import /tmp/pubkey.pub
  for rpm_file in $(find "$RESULT_DIR" -type f -name '*.rpm' ! -name '*.src.rpm'); do
    echo "Signing: $rpm_file"
    rpm --define "_gpg_name $GPG_USER_ID" --define '_signature gpg' --addsign "$rpm_file"
    rpm --checksig "$rpm_file"
    rpm_count=$((rpm_count + 1))
  done
  echo "Signed $rpm_count RPM package(s)"
  if [ "$rpm_count" -eq 0 ]; then
    echo "ERROR: no .rpm files found in $RESULT_DIR" >&2
    exit 1
  fi
fi

echo "=== Signing complete: $deb_count DEB + $rpm_count RPM ==="
