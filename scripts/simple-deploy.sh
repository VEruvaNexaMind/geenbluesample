#!/bin/bash

# Simple Deployment Script for Existing EKS Setup
# This script deploys blue-green applications to your existing "sbx" namespace

set -e

# Configuration for your existing setup
NAMESPACE="sbx"
CLUSTER_NAME="bluegreen-eks-sbx"
REGION="us-west-2"

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

# Function to build Docker images
build_images() {
    print_status "Building Docker images..."
    
    # Build blue version
    docker build -t bluegreen-demo:blue .
    
    # Build green version
    docker build -t bluegreen-demo:green .
    
    print_success "Docker images built successfully!"
    docker images bluegreen-demo
}

# Function to deploy applications
deploy_applications() {
    print_status "Deploying applications to namespace: ${NAMESPACE}"
    
    # Deploy services
    kubectl apply -f k8s/service.yaml
    kubectl apply -f k8s/service-blue.yaml
    kubectl apply -f k8s/service-green.yaml
    
    # Deploy blue deployment
    kubectl apply -f k8s/deployment-blue.yaml
    
    # Deploy green deployment
    kubectl apply -f k8s/deployment-green.yaml
    
    # Deploy ingress
    kubectl apply -f k8s/ingress.yaml
    
    print_success "Applications deployed successfully!"
}

# Function to wait for deployments
wait_for_deployments() {
    print_status "Waiting for deployments to be ready..."
    
    kubectl wait --for=condition=available deployment/bluegreen-demo-blue -n ${NAMESPACE} --timeout=300s
    kubectl wait --for=condition=available deployment/bluegreen-demo-green -n ${NAMESPACE} --timeout=300s
    
    print_success "All deployments are ready!"
}

# Function to show status
show_status() {
    print_status "Current deployment status in namespace: ${NAMESPACE}"
    echo ""
    
    echo "Deployments:"
    kubectl get deployments -n ${NAMESPACE}
    echo ""
    
    echo "Services:"
    kubectl get services -n ${NAMESPACE}
    echo ""
    
    echo "Pods:"
    kubectl get pods -n ${NAMESPACE}
    echo ""
    
    echo "Ingress:"
    kubectl get ingress -n ${NAMESPACE}
}

# Function to test application
test_application() {
    print_status "Testing application..."
    
    # Port forward to test
    kubectl port-forward service/bluegreen-demo-service 8080:80 -n ${NAMESPACE} &
    local port_forward_pid=$!
    
    sleep 5
    
    # Test health endpoint
    if curl -s http://localhost:8080/health > /dev/null; then
        print_success "Application is responding!"
        curl -s http://localhost:8080/health | jq . || curl -s http://localhost:8080/health
    else
        print_error "Application is not responding!"
    fi
    
    # Kill port forward
    kill $port_forward_pid 2>/dev/null || true
}

# Main execution
main() {
    print_status "Starting Blue-Green Deployment to existing EKS setup"
    print_status "Namespace: ${NAMESPACE}"
    print_status "Cluster: ${CLUSTER_NAME}"
    
    # Configure kubectl
    aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}
    
    # Build images
    build_images
    
    # Deploy applications
    deploy_applications
    
    # Wait for deployments
    wait_for_deployments
    
    # Show status
    show_status
    
    # Test application
    test_application
    
    print_success "Deployment completed successfully!"
    
    echo ""
    echo "Next steps:"
    echo "1. Access application: kubectl port-forward service/bluegreen-demo-service 8080:80 -n ${NAMESPACE}"
    echo "2. Test in browser: http://localhost:8080"
    echo "3. Switch traffic: kubectl patch service bluegreen-demo-service -n ${NAMESPACE} -p '{\"spec\":{\"selector\":{\"version\":\"green\"}}}'"
}

# Command line interface
case "$1" in
    "deploy")
        main
        ;;
    "status")
        show_status
        ;;
    "test")
        test_application
        ;;
    "switch-blue")
        kubectl patch service bluegreen-demo-service -n ${NAMESPACE} -p '{"spec":{"selector":{"version":"blue"}}}'
        print_success "Switched traffic to blue!"
        ;;
    "switch-green")
        kubectl patch service bluegreen-demo-service -n ${NAMESPACE} -p '{"spec":{"selector":{"version":"green"}}}'
        print_success "Switched traffic to green!"
        ;;
    *)
        echo "Usage: $0 {deploy|status|test|switch-blue|switch-green}"
        echo ""
        echo "Commands:"
        echo "  deploy       - Build images and deploy applications"
        echo "  status       - Show current deployment status"
        echo "  test         - Test application connectivity"
        echo "  switch-blue  - Switch traffic to blue version"
        echo "  switch-green - Switch traffic to green version"
        exit 1
        ;;
esac
