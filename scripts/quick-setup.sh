#!/bin/bash

# Quick Setup Script for Blue-Green Deployment Demo
# This script automates the complete setup process

set -e

# Configuration
CLUSTER_NAME="bluegreen-eks-sbx"
REGION="us-west-2"
NAMESPACE="bluegreen-demo"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_tools=()
    
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws-cli")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install the missing tools and try again."
        exit 1
    fi
    
    print_success "All required tools are installed!"
}

# Function to configure kubectl
configure_kubectl() {
    print_header "Configuring kubectl for EKS"
    
    print_status "Updating kubeconfig for cluster: ${CLUSTER_NAME}"
    aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}
    
    print_status "Testing cluster connectivity..."
    if kubectl get nodes &> /dev/null; then
        print_success "Successfully connected to EKS cluster!"
        kubectl get nodes
    else
        print_error "Failed to connect to EKS cluster!"
        exit 1
    fi
}

# Function to make scripts executable
make_scripts_executable() {
    print_header "Making Scripts Executable"
    
    chmod +x scripts/*.sh
    print_success "All scripts are now executable!"
}

# Function to setup environment
setup_environment() {
    print_header "Setting Up Kubernetes Environment"
    
    print_status "Running environment setup..."
    ./scripts/setup.sh setup
    
    print_success "Environment setup completed!"
}

# Function to build images
build_images() {
    print_header "Building Docker Images"
    
    print_status "Building blue version..."
    ./scripts/build-and-push.sh build blue
    
    print_status "Building green version..."
    ./scripts/build-and-push.sh build green
    
    print_success "Both images built successfully!"
    
    print_status "Available images:"
    docker images bluegreen-demo
}

# Function to load images to nodes
load_images() {
    print_header "Loading Images to EKS Nodes"
    
    print_status "Loading blue image to all nodes..."
    ./scripts/load-images.sh load blue
    
    print_status "Loading green image to all nodes..."
    ./scripts/load-images.sh load green
    
    print_success "Images loaded to all EKS nodes!"
    
    print_status "Verifying images on nodes..."
    ./scripts/load-images.sh check
}

# Function to deploy blue environment
deploy_blue() {
    print_header "Deploying Blue Environment"
    
    print_status "Deploying to blue environment..."
    ./scripts/blue-green-deploy.sh deploy blue blue
    
    print_success "Blue environment deployed!"
}

# Function to test deployment
test_deployment() {
    print_header "Testing Deployment"
    
    print_status "Checking deployment status..."
    ./scripts/blue-green-deploy.sh status
    
    print_status "Running health check..."
    ./scripts/blue-green-deploy.sh health
    
    print_status "Checking pods..."
    kubectl get pods -n ${NAMESPACE}
    
    print_success "Deployment test completed!"
}

# Function to show next steps
show_next_steps() {
    print_header "Next Steps"
    
    echo -e "${GREEN}🎉 Blue-Green Deployment Setup Complete!${NC}"
    echo ""
    echo "Your application is now running on the blue environment."
    echo ""
    echo "To test the application locally:"
    echo "  kubectl port-forward service/bluegreen-demo-service 8080:80 -n bluegreen-demo"
    echo "  curl http://localhost:8080/health"
    echo ""
    echo "To deploy to green environment:"
    echo "  ./scripts/blue-green-deploy.sh deploy green green"
    echo ""
    echo "To switch traffic between environments:"
    echo "  ./scripts/blue-green-deploy.sh switch green"
    echo "  ./scripts/blue-green-deploy.sh switch blue"
    echo ""
    echo "To check status:"
    echo "  ./scripts/blue-green-deploy.sh status"
    echo ""
    echo "To rollback:"
    echo "  ./scripts/blue-green-deploy.sh rollback"
    echo ""
    echo "For more commands, see: ./DEPLOYMENT-INSTRUCTIONS.md"
}

# Function to prompt for continuation
prompt_continue() {
    local step_name=$1
    echo ""
    read -p "$(echo -e "${YELLOW}Continue with ${step_name}? (y/n): ${NC}")" -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Setup interrupted by user."
        exit 0
    fi
}

# Main execution
main() {
    print_header "Blue-Green Deployment Quick Setup"
    print_status "This script will set up the complete blue-green deployment environment."
    print_status "Cluster: ${CLUSTER_NAME}"
    print_status "Region: ${REGION}"
    
    # Check if user wants to continue
    echo ""
    read -p "$(echo -e "${YELLOW}Do you want to continue? (y/n): ${NC}")" -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Setup cancelled by user."
        exit 0
    fi
    
    check_prerequisites
    prompt_continue "kubectl configuration"
    
    configure_kubectl
    prompt_continue "making scripts executable"
    
    make_scripts_executable
    prompt_continue "environment setup"
    
    setup_environment
    prompt_continue "building Docker images"
    
    build_images
    prompt_continue "loading images to EKS nodes"
    
    load_images
    prompt_continue "deploying blue environment"
    
    deploy_blue
    prompt_continue "testing deployment"
    
    test_deployment
    
    show_next_steps
}

# Command line interface
case "$1" in
    "auto")
        # Run without prompts (automatic mode)
        check_prerequisites
        configure_kubectl
        make_scripts_executable
        setup_environment
        build_images
        load_images
        deploy_blue
        test_deployment
        show_next_steps
        ;;
    "help"|"-h"|"--help")
        echo "Blue-Green Deployment Quick Setup"
        echo ""
        echo "Usage: $0 [auto]"
        echo ""
        echo "Commands:"
        echo "  auto    - Run complete setup without prompts"
        echo "  help    - Show this help message"
        echo ""
        echo "Interactive mode (default):"
        echo "  $0"
        ;;
    "")
        # Default interactive mode
        main
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use '$0 help' for usage information."
        exit 1
        ;;
esac
