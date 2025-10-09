#!/bin/bash

# Version of vscode-eslint to use
VSCODE_ESLINT_VERSION="3.0.16"

# Check if --debug option is provided
DEBUG_MODE=false
if [ "$1" == "--debug" ]; then
  DEBUG_MODE=true
fi

# Clone the repository
rm -rf vscode-eslint
git clone https://github.com/microsoft/vscode-eslint.git 

# Checkout the given release version
cd vscode-eslint
git checkout "release/${VSCODE_ESLINT_VERSION}"
npm install

# Build the eslint language server
cd server
npm install
npm run webpack

# If not in debug mode, clean up unnecessary files
if [ "$DEBUG_MODE" == "false" ]; then
  cd ../../
  echo "Cleaning up the repository except for ./vscode-eslint/server/out..."
  find ./vscode-eslint -mindepth 1 ! -regex '^./vscode-eslint/server\(/.*\)?' -delete
  find ./vscode-eslint/server -mindepth 1 ! -regex '^./vscode-eslint/server/out\(/.*\)?' -delete
  
  # Remove unnecessary TypeScript declaration files (.d.ts)
  # Keep only the essential runtime files: eslintServer.js and eslintServer.js.map
  echo "Removing unnecessary TypeScript declaration files..."
  find ./vscode-eslint/server/out -type f -name "*.d.ts" -delete
  # Remove empty directories that may be left after deleting .d.ts files
  find ./vscode-eslint/server/out -type d -empty -delete
else
  echo "Skipping cleanup due to --debug mode."
fi
