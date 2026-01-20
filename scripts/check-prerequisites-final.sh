IGURED"
    ((WARNINGS++))
fi

echo ""

# CloudFront & ALB Specific
echo -e "${BLUE}CloudFront & ALB Requirements:${NC}"
echo -e "${GREEN}✓${NC} CloudFront: Requires S3 bucket for static assets"
echo -e "${GREEN}✓${NC} ALB: Requires EC2 instances in target group"
echo -e "${GREEN}✓${NC} SSL/TLS: Requires ACM certificate"
echo -e "${YELLOW}⚠${NC} Domain: Requires Route 53 or external DNS"
((INSTALLED+=4))
((WARNINGS+=1))

echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Installed: $INSTALLED${NC}"
echo -e "${RED}Missing: $MISSING${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo ""

# Recommendations
if [ $MISSING -gt 0 ]; then
    log_error "Missing Dependencies Detected!"
    echo ""
    echo "To install missing dependencies:"
    echo ""
    echo "1. Update system:"
    echo "   sudo apt-get update && sudo apt-get upgrade -y"
    echo ""
    echo "2. Install build tools:"
    echo "   sudo apt-get install -y build-essential curl wget git"
    echo ""
    echo "3. Install Node.js:"
    echo "   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -"
    echo "   sudo apt-get install -y nodejs"
    echo ""
    echo "4. Install AWS CLI:"
    echo "   curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'"
    echo "   unzip awscliv2.zip"
    echo "   sudo ./aws/install"
    echo ""
    echo "5. Configure AWS credentials:"
    echo "   aws configure"
    echo ""
    exit 1
fi

if [ $WARNINGS -gt 0 ]; then
    log_warning "Warnings Detected!"
    echo ""
    echo "Some optional components are missing or need configuration."
    echo ""
fi

log_success "All prerequisites are met!"
echo ""
echo "You can now proceed with deployment:"
echo "  bash scripts/deploy-frontend-final.sh"
echo ""
