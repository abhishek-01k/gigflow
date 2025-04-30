#!/bin/bash

# This script will commit all changes in multiple logical commits
set -e  # Exit immediately if a command exits with a non-zero status

echo "Starting commit sequence..."

git config user.name abhishek-01k
git config user.email abhishekkumar214567@gmail.com
# 1. Commit the verify utility function
echo "Committing contract verification utility..."
git add contracts/utils/verify.js
git commit -m "feat: add contract verification utility function for block explorers"

# 2. Commit the dispute resolver contract
echo "Committing GigFlowDisputeResolver contract..."
git add contracts/contracts/GigFlowDisputeResolver.sol
git commit -m "feat: implement GigFlowDisputeResolver contract for handling disputes between freelancers and clients"

# 3. Commit the deployment script
echo "Committing deployment script..."
git add contracts/scripts/deploy.js
git commit -m "feat: create deployment script for GigFlow platform contracts"

# 4. Final commit for any remaining changes (if any)
if [ -n "$(git status --porcelain)" ]; then
  echo "Committing remaining changes..."
  git add .
  git commit -m "chore: finalize implementation and fix integration issues"
fi

echo "All commits completed successfully!"
echo "Summary of commits:"
git log --oneline -n 4

# Make the script executable
chmod +x commit.sh 