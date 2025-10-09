#!/bin/bash
set -e

# Get the current version from build script
CURRENT_VERSION=$(grep "VSCODE_ESLINT_VERSION=" build-eslint-language-server.sh | cut -d'"' -f2)
echo "Current version in build script: ${CURRENT_VERSION}"

# Get the latest release from vscode-eslint repo using gh CLI
LATEST_VERSION=$(gh release list --repo microsoft/vscode-eslint --limit 50 --json tagName,isPrerelease | \
  jq -r '.[] | select(.isPrerelease == false) | .tagName' | \
  grep "^release/" | \
  head -n 1 | \
  sed 's/release\///')

echo "Latest release version: ${LATEST_VERSION}"

# Compare versions
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
  echo "✓ Version is up to date"
  echo "up-to-date=true" >> $GITHUB_OUTPUT
  exit 0
else
  echo "✗ New version available: ${LATEST_VERSION} (current: ${CURRENT_VERSION})"
  echo "up-to-date=false" >> $GITHUB_OUTPUT
  echo "current-version=${CURRENT_VERSION}" >> $GITHUB_OUTPUT
  echo "latest-version=${LATEST_VERSION}" >> $GITHUB_OUTPUT
  exit 0
fi
