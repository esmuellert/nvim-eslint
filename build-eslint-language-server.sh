#!/bin/bash

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
git checkout release/3.0.16
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
else
  echo "Skipping cleanup due to --debug mode."
fi
