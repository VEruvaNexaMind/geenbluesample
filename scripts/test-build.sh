#!/bin/bash

# Quick build test after fixing Dockerfile

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check project structure
check_structure() {
    print_status "Checking project structure..."
    
    if [ ! -f "app/package.json" ]; then
        print_error "app/package.json not found!"
        exit 1
    fi
    
    if [ ! -f "app/server.js" ]; then
        print_error "app/server.js not found!"
        exit 1
    fi
    
    if [ ! -f "app/index.html" ]; then
        print_error "app/index.html not found!"
        exit 1
    fi
    
    print_success "Project structure looks good!"
}

# Build Docker image
build_image() {
    local tag=$1
    print_status "Building Docker image: bluegreen-demo:${tag}"
    
    docker build -t bluegreen-demo:${tag} .
    
    if [ $? -eq 0 ]; then
        print_success "Successfully built bluegreen-demo:${tag}"
    else
        print_error "Failed to build bluegreen-demo:${tag}"
        exit 1
    fi
}

# Main execution
main() {
    print_status "🔧 Testing Docker build after fixes..."
    
    # Check project structure
    check_structure
    
    # Build blue image
    build_image "blue"
    
    # Build green image  
    build_image "green"
    
    print_success "✅ All images built successfully!"
    
    echo ""
    echo "Available images:"
    docker images bluegreen-demo
    
    echo ""
    echo "Next steps:"
    echo "1. Restart pods: kubectl delete pods -l app=bluegreen-demo -n sbx"
    echo "2. Check status: kubectl get pods -n sbx"
    echo "3. Test app: kubectl port-forward service/bluegreen-demo-service 8080:80 -n sbx"
}

# Run the test
main
