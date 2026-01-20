#!/bin/bash

################################################################################
# Pharmaceutical CI Platform - Prerequisites Check Script
# Validates all requirements before deployment
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Global variables
ERRORS=0
WARNINGS=0

check_requirement() {
    local name="$1"
    local command="$2"
    local required="$3"
    
    if eval "$command" &>/dev/null; then
        log_success "$name is installed"
        return 0
    else
        if [ "$required" = "true" ]; then
            log_error "$name is required but not found"
            ((ERRORS++))
            return 1
        else
            log_warning "$name is recommended but not found"
            ((WARNINGS++))
            return 1
        fi
    fi
}

echo "=========================================="
echo "Pharmaceutical CI Platform Prerequisites"
echo "=========================================="
echo ""

# 1. AWS CLI
log_info "Checking AWS CLI..."
if check_requirement "AWS CLI" "aws --version" "true"; then
    AWS_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
    echo "   Version: $AWS_VERSION"
    
    # Check minimum version (2.0.0)
    if [[ $(echo "$AWS_VERSION 2.0.0" | tr " " "\n" | sort -V | head -n1) == "2.0.0" ]]; then
        log_success "AWS CLI version is compatible"
    else
        log_warning "AWS CLI version $AWS_VERSION may be outdated (recommended: 2.0.0+)"
        ((WARNINGS++))
    fi
fi
echo ""

# 2. AWS Credentials
log_info "Checking AWS credentials..."
if aws sts get-caller-identity &>/dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    log_success "AWS credentials configured"
    echo "   Account ID: $ACCOUNT_ID"
    echo "   User/Role: $USER_ARN"
else
    log_error "AWS credentials not configured"
    echo "   Run: aws configure"
    ((ERRORS++))
fi
echo ""

# 3. Required AWS Permissions
log_info "Checking AWS permissions..."
REQUIRED_PERMISSIONS=(
    "cloudformation:CreateStack"
    "cloudformation:UpdateStack"
    "cloudformation:DescribeStacks"
    "lambda:CreateFunction"
    "lambda:UpdateFunctionCode"
    "apigateway:CreateRestApi"
    "s3:CreateBucket"
    "es:CreateDomain"
    "iam:CreateRole"
    "events:PutRule"
    "sns:CreateTopic"
    "secretsmanager:CreateSecret"
)

PERMISSION_ERRORS=0
for permission in "${REQUIRED_PERMISSIONS[@]}"; do
    service=$(echo "$permission" | cut -d: -f1)
    action=$(echo "$permission" | cut -d: -f2)
    
    # Simulate permission check (simplified)
    if aws iam simulate-principal-policy \
        --policy-source-arn "$USER_ARN" \
        --action-names "$permission" \
        --resource-arns "*" \
        --query 'EvaluationResults[0].EvalDecision' \
        --output text 2>/dev/null | grep -q "allowed"; then
        continue
    else
        log_warning "Permission may be missing: $permission"
        ((PERMISSION_ERRORS++))
    fi
done

if [ $PERMISSION_ERRORS -eq 0 ]; then
    log_success "AWS permissions appear sufficient"
else
    log_warning "$PERMISSION_ERRORS permissions may be insufficient"
    ((WARNINGS++))
fi
echo ""

# 4. Python
log_info "Checking Python..."
if check_requirement "Python 3" "python3 --version" "true"; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    echo "   Version: $PYTHON_VERSION"
    
    # Check minimum version (3.8)
    if [[ $(echo "$PYTHON_VERSION 3.8.0" | tr " " "\n" | sort -V | head -n1) == "3.8.0" ]]; then
        log_success "Python version is compatible"
    else
        log_error "Python version $PYTHON_VERSION is too old (required: 3.8+)"
        ((ERRORS++))
    fi
fi
echo ""

# 5. Node.js (for frontend)
log_info "Checking Node.js..."
if check_requirement "Node.js" "node --version" "true"; then
    NODE_VERSION=$(node --version | sed 's/v//')
    echo "   Version: $NODE_VERSION"
    
    # Check minimum version (16.0)
    if [[ $(echo "$NODE_VERSION 16.0.0" | tr " " "\n" | sort -V | head -n1) == "16.0.0" ]]; then
        log_success "Node.js version is compatible"
    else
        log_error "Node.js version $NODE_VERSION is too old (required: 16.0+)"
        ((ERRORS++))
    fi
fi
echo ""

# 6. npm
log_info "Checking npm..."
if check_requirement "npm" "npm --version" "true"; then
    NPM_VERSION=$(npm --version)
    echo "   Version: $NPM_VERSION"
fi
echo ""

# 7. Git
log_info "Checking Git..."
if check_requirement "Git" "git --version" "true"; then
    GIT_VERSION=$(git --version | cut -d' ' -f3)
    echo "   Version: $GIT_VERSION"
fi
echo ""

# 8. Docker (optional)
log_info "Checking Docker..."
if check_requirement "Docker" "docker --version" "false"; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | sed 's/,//')
    echo "   Version: $DOCKER_VERSION"
    
    # Check if Docker daemon is running
    if docker info &>/dev/null; then
        log_success "Docker daemon is running"
    else
        log_warning "Docker is installed but daemon is not running"
        ((WARNINGS++))
    fi
fi
echo ""

# 9. AWS Bedrock Access
log_info "Checking AWS Bedrock access..."
if aws bedrock list-foundation-models --region us-east-1 &>/dev/null; then
    # Check for Claude 3 Sonnet model
    if aws bedrock list-foundation-models --region us-east-1 \
        --query 'modelSummaries[?contains(modelId, `anthropic.claude-3-sonnet`)]' \
        --output text | grep -q "anthropic.claude-3-sonnet"; then
        log_success "Bedrock access confirmed with Claude 3 Sonnet"
    else
        log_warning "Bedrock access available but Claude 3 Sonnet not found"
        ((WARNINGS++))
    fi
else
    log_warning "Bedrock access not available (may need to request access)"
    ((WARNINGS++))
fi
echo ""

# 10. Available AWS Services in Region
log_info "Checking AWS services availability..."
REGION=${AWS_DEFAULT_REGION:-us-east-1}
echo "   Checking region: $REGION"

SERVICES=("lambda" "apigateway" "s3" "es" "events" "sns" "secretsmanager" "bedrock")
SERVICE_ERRORS=0

for service in "${SERVICES[@]}"; do
    case $service in
        "lambda")
            if aws lambda list-functions --region "$REGION" --max-items 1 &>/dev/null; then
                continue
            fi
            ;;
        "apigateway")
            if aws apigateway get-rest-apis --region "$REGION" --limit 1 &>/dev/null; then
                continue
            fi
            ;;
        "s3")
            if aws s3 ls &>/dev/null; then
                continue
            fi
            ;;
        "es")
            if aws es list-domain-names --region "$REGION" &>/dev/null; then
                continue
            fi
            ;;
        "events")
            if aws events list-rules --region "$REGION" --limit 1 &>/dev/null; then
                continue
            fi
            ;;
        "sns")
            if aws sns list-topics --region "$REGION" &>/dev/null; then
                continue
            fi
            ;;
        "secretsmanager")
            if aws secretsmanager list-secrets --region "$REGION" --max-results 1 &>/dev/null; then
                continue
            fi
            ;;
        "bedrock")
            if aws bedrock list-foundation-models --region "$REGION" &>/dev/null; then
                continue
            fi
            ;;
    esac
    
    log_warning "Service $service may not be available in region $REGION"
    ((SERVICE_ERRORS++))
done

if [ $SERVICE_ERRORS -eq 0 ]; then
    log_success "All required AWS services are available"
else
    log_warning "$SERVICE_ERRORS AWS services may have issues"
    ((WARNINGS++))
fi
echo ""

# 11. Disk Space
log_info "Checking disk space..."
AVAILABLE_SPACE=$(df . | tail -1 | awk '{print $4}')
REQUIRED_SPACE=1048576  # 1GB in KB

if [ "$AVAILABLE_SPACE" -gt "$REQUIRED_SPACE" ]; then
    log_success "Sufficient disk space available ($(($AVAILABLE_SPACE/1024/1024))GB)"
else
    log_error "Insufficient disk space (required: 1GB, available: $(($AVAILABLE_SPACE/1024/1024))GB)"
    ((ERRORS++))
fi
echo ""

# 12. Network Connectivity
log_info "Checking network connectivity..."
ENDPOINTS=(
    "https://aws.amazon.com"
    "https://api.fda.gov"
    "https://eutils.ncbi.nlm.nih.gov"
    "https://clinicaltrials.gov"
)

NETWORK_ERRORS=0
for endpoint in "${ENDPOINTS[@]}"; do
    if curl -s --connect-timeout 5 "$endpoint" >/dev/null; then
        continue
    else
        log_warning "Cannot reach $endpoint"
        ((NETWORK_ERRORS++))
    fi
done

if [ $NETWORK_ERRORS -eq 0 ]; then
    log_success "Network connectivity verified"
else
    log_warning "$NETWORK_ERRORS endpoints unreachable (may affect data ingestion)"
    ((WARNINGS++))
fi
echo ""

# 13. Project Structure
log_info "Checking project structure..."
REQUIRED_FILES=(
    "architecture.yaml"
    "bedrock-agent.yaml"
    "comprehensive-eventbridge-rules.yaml"
    "backend/src/comprehensive_data_ingestion.py"
    "backend/src/data_quality_pipeline.py"
    "frontend/package.json"
    "frontend/src/App.tsx"
)

MISSING_FILES=0
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        continue
    else
        log_warning "Missing file: $file"
        ((MISSING_FILES++))
    fi
done

if [ $MISSING_FILES -eq 0 ]; then
    log_success "Project structure is complete"
else
    log_warning "$MISSING_FILES files are missing"
    ((WARNINGS++))
fi
echo ""

# Summary
echo "=========================================="
echo "Prerequisites Check Summary"
echo "=========================================="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    log_success "All prerequisites met! Ready for deployment."
    echo ""
    echo "Next steps:"
    echo "1. Run: ./deploy.sh dev us-east-1"
    echo "2. Configure API keys in AWS Secrets Manager"
    echo "3. Deploy frontend"
    EXIT_CODE=0
elif [ $ERRORS -eq 0 ]; then
    log_warning "Prerequisites mostly met with $WARNINGS warnings."
    echo ""
    echo "You can proceed with deployment, but consider addressing warnings."
    echo "Run: ./deploy.sh dev us-east-1"
    EXIT_CODE=0
else
    log_error "Prerequisites check failed with $ERRORS errors and $WARNINGS warnings."
    echo ""
    echo "Please fix the errors before deployment:"
    
    if ! command -v aws &>/dev/null; then
        echo "• Install AWS CLI: https://aws.amazon.com/cli/"
    fi
    
    if ! aws sts get-caller-identity &>/dev/null; then
        echo "• Configure AWS credentials: aws configure"
    fi
    
    if ! command -v python3 &>/dev/null; then
        echo "• Install Python 3.8+: https://python.org"
    fi
    
    if ! command -v node &>/dev/null; then
        echo "• Install Node.js 16+: https://nodejs.org"
    fi
    
    EXIT_CODE=1
fi

echo ""
echo "Errors: $ERRORS | Warnings: $WARNINGS"
echo "=========================================="

exit $EXIT_CODE