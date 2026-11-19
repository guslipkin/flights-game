#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JOTTO_DATA_DIR="${1:-${REPO_ROOT}/../jotto-cli/data}"
ASSETS_DIR="${REPO_ROOT}/app/src/main/assets"

if [[ ! -d "${JOTTO_DATA_DIR}" ]]; then
  echo "Error: jotto-cli data directory not found at '${JOTTO_DATA_DIR}'" >&2
  exit 1
fi

mkdir -p "${ASSETS_DIR}"
cp -v "${JOTTO_DATA_DIR}/flights.tsv" "${ASSETS_DIR}/flights.tsv"
cp -v "${JOTTO_DATA_DIR}/coastlines.bin" "${ASSETS_DIR}/coastlines.bin"

echo "Synced flights.tsv and coastlines.bin to ${ASSETS_DIR}"
