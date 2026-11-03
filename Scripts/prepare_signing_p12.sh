#!/bin/bash
set -euo pipefail
umask 077

# Keep password values out of OpenSSL command arguments
: "${DISTRIBUTION_P12_PASSWORD:?Missing source PKCS12 password}"
: "${P12_IMPORT_PASSWORD:?Missing temporary PKCS12 password}"
SOURCE_P12=${1:?Missing source PKCS12 path}
OUTPUT_P12=${2:?Missing output PKCS12 path}
WORK_DIR=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/plaza-p12.XXXXXX")
trap 'rm -rf "$WORK_DIR"' EXIT

# Retry with the legacy provider for older RC2-encrypted exports
legacy_input=
if ! openssl pkcs12 -in "$SOURCE_P12" -passin env:DISTRIBUTION_P12_PASSWORD \
    -noout >"$WORK_DIR/verify.log" 2>&1; then
    legacy_input=yes
    if ! openssl pkcs12 -legacy -in "$SOURCE_P12" -passin env:DISTRIBUTION_P12_PASSWORD \
        -noout >"$WORK_DIR/verify.log" 2>&1; then
        echo 'OpenSSL cannot verify the source PKCS12. Check the uploaded file/password pair, file integrity and supported algorithms; Keychain import has not run.' >&2
        exit 1
    fi
fi

echo 'Source PKCS12 verified by OpenSSL; preparing a Keychain-compatible container.'
# The intermediate private key stays encrypted, inside a private temporary directory
openssl pkcs12 ${legacy_input:+-legacy} -in "$SOURCE_P12" \
    -passin env:DISTRIBUTION_P12_PASSWORD -passout env:P12_IMPORT_PASSWORD \
    -aes256 -out "$WORK_DIR/identity.pem"
openssl pkcs12 -export -in "$WORK_DIR/identity.pem" \
    -passin env:P12_IMPORT_PASSWORD -passout env:P12_IMPORT_PASSWORD \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
    -out "$OUTPUT_P12"
