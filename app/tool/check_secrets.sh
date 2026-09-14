#!/usr/bin/env bash
#
# `F-158` — no secrets in the tree, ever.
#
# This is `docs/30` §1 step 2, lifted out of the markdown and into CI. It was a
# snippet you were meant to remember to paste, which means it ran on the days
# somebody remembered.
#
# ## Why the pattern insists on a key BODY
#
# The first version matched the prefix alone — `rzp_live_`, `sk_test_`. That
# matched every line in the repository that merely *describes* the format:
# two research documents, a screen spec, a test fixture, and the copy of the
# pattern inside `docs/30` itself. So it printed "SECRET FOUND - STOP" on every
# run, and the only way to use it was to skim the hits and move on — which is
# precisely the habit that lets a real key through.
#
# Requiring twelve or more key characters after the prefix removes every one of
# those without weakening anything: a real Razorpay key is the prefix plus
# fourteen alphanumerics, and `rzp_live_Lq7…` in a diagram is not.
#
# Documentation is deliberately still scanned. A key pasted into a markdown
# file is just as public as one pasted into Dart.
set -uo pipefail
cd "$(dirname "$0")/.."

PATTERN='(rzp_(live|test)_|sk_live_|sk_test_)[A-Za-z0-9]{12,}'
PATTERN+='|AIza[0-9A-Za-z_-]{35}'
PATTERN+='|-----BEGIN [A-Z ]*PRIVATE KEY'

# `..` so this covers docs/ and the repository root too, not only app/.
if grep -rIn --exclude-dir=.git --exclude-dir=build --exclude-dir=.dart_tool \
     -E "$PATTERN" .. ; then
  echo
  echo "SECRET FOUND — STOP."
  echo "Nothing above may be committed. A Razorpay secret inside an APK is"
  echo "public the moment the APK ships. Keys belong in GitHub Actions"
  echo "Secrets, or on the user's own device — never in this repository."
  exit 1
fi

echo "NO SECRETS"
