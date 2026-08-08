#!/usr/bin/env bash
# Fetches Inter into assets/fonts/.
#
# Inter is not committed: it keeps the repo small and the licence clean.
# The build fails without it ON PURPOSE — silently falling back to a different
# typeface would change every screen in the design system.
#
# Inter is SIL Open Font Licence 1.1, so shipping it inside the app is fine.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/assets/fonts"
mkdir -p "$DIR"

BASE="https://github.com/rsms/inter/raw/master/docs/font-files"

fetch() {
  local file="$1"
  if [ -f "$DIR/$file" ]; then
    echo "  have  $file"
    return
  fi
  echo "  get   $file"
  curl -fsSL "$BASE/$file" -o "$DIR/$file"
}

echo "Fetching Inter into assets/fonts ..."
fetch Inter-Regular.ttf
fetch Inter-Medium.ttf
fetch Inter-SemiBold.ttf
fetch Inter-Bold.ttf

echo
echo "Done. Now run:  flutter pub get && flutter run"
