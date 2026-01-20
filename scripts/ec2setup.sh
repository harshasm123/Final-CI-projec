#!/bin/bash

#############################################
# EC2 Setup Script - Git Installation & Repo Pull
# Purpose: Install Git and pull repository on EC2
#############################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="${1:-https://github.com/your-org/ci-alert-platform.git}"
BRANCH="${2:-main}"
INSTALL_DIR="${3:-$HOME/ci-alert-platform}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}EC2 Setup - Git & Repository Pull${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Step 1: Update system packages
print_info "Step 1: Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
print_status "System packages updated"
echo ""

# Step 2: Install Git
print_info "Step 2: Installing Git..."
if command -v git &> /dev/null; then
    print_warning "Git already installed: $(git --version)"
else
    sudo apt-get install -y -qq git
    print_status "Git installed: $(git --version)"
fi
echo ""

# Step 3: Configure Git (if not already configured)
print_info "Step 3: Configuring Git..."
GIT_USER=$(git config --global user.name 2>/dev/null || echo "")
GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

if [ -z "$GIT_USER" ]; then
    print_warning "Git user not configured. Setting default..."
    git config --global user.name "CI Analyst"
    git config --global user.email "analyst@pharma-ci.local"
    print_status "Git user configured"
else
    print_status "Git user already configured: $GIT_USER"
fi
echo ""

# Step 4: Create installation directory
print_info "Step 4: Creating installation directory..."
if [ -d "$INSTALL_DIR" ]; then
    print_warning "Directory already exists: $INSTALL_DIR"
    read -p "Do you want to pull latest changes? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd "$INSTALL_DIR"
        print_info "Pulling latest changes from $BRANCH..."
        git fetch origin
        git reset --hard origin/$BRANCH
        git pull origin $BRANCH
        print_status "Repository updated"
    fi
else
    mkdir -p "$INSTALL_DIR"
    print_status "Directory created: $INSTALL_DIR"
fi
echo ""

# Step 5: Clone or update repository
if [ ! -d "$INSTALL_DIR/.git" ]; then
    print_info "Step 5: Cloning repository..."
    print_info "Repository URL: $REPO_URL"
    print_info "Branch: $BRANCH"
    print_info "Destination: $INSTALL_DIR"
    
    git clone --branch $BRANCH $REPO_URL $INSTALL_DIR
    print_status "Repository cloned successfully"
else
    print_info "Step 5: Repository already exists, pulling latest changes..."
    cd "$INSTALL_DIR"
    git fetch origin
    git reset --hard origin/$BRANCH
    git pull origin $BRANCH
    print_status "Repository updated successfully"
fi
echo ""

# Step 6: Verify repository
print_info "Step 6: Verifying repository..."
cd "$INSTALL_DIR"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
CURRENT_COMMIT=$(git rev-parse --short HEAD)
REPO_NAME=$(basename "$REPO_URL" .git)

print_status "Repository: $REPO_NAME"
print_status "Location: $INSTALL_DIR"
print_status "Branch: $CURRENT_BRANCH"
print_status "Commit: $CURRENT_COMMIT"
echo ""

# Step 7: Display directory structure
print_info "Step 7: Repository structure:"
ls -la "$INSTALL_DIR" | head -20
echo ""

# Step 8: Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Repository Details:"
echo "  Location: $INSTALL_DIR"
echo "  Repository: $REPO_NAME"
echo "  Branch: $CURRENT_BRANCH"
echo "  Commit: $CURRENT_COMMIT"
echo ""
echo "Next Steps:"
echo "  1. cd $INSTALL_DIR"
echo "  2. Review the code"
echo "  3. Run deployment scripts from scripts/ directory"
echo ""
echo "Useful Commands:"
echo "  Check git status: git status"
echo "  View commit history: git log --oneline -10"
echo "  Pull latest changes: git pull origin $BRANCH"
echo "  Switch branch: git checkout <branch-name>"
echo ""

print_status "EC2 setup completed successfully!"
