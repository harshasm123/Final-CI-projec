#!/bin/bash

################################################################################
# Push Code to GitHub Script
# Commits and pushes all changes to GitHub repository
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

################################################################################
# Configuration
################################################################################

REPO_URL=${1:-""}
BRANCH=${2:-"main"}
COMMIT_MESSAGE=${3:-"Update: CI Alert Platform - $(date +%Y-%m-%d\ %H:%M:%S)"}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Push Code to GitHub${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

################################################################################
# Validate Input
################################################################################

if [ -z "$REPO_URL" ]; then
    log_error "Repository URL is required"
    echo ""
    echo "Usage: $0 <REPO_URL> [BRANCH] [COMMIT_MESSAGE]"
    echo ""
    echo "Examples:"
    echo "  $0 https://github.com/your-org/ci-alert-platform.git"
    echo "  $0 https://github.com/your-org/ci-alert-platform.git main 'Initial commit'"
    echo "  $0 git@github.com:your-org/ci-alert-platform.git develop"
    echo ""
    exit 1
fi

################################################################################
# Check Git Configuration
################################################################################

log_info "Checking Git configuration..."

if ! git config --global user.name &> /dev/null; then
    log_error "Git user name not configured"
    echo ""
    echo "Configure git user:"
    echo "  git config --global user.name 'Your Name'"
    echo "  git config --global user.email 'your.email@example.com'"
    echo ""
    exit 1
fi

if ! git config --global user.email &> /dev/null; then
    log_error "Git user email not configured"
    echo ""
    echo "Configure git email:"
    echo "  git config --global user.email 'your.email@example.com'"
    echo ""
    exit 1
fi

log_success "Git configured as: $(git config --global user.name) <$(git config --global user.email)>"
echo ""

################################################################################
# Check Repository Status
################################################################################

log_info "Checking repository status..."

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Not in a git repository"
    echo ""
    echo "Initialize git repository:"
    echo "  git init"
    echo "  git add ."
    echo "  git commit -m 'Initial commit'"
    echo ""
    exit 1
fi

log_success "Git repository found"

# Check for uncommitted changes
if git diff-index --quiet HEAD --; then
    log_warning "No uncommitted changes"
else
    log_info "Uncommitted changes detected"
fi

echo ""

################################################################################
# Display Changes
################################################################################

log_info "Changes to be committed:"
echo ""

# Show status
git status --short

echo ""

################################################################################
# Confirm Before Pushing
################################################################################

log_info "Repository details:"
echo "  URL: $REPO_URL"
echo "  Branch: $BRANCH"
echo "  Commit Message: $COMMIT_MESSAGE"
echo ""

read -p "Continue with push? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warning "Push cancelled"
    exit 0
fi

echo ""

################################################################################
# Stage Changes
################################################################################

log_info "Staging changes..."

# Add all changes
git add -A

# Show what will be committed
log_info "Files to be committed:"
git diff --cached --name-only | sed 's/^/  /'

echo ""

################################################################################
# Commit Changes
################################################################################

log_info "Creating commit..."

git commit -m "$COMMIT_MESSAGE" || {
    log_warning "Nothing to commit"
}

log_success "Commit created"
echo ""

################################################################################
# Configure Remote
################################################################################

log_info "Configuring remote repository..."

# Check if remote exists
if git remote | grep -q "^origin$"; then
    log_info "Remote 'origin' already exists"
    CURRENT_URL=$(git remote get-url origin)
    
    if [ "$CURRENT_URL" != "$REPO_URL" ]; then
        log_warning "Remote URL mismatch"
        echo "  Current: $CURRENT_URL"
        echo "  New: $REPO_URL"
        
        read -p "Update remote URL? (y/n) " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git remote set-url origin "$REPO_URL"
            log_success "Remote URL updated"
        fi
    fi
else
    log_info "Adding remote 'origin'..."
    git remote add origin "$REPO_URL"
    log_success "Remote added"
fi

echo ""

################################################################################
# Push to GitHub
################################################################################

log_info "Pushing to GitHub..."
echo "  Branch: $BRANCH"
echo ""

# Try to push
if git push -u origin "$BRANCH"; then
    log_success "Code pushed successfully"
else
    log_error "Failed to push code"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check your GitHub credentials"
    echo "  2. Verify SSH key is configured (if using SSH)"
    echo "  3. Check branch permissions"
    echo "  4. Try: git push -u origin $BRANCH --force (use with caution)"
    echo ""
    exit 1
fi

echo ""

################################################################################
# Display Summary
################################################################################

log_success "Push completed successfully!"
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Repository: $REPO_URL"
echo "Branch: $BRANCH"
echo "Commit: $COMMIT_MESSAGE"
echo ""
echo "View on GitHub:"
echo "  $REPO_URL/tree/$BRANCH"
echo ""

################################################################################
# Next Steps
################################################################################

log_info "Next steps:"
echo "  1. Deploy frontend from GitHub:"
echo "     bash scripts/deploy-frontend-ec2.sh dev http://api.example.com:8000"
echo ""
echo "  2. Or deploy with Docker:"
echo "     bash scripts/deploy-frontend-docker.sh dev http://api.example.com:8000"
echo ""
echo "  3. Or use one-liner deployment:"
echo "     bash scripts/one-liner-deploy.sh dev http://api.example.com:8000"
echo ""
