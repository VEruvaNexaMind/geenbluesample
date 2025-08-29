#!/bin/bash

# Build Script for Blue-Green Deployment
# This script builds Docker images locally

set -e

# Configuration
LOCAL_IMAGE="bluegreen-demo"
REGION="us-west-2"
VERSION=${1:-$(date +%Y%m%d%H%M%S)}

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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to login to ECR
ecr_login() {
    print_status "Logging into ECR..."
    aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_REPO}
    
    if [ $? -eq 0 ]; then
        print_success "ECR login successful!"
    else
        print_error "ECR login failed!"
        exit 1
    fi
}

# Function to build Docker image
build_image() {
    local tag=$1
    print_status "Building Docker image with tag: ${tag}..."
    
    # Generate package-lock.json if it doesn't exist
    if [ ! -f "app/package-lock.json" ]; then
        print_status "Generating package-lock.json..."
        cd app && npm install && cd ..
    fi
    
    docker build -t ${LOCAL_IMAGE}:${tag} .
    docker tag ${LOCAL_IMAGE}:${tag} ${LOCAL_IMAGE}:latest
    
    if [ $? -eq 0 ]; then
        print_success "Docker image built successfully!"
        print_success "Image: ${LOCAL_IMAGE}:${tag}"
    else
        print_error "Docker build failed!"
        exit 1
    fi
}

# Remove ECR-related functions since we're using local images
# No push needed for local development

# Main execution
main() {
    print_status "Starting build process..."
    print_status "Version: ${VERSION}"
    print_status "Local Image: ${LOCAL_IMAGE}"
    
    # Build image
    build_image ${VERSION}
    
    print_success "Build completed successfully!"
    print_success "You can now deploy using: ./scripts/blue-green-deploy.sh deploy <blue|green> ${VERSION}"
}

# Function to create ECR repository if it doesn't exist
create_ecr_repo() {
    local repo_name=$(basename ${ECR_REPO})
    print_status "Checking if ECR repository exists..."
    
    aws ecr describe-repositories --repository-names ${repo_name} --region ${REGION} >/dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        print_status "Creating ECR repository: ${repo_name}..."
        aws ecr create-repository --repository-name ${repo_name} --region ${REGION}
        
        if [ $? -eq 0 ]; then
            print_success "ECR repository created successfully!"
        else
            print_error "Failed to create ECR repository!"
            exit 1
        fi
    else
        print_status "ECR repository already exists."
    fi
}

# Main execution
main() {
    print_status "Starting build and push process..."
    print_status "Version: ${VERSION}"
    print_status "ECR Repository: ${ECR_REPO}"
    
    # Create ECR repository if needed
    create_ecr_repo
    
    # Login to ECR
    ecr_login
    
    # Build image
    build_image ${VERSION}
    
    # Push image
    push_image ${VERSION}
    
    print_success "Build and push completed successfully!"
    print_success "You can now deploy using: ./scripts/blue-green-deploy.sh deploy <blue|green> ${VERSION}"
}

# Check if required tools are installed
check_dependencies() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed!"
        exit 1
    fi
}

# Command line interface
case "$1" in
    "build")
        check_dependencies
        main
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [build] [version]"
        echo ""
        echo "Commands:"
        echo "  build [version]  - Build Docker image locally (default: timestamp)"
        echo "  help            - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 build              # Build with timestamp version"
        echo "  $0 build v1.0.0       # Build with specific version"
        ;;
    "")
        # Default to build
        check_dependencies
        main
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use '$0 help' for usage information."
        exit 1
        ;;
esac
