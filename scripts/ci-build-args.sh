#!/usr/bin/env bash
# Prints `flutter build` version flags for CI. On a version tag (v1.2.3) the
# app's version comes from the tag, so releases don't depend on remembering to
# bump pubspec.yaml; the build number is the workflow run number, which only
# goes up. Off a tag it prints nothing and pubspec.yaml's version is used.
set -euo pipefail

if [[ "${GITHUB_REF_TYPE:-}" == "tag" && "${GITHUB_REF_NAME:-}" == v* ]]; then
  echo "--build-name=${GITHUB_REF_NAME#v} --build-number=${GITHUB_RUN_NUMBER}"
fi
