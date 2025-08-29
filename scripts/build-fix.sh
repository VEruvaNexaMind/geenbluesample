#!/bin/bash

# Generate package-lock.json and build Docker images

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to generate package-lock.json
generate_package_lock() {
    print_status "Generating package-lock.json..."
    
    cd app
    
    # Generate package-lock.json
    npm install
    
    print_success "package-lock.json generated!"
    
    cd ..
}

# Function to build Docker images
build_images() {
    print_status "Building Docker images..."
    
    # Build blue version
    print_status "Building blue version..."
    docker build -t bluegreen-demo:blue .
    
    # Build green version
    print_status "Building green version..."
    docker build -t bluegreen-demo:green .
    
    print_success "Docker images built successfully!"
    
    echo "Available images:"
    docker images bluegreen-demo
}

# Main execution
main() {
    print_status "🔧 Fixing npm and building Docker images..."
    
    # Check if we're in the right directory
    if [ ! -f "Dockerfile" ]; then
        echo "Error: Dockerfile not found! Please run this script from the project root directory."
        exit 1
    fi
    
    # Generate package-lock.json
    generate_package_lock
    
    # Build Docker images
    build_images
    
    print_success "✅ Build completed successfully!"
    
    echo ""
    echo "Next steps:"
    echo "1. Restart pods: kubectl delete pods -l app=bluegreen-demo -n sbx"
    echo "2. Check status: kubectl get pods -n sbx"
    echo "3. Test app: kubectl port-forward service/bluegreen-demo-service 8080:80 -n sbx"
}

# Run the script
main
