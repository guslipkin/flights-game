#!/usr/bin/env bash
# Packages the built macOS app as a disk image whose window is laid out like
# the app icon: the app on the green dot, Applications (tinted pink) on the
# pink one. macOS only. Needs dmgbuild (`pip install dmgbuild`).
# Usage: scripts/make-dmg.sh path/to/Flights.app out.dmg
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$1"
OUT="$2"
ART="$(mktemp -d)"
trap 'rm -rf "${ART}"' EXIT

swift "${ROOT}/scripts/dmg-art.swift" "${ART}"
rm -f "${OUT}"
dmgbuild -s "${ROOT}/scripts/dmg-settings.py" \
  -D app="${APP}" -D art="${ART}" \
  Flights "${OUT}"
