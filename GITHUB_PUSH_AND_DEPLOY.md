# GitHub Push and Deploy Workflow

## Overview

This guide walks you through pushing your code to GitHub and deploying the frontend from GitHub to EC2.

## Workflow Steps

```
Local Development
    ↓
Push to GitHub
    ↓
EC2 Instance
    ↓
Pull from GitHub
    ↓
Build & Deploy
    ↓
Frontend Running
```

## Step 1: Push Code to GitHub

### Prerequisites

- GitHub account
- Repository created on GitHub
- Git configured locally

### Configure Git (First Time Only)

```bash
# Set your name
git config --global user.name "Your Name"

# Set your email
git config --global user.email "your.email@example.com"

# Verify configuration
git config --global --list
```

### Push Code to GitHub

```bash
# Make the script executable
chmod +x scripts/push-to-github.sh

# Run the push script
./scripts/push-to-github.sh https://github.com/your-org/ci-alert-platform.git main

# Or with custom commit message
./scripts/push-to-github.sh https://github.com/your-org/ci-alert-platform.git main "Initial commit with Phase 3"
```

### Script Parameters

```bash
./scripts/push-to-github.sh <REPO_URL> [BRANCH] [COMMIT_MESSAGE]
```

- `REPO_URL`: GitHub repository URL (required)
- `BRANCH`: Git branch (default: main)
- `COMMIT_MESSAGE`: Commit message (default: timestamp)

### Example Usage

```bash
# Push to main branch
./scripts/push-to-github.sh https://github.com/your-org/ci-alert-platform.git main

# Push to develop branch
./scripts/push-to-github.sh https://github.com/your-org/ci-alert-platform.git develop

# Push with custom message
./scripts/push-to-github.sh https://github.com/your-org/ci-alert-platform.git main "Add chatbot and Phase 3"

# Using SSH URL
./scripts/push-to-github.sh git@github.com:your-org/ci-alert-platform.git main
```

### What the Script Does

1. ✅ Checks Git configuration
2. ✅ Verifies repository status
3. ✅ Shows changes to be committed
4. ✅ Confirms before pushing
5. ✅ Stages all changes
6. ✅ Creates commit
7. ✅ Configures remote
8. ✅ Pushes to GitHub
9. ✅ Displays summary

### Output Example

```
[INFO] Checking Git configuration...
[SUCCESS] Git configured as: Your Name <your.email@example.com>

[INFO] Checking repository status...
[SUCCESS] Git repository found

[INFO] Changes to be committed:
 M backend/src/handlers/chatbot_handler.py
 A backend/src/handlers/agent_tools.py
 M architecture.yaml
 A CHATBOT_IMPLEMENTATION.md

Continue with push? (y/n) y

[INFO] Staging changes...
[INFO] Files to be committed:
  backend/src/handlers/chatbot_handler.py
  backend/src/handlers/agent_tools.py
  architecture.yaml
  CHATBOT_IMPLEMENTATION.md

[INFO] Creating commit...
[SUCCESS] Commit created

[SUCCESS] Push completed successfully!

Repository: https://github.com/your-org/ci-alert-platform.git
Branch: main
Commit: Initial commit with Phase 3

View on GitHub:
  https://github.com/your-org/ci-alert-platform.git/tree/main
```

---

## Step 2: Deploy Frontend from GitHub

### All Deployment Scripts Now Pull from GitHub

All deployment scripts have been updated to:
1. Pull latest code from GitHub
2. Build frontend
3. Start services

### Option 1: Full Automated Deployment

```bash
# SSH into EC2 instance
ssh -i your-key-pair.pem ubuntu@<INSTANCE_IP>

# Download and run deployment script
wget https://raw.githubusercontent.com/your-org/ci-alert-platform/main/scripts/deploy-frontend-ec2.sh
chmod +x deploy-frontend-ec2.sh

# Run deployment
./deploy-frontend-ec2.sh dev https://github.com/your-org/ci-alert-platform.git http://api.example.com:8000 3000 main
```

### Option 2: Quick Deployment

```bash
# SSH into EC2 instance
ssh -i your-key-pair.pem ubuntu@<INSTANCE_IP>

# Download and run quick deployment script
wget https://raw.githubusercontent.com/your-org/ci-alert-platform/main/scripts/quick-deploy-frontend.sh
chmod +x quick-deploy-frontend.sh

# Run deployment
./quick-deploy-frontend.sh dev http://api.example.com:8000 3000 https://github.com/your-org/ci-alert-platform.git main
```

### Option 3: Docker Deployment

```bash
# SSH into EC2 instance
ssh -i your-key-pair.pem ubuntu@<INSTANCE_IP>

# Download and run Docker deployment script
wget https://raw.githubusercontent.com/your-org/ci-alert-platform/main/scripts/deploy-frontend-docker.sh
chmod +x deploy-frontend-docker.sh

# Run deployment
./deploy-frontend-docker.sh dev http://api.example.com:8000 3000 docker.io https://github.com/your-org/ci-alert-platform.git main
```

### Option 4: One-Liner Deployment

```bash
# SSH into EC2 instance
ssh -i your-key-pair.pem ubuntu@<INSTANCE_IP>

# Download and run one-liner deployment script
wget https://raw.githubusercontent.com/your-org/ci-alert-platform/main/scripts/one-liner-deploy.sh
chmod +x one-liner-deploy.sh

# Run deployment
./one-liner-deploy.sh dev http://api.example.com:8000 3000 https://github.com/your-org/ci-alert-platform.git main
```

---

## Deployment Script Parameters

### Full Deployment (`deploy-frontend-ec2.sh`)

```bash
./deploy-frontend-ec2.sh [ENVIRONMENT] [PORT] [API_ENDPOINT] [REPO_URL] [BRANCH]
```

- `ENVIRONMENT`: dev/staging/prod (default: dev)
- `PORT`: Frontend port (default: 3000)
- `API_ENDPOINT`: Backend API URL (default: http://localhost:8000)
- `REPO_URL`: GitHub repository URL
- `BRANCH`: Git branch (default: main)

### Quick Deployment (`quick-deploy-frontend.sh`)

```bash
./quick-deploy-frontend.sh [ENVIRONMENT] [API_ENDPOINT] [PORT] [REPO_URL] [BRANCH]
```

### Docker Deployment (`deploy-frontend-docker.sh`)

```bash
./deploy-frontend-docker.sh [ENVIRONMENT] [API_ENDPOINT] [PORT] [REGISTRY] [REPO_URL] [BRANCH]
```

### One-Liner Deployment (`one-liner-deploy.sh`)

```bash
./one-liner-deploy.sh [ENVIRONMENT] [API_ENDPOINT] [PORT] [REPO_URL] [BRANCH]
```

---

## Complete Workflow Example

### Step 1: Local Development

```bash
# Make changes to code
# Edit files, add features, etc.

# Check status
git status

# Stage changes
git add .

# Commit locally
git commit -m "Add new features"
```

### Step 2: Push to GitHub

```bash
# Make script executable
chmod +x scripts/push-to-github.sh

# Push to GitHub
./scripts/push-to-github.sh https://github.com/your-org/ci-alert-platform.git main "Add new features"

# Verify on GitHub
# Visit: https://github.com/your-org/ci-alert-platform
```

### Step 3: Deploy to EC2

```bash
# SSH into EC2
ssh -i your-key-pair.pem ubuntu@<INSTANCE_IP>

# Download deployment script
wget https://raw.githubusercontent.com/your-org/ci-alert-platform/main/scripts/quick-deploy-frontend.sh
chmod +x quick-deploy-frontend.sh

# Deploy
./quick-deploy-frontend.sh dev http://api.example.com:8000 3000 https://github.com/your-org/ci-alert-platform.git main

# Verify deployment
curl http://localhost/health
```

### Step 4: Access Frontend

```bash
# Open in browser
# http://<INSTANCE_IP>
```

---

## Troubleshooting

### Git Configuration Issues

```bash
# Check git configuration
git config --global --list

# Set user name
git config --global user.name "Your Name"

# Set user email
git config --global user.email "your.email@example.com"
```

### Push Fails

```bash
# Check remote URL
git remote -v

# Update remote URL
git remote set-url origin https://github.com/your-org/ci-alert-platform.git

# Try push again
git push -u origin main
```

### Deployment Fails

```bash
# Check prerequisites
./scripts/check-prerequisites.sh

# Check logs
sudo journalctl -u ci-frontend -f

# Check Nginx
sudo systemctl status nginx

# Restart services
sudo systemctl restart ci-frontend nginx
```

### Code Not Updating

```bash
# Force pull latest code
cd ci-alert-platform
git fetch origin main
git reset --hard origin/main
git pull origin main

# Rebuild
cd frontend
npm install
npm run build

# Restart
sudo systemctl restart ci-frontend
```

---

## Continuous Deployment Workflow

### Automated Updates

```bash
# Create update script
cat > ~/update-frontend.sh << 'EOF'
#!/bin/bash
cd ~/ci-alert-platform
git fetch origin main
git reset --hard origin/main
git pull origin main
cd frontend
npm install
npm run build
sudo systemctl restart ci-frontend
EOF

# Make executable
chmod +x ~/update-frontend.sh

# Add to crontab for daily updates
(crontab -l 2>/dev/null; echo "0 2 * * * ~/update-frontend.sh") | crontab -
```

---

## Best Practices

### Before Pushing

1. ✅ Test code locally
2. ✅ Run linter/formatter
3. ✅ Build successfully
4. ✅ Check for sensitive data
5. ✅ Write meaningful commit message

### Push Command

```bash
# Always use the push script
./scripts/push-to-github.sh <REPO_URL> <BRANCH> "<MESSAGE>"
```

### After Deployment

1. ✅ Verify frontend is running
2. ✅ Check logs for errors
3. ✅ Test API connectivity
4. ✅ Monitor performance
5. ✅ Keep backups

---

## Security Considerations

### GitHub Access

```bash
# Use SSH keys (recommended)
ssh-keygen -t ed25519 -C "your.email@example.com"

# Add public key to GitHub
# Settings → SSH and GPG keys → New SSH key

# Test connection
ssh -T git@github.com
```

### Credentials

```bash
# Never commit credentials
# Use environment variables instead

# Example .env.local (not committed)
REACT_APP_API_ENDPOINT=http://api.example.com:8000
REACT_APP_API_KEY=your-secret-key
```

### Repository Permissions

```bash
# Make repository private if needed
# GitHub → Settings → Visibility → Private

# Restrict branch access
# GitHub → Settings → Branches → Branch protection rules
```

---

## Summary

| Step | Command | Time |
|------|---------|------|
| Push to GitHub | `./scripts/push-to-github.sh <URL>` | 1-2 min |
| Deploy (Full) | `./scripts/deploy-frontend-ec2.sh dev <API>` | 10-15 min |
| Deploy (Quick) | `./scripts/quick-deploy-frontend.sh dev <API>` | 5-7 min |
| Deploy (Docker) | `./scripts/deploy-frontend-docker.sh dev <API>` | 8-10 min |
| Deploy (One-Liner) | `./scripts/one-liner-deploy.sh dev <API>` | 12-15 min |

---

## Next Steps

1. ✅ Configure Git locally
2. ✅ Push code to GitHub
3. ✅ Launch EC2 instance
4. ✅ Deploy frontend from GitHub
5. ✅ Verify deployment
6. ✅ Setup monitoring
7. ✅ Configure CI/CD pipeline
