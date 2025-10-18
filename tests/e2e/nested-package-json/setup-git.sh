#!/bin/bash

# Setup script to initialize the .git repository in the test project
# This must be run before testing as .git directories cannot be committed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Setting up test project git repository ==="
echo "Directory: $SCRIPT_DIR"

# Check if .git already exists
if [ -d ".git" ]; then
    echo "✓ .git directory already exists"
    git status &>/dev/null && echo "✓ Git repository is valid" || {
        echo "❌ .git exists but is invalid, recreating..."
        rm -rf .git
    }
fi

# Initialize git if needed
if [ ! -d ".git" ]; then
    echo "Initializing git repository..."
    git init
    git config user.email "test@nvim-eslint.local"
    git config user.name "Test User"
    
    # Add all files except node_modules
    git add -A
    git commit -m "Initial commit of test project"
    
    echo "✓ Git repository initialized and files committed"
fi

# Verify the setup
echo ""
echo "=== Verification ==="
echo "Git root: $(git rev-parse --show-toplevel)"
echo "Commit count: $(git rev-list --count HEAD)"
echo ""
echo "✓ Setup complete!"
echo ""
echo "The test project now has its own .git repository at the root,"
echo "matching the user's folder structure from issue #10."
