#!/usr/bin/env bash
# File: hedgedoc-kubernetes/.github/scripts/bump-chart-version.sh
# ─────────────────────────────────────────────────────────────────────────────
# Called by Renovate's postUpgradeTasks when it updates the HedgeDoc image tag
# in charts/hedgedoc/values.yaml.
#
# What it does:
#   1. Sets appVersion in Chart.yaml to <new-app-version>.
#   2. Bumps the PATCH segment of version in Chart.yaml by 1.
#
# Usage:
#   bash .github/scripts/bump-chart-version.sh <new-app-version>
#
# Example:
#   bash .github/scripts/bump-chart-version.sh 1.10.0
#   → appVersion: "1.10.0"
#   → version: 0.1.0  →  0.1.1
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

NEW_APP_VERSION="${1:?Usage: $0 <new-app-version>}"
CHART_FILE="charts/hedgedoc/Chart.yaml"

if [[ ! -f "${CHART_FILE}" ]]; then
  echo "ERROR: ${CHART_FILE} not found. Run this script from the repository root." >&2
  exit 1
fi

# ── Update appVersion ────────────────────────────────────────────────────────
sed -i "s|^appVersion:.*|appVersion: \"${NEW_APP_VERSION}\"|" "${CHART_FILE}"

# ── Bump chart patch version ─────────────────────────────────────────────────
CURRENT_VERSION="$(grep '^version:' "${CHART_FILE}" | awk '{print $2}')"

IFS='.' read -r major minor patch <<< "${CURRENT_VERSION}"
NEW_PATCH=$(( patch + 1 ))
NEW_VERSION="${major}.${minor}.${NEW_PATCH}"

sed -i "s|^version:.*|version: ${NEW_VERSION}|" "${CHART_FILE}"

echo "✔  Chart.yaml updated"
echo "   version    : ${CURRENT_VERSION} → ${NEW_VERSION}"
echo "   appVersion : → ${NEW_APP_VERSION}"
