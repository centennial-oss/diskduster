#!/usr/bin/env bash
# Submits a zip, DMG or pkg to Apple's notary service and waits for the result. Prints the notary log and fails
# if Apple doesn't accept it. Needs APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID and the API key at
# ~/private_keys/AuthKey_<key id>.p8.
#
# Most submissions finish in minutes, but a team's first ones can take hours while Apple analyzes them, so the
# submission ID is printed right away (to look it up with `xcrun notarytool info <id>`) and the wait is long.
set -euo pipefail

FILE="${1:?usage: notarize.sh <file>}"
WAIT_TIMEOUT="${NOTARIZE_TIMEOUT:-3h}"
AUTH=(
  --key "$HOME/private_keys/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
  --key-id "$APP_STORE_CONNECT_KEY_ID"
  --issuer "$APP_STORE_CONNECT_ISSUER_ID"
)

echo "Submitting $FILE for notarization"
SUBMIT=$(xcrun notarytool submit "$FILE" "${AUTH[@]}" --output-format json)
echo "$SUBMIT"
SUBMISSION_ID=$(echo "$SUBMIT" | plutil -extract id raw -o - -)
echo "Submission ID: $SUBMISSION_ID. Waiting up to $WAIT_TIMEOUT for Apple's result."

# The final status decides the outcome, whatever `wait` exits with.
xcrun notarytool wait "$SUBMISSION_ID" "${AUTH[@]}" --timeout "$WAIT_TIMEOUT" || true

RESULT=$(xcrun notarytool info "$SUBMISSION_ID" "${AUTH[@]}" --output-format json)
echo "$RESULT"
STATUS=$(echo "$RESULT" | plutil -extract status raw -o - -)

if [ "$STATUS" = "In Progress" ]; then
  echo "::error::Gave up after $WAIT_TIMEOUT waiting for notarization of $FILE (submission $SUBMISSION_ID)"
  exit 1
fi
if [ "$STATUS" != "Accepted" ]; then
  echo "::error::Notarization of $FILE finished with status '$STATUS' (submission $SUBMISSION_ID)"
  echo "--- Notarization log ---"
  xcrun notarytool log "$SUBMISSION_ID" "${AUTH[@]}" || true
  echo "--- End log ---"
  exit 1
fi
echo "Notarization of $FILE accepted (submission $SUBMISSION_ID)"
