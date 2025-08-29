#!/bin/bash

# Quick Fix Script for ErrImageNeverPull Issue

set -e

NAMESPACE="sbx"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to build Docker images
build_images() {
    print_status "Building Docker images..."
    
    print_status "Building blue version..."
    docker build -t bluegreen-demo:blue .
    
    print_status "Building green version..."
    docker build -t bluegreen-demo:green .
    
    print_success "Docker images built successfully!"
    
    echo "Available images:"
    docker images bluegreen-demo
}

# Function to restart deployments
restart_deployments() {
    print_status "Restarting deployments to pick up new images..."
    
    # Delete current pods
    kubectl delete pods -l app=bluegreen-demo -n ${NAMESPACE}
    
    print_success "Pods deleted. New pods will start automatically."
    
    # Wait a moment for new pods to be created
    sleep 5
    
    print_status "Current pod status:"
    kubectl get pods -n ${NAMESPACE}
}

# Function to wait for pods to be ready
wait_for_pods() {
    print_status "Waiting for pods to be ready..."
    
    # Wait for deployments to be available
    kubectl wait --for=condition=available deployment/bluegreen-demo-blue -n ${NAMESPACE} --timeout=300s
    kubectl wait --for=condition=available deployment/bluegreen-demo-green -n ${NAMESPACE} --timeout=300s
    
    print_success "All deployments are now ready!"
}

# Function to show final status
show_status() {
    print_status "Final status:"
    
    echo "Pods:"
    kubectl get pods -n ${NAMESPACE}
    echo ""
    
    echo "Deployments:"
    kubectl get deployments -n ${NAMESPACE}
    echo ""
    
    echo "Services:"
    kubectl get services -n ${NAMESPACE}
}

# Function to test the application
test_app() {
    print_status "Testing the application..."
    
    kubectl port-forward service/bluegreen-demo-service 8080:80 -n ${NAMESPACE} &
    local pid=$!
    
    sleep 5
    
    if curl -s http://localhost:8080/health > /dev/null; then
        print_success "Application is responding!"
        echo "Response:"
        curl -s http://localhost:8080/health | jq . 2>/dev/null || curl -s http://localhost:8080/health
    else
        print_warning "Application not responding yet. It might still be starting up."
    fi
    
    kill $pid 2>/dev/null || true
}

# Main execution
main() {
    print_status "🔧 Fixing ErrImageNeverPull issue..."
    
    # Check if we're in the right directory
    if [ ! -f "Dockerfile" ]; then
        print_error "Dockerfile not found! Please run this script from the project root directory."
        exit 1
    fi
    
    # Build images
    build_images
    
    # Restart deployments
    restart_deployments
    
    # Wait for pods to be ready
    wait_for_pods
    
    # Show status
    show_status
    
    # Test application
    test_app
    
    print_success "✅ Fix completed! Your application should now be running."
    
    echo ""
    echo "Next steps:"
    echo "1. Test application: kubectl port-forward service/bluegreen-demo-service 8080:80 -n ${NAMESPACE}"
    echo "2. Open browser: http://localhost:8080"
    echo "3. Switch versions: kubectl patch service bluegreen-demo-service -n ${NAMESPACE} -p '{\"spec\":{\"selector\":{\"version\":\"green\"}}}'"
}

# Run the fix
main
