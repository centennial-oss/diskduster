#!/usr/bin/env bash
# Submits a zip, DMG or pkg to Apple's notary service and waits for the result. Prints the notary log and fails
# if Apple doesn't accept it. Needs APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID and the API key at
# ~/private_keys/AuthKey_<key id>.p8.
set -euo pipefail

FILE="${1:?usage: notarize.sh <file>}"
AUTH=(
  --key "$HOME/private_keys/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
  --key-id "$APP_STORE_CONNECT_KEY_ID"
  --issuer "$APP_STORE_CONNECT_ISSUER_ID"
)

echo "Submitting $FILE for notarization"
RESULT=$(xcrun notarytool submit "$FILE" "${AUTH[@]}" --wait --timeout 30m --output-format json)
echo "$RESULT"
SUBMISSION_ID=$(echo "$RESULT" | plutil -extract id raw -o - -)
STATUS=$(echo "$RESULT" | plutil -extract status raw -o - -)

if [ "$STATUS" != "Accepted" ]; then
  echo "::error::Notarization of $FILE finished with status '$STATUS' (submission $SUBMISSION_ID)"
  echo "--- Notarization log ---"
  xcrun notarytool log "$SUBMISSION_ID" "${AUTH[@]}" || true
  echo "--- End log ---"
  exit 1
fi
echo "Notarization of $FILE accepted (submission $SUBMISSION_ID)"
