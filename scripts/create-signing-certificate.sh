#!/usr/bin/env bash
# Creates the self-signed code signing certificate releases are signed with.
#
# The certificate exists to give the app a stable designated requirement. An
# ad-hoc signature's requirement is a bare code hash that changes on every
# rebuild, which invalidates the keychain ACL guarding the stored token, so
# macOS re-asks for permission after every update. A certificate leaf hash does
# not change, so the grant survives. Notarisation is unaffected either way, and
# is not the point of this.
#
# Run once. The exported key is printed as base64 for the SIGNING_CERTIFICATE_P12
# repository secret, which is the only copy that outlives this machine.
#
# Usage: scripts/create-signing-certificate.sh [common-name]

set -euo pipefail

COMMON_NAME="${1:-GitHub Notifications Signing}"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
WORKING_DIRECTORY="$(mktemp -d)"
IMPORTED=false
COMPLETED=false

## Leaves nothing half-installed: an identity in the keychain without the
## printed secrets is unusable, and would block the re-run that fixes it.
clean_up() {
  rm -rf "${WORKING_DIRECTORY}"

  if [[ "${IMPORTED}" == true && "${COMPLETED}" == false ]]; then
    echo "Rolling back the partially imported identity." >&2
    security delete-identity -c "${COMMON_NAME}" "${KEYCHAIN}" >/dev/null 2>&1 || true
  fi
}

trap clean_up EXIT

# The export below needs OpenSSL 3's -legacy flag, which the LibreSSL shipped at
# /usr/bin/openssl does not have.
if ! openssl version | grep -q "^OpenSSL 3"; then
  echo "error: OpenSSL 3 is required, found '$(openssl version)'." >&2
  echo "       Install it (brew install openssl@3) and put it ahead of LibreSSL on PATH." >&2
  exit 1
fi

if security find-certificate -c "${COMMON_NAME}" "${KEYCHAIN}" >/dev/null 2>&1; then
  echo "error: a certificate named '${COMMON_NAME}' is already in the login keychain." >&2
  echo "       Remove it first, then re-run to rotate:" >&2
  echo "       security delete-identity -c \"${COMMON_NAME}\" \"${KEYCHAIN}\"" >&2
  exit 1
fi

PASSWORD="$(openssl rand -base64 24)"

cat >"${WORKING_DIRECTORY}/openssl.cnf" <<CONFIGURATION
[ req ]
distinguished_name = subject
x509_extensions    = extensions
prompt             = no

[ subject ]
CN = ${COMMON_NAME}

[ extensions ]
basicConstraints = critical,CA:false
keyUsage         = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CONFIGURATION

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -config "${WORKING_DIRECTORY}/openssl.cnf" \
  -keyout "${WORKING_DIRECTORY}/key.pem" \
  -out "${WORKING_DIRECTORY}/certificate.pem" 2>/dev/null

# -legacy: the keychain cannot read PKCS#12 files encrypted with OpenSSL 3's
# defaults, and fails with a bare "MAC verification failed" if you let it.
openssl pkcs12 -export -legacy \
  -inkey "${WORKING_DIRECTORY}/key.pem" \
  -in "${WORKING_DIRECTORY}/certificate.pem" \
  -name "${COMMON_NAME}" \
  -passout "pass:${PASSWORD}" \
  -out "${WORKING_DIRECTORY}/certificate.p12"

# -T /usr/bin/codesign lets codesign use the key without a prompt per build.
security import "${WORKING_DIRECTORY}/certificate.p12" \
  -k "${KEYCHAIN}" \
  -P "${PASSWORD}" \
  -T /usr/bin/codesign \
  -f pkcs12 >/dev/null

IMPORTED=true

# Trusted in the user domain rather than the system one: codesign refuses to
# build a chain to an untrusted root, and the user domain needs no administrator
# rights. trustRoot, not trustAsRoot, because the certificate is its own root.
security add-trusted-cert -r trustRoot -p codeSign -k "${KEYCHAIN}" \
  "${WORKING_DIRECTORY}/certificate.pem"

# Without a partition list entry, codesign asks for the keychain password on
# every build no matter what -T granted at import time. It needs the login
# password, which is only worth asking for when there is a terminal to ask on:
# without it the first build prompts once, and Always Allow settles it.
PARTITION_LIST_COMMAND="security set-key-partition-list -S apple-tool:,apple:,codesign: -s -l \"${COMMON_NAME}\" \"${KEYCHAIN}\""

if [[ -n "${LOGIN_KEYCHAIN_PASSWORD:-}" ]]; then
  security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s -l "${COMMON_NAME}" \
    -k "${LOGIN_KEYCHAIN_PASSWORD}" \
    "${KEYCHAIN}" >/dev/null
elif [[ -t 0 ]]; then
  read -rsp "Login keychain password (lets codesign use the key unattended): " LOGIN_KEYCHAIN_PASSWORD
  echo

  security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s -l "${COMMON_NAME}" \
    -k "${LOGIN_KEYCHAIN_PASSWORD}" \
    "${KEYCHAIN}" >/dev/null
else
  PARTITION_LIST_PENDING=true
fi

COMPLETED=true

echo
echo "Imported '${COMMON_NAME}' into the login keychain."
echo
echo "Build locally with:"
echo "  SIGNING_IDENTITY=\"${COMMON_NAME}\" scripts/build.sh release"
echo

if [[ "${PARTITION_LIST_PENDING:-false}" == true ]]; then
  echo "The first build will ask for the keychain password once. Choose Always Allow,"
  echo "or run this in a terminal to settle it now:"
  echo "  ${PARTITION_LIST_COMMAND}"
  echo
fi
echo "Store these as repository secrets. This is the only copy of the private key:"
echo
echo "SIGNING_CERTIFICATE_PASSWORD:"
echo "${PASSWORD}"
echo
echo "SIGNING_CERTIFICATE_P12:"
base64 <"${WORKING_DIRECTORY}/certificate.p12"
echo
echo "Rotating later resets keychain access and notification permission for every"
echo "installed copy, because the designated requirement changes. See the README."
