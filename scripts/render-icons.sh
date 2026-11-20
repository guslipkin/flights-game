#!/usr/bin/env bash
# Regenerates every app icon from assets/icon/flights_icon.svg, the single
# source of truth. Run after editing the SVG, then commit the results.
# macOS only: rendering uses AppKit (scripts/svg2png.swift), the one SVG
# renderer here that keeps transparency, which the Android and macOS
# layers need.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICON_DIR="${ROOT}/assets/icon"
SRC="${ICON_DIR}/flights_icon.svg"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

render() { swift "${ROOT}/scripts/svg2png.swift" "$1" "$2" 1024; }

# The drawing without its background square.
sed '/<rect /d; /<\/svg>/d; /<svg /d' "${SRC}" > "${TMP}/body.svg"

# iOS and legacy Android: the full square. The platforms apply their own
# rounded mask.
render "${SRC}" "${ICON_DIR}/flights_icon.png"

# Android adaptive foreground: transparent, shrunk so the wingtip dots stay
# inside the central circle that every launcher mask keeps (the middle 66%).
{
  echo '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
  echo '<g transform="translate(512 512) scale(0.72) translate(-512 -532)">'
  cat "${TMP}/body.svg"
  echo '</g></svg>'
} > "${TMP}/foreground.svg"
render "${TMP}/foreground.svg" "${ICON_DIR}/flights_icon_foreground.png"

# macOS: Apple's icon grid puts an 824pt rounded tile in the 1024 canvas,
# with transparent margins, so the icon matches the size of other apps'.
{
  echo '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
  echo '<rect x="100" y="100" width="824" height="824" rx="185" fill="#0D1117"/>'
  echo '<g transform="translate(100 100) scale(0.8046875)">'
  cat "${TMP}/body.svg"
  echo '</g></svg>'
} > "${TMP}/macos.svg"
render "${TMP}/macos.svg" "${ICON_DIR}/flights_icon_macos.png"

cd "${ROOT}"
flutter pub get >/dev/null
dart run flutter_launcher_icons
