# Getting Started

## Quick Start (5 Minutes)

### Option 1: Quick Deploy (Recommended)
```bash
chmod +x quick-deploy.sh
./quick-deploy.sh dev us-east-1
```

### Option 2: Full Deploy
```bash
chmod +x deploy.sh
./deploy.sh dev us-east-1
```

## Prerequisites

Your system needs:
- Git
- Node.js 18+
- Python 3.11+
- AWS CLI
- AWS CDK

**The deploy script will automatically install missing tools!**

## Step-by-Step

### 1. Configure AWS Credentials
```bash
aws configure
```

Enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region: `us-east-1`
- Default output format: `json`

Verify:
```