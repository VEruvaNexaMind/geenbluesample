#!/bin/bash

# Setup Script for Blue-Green Deployment on EKS
# This script sets up the initial environment

set -e

# Configuration
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

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed!"
        exit 1
    fi
    
    # Check aws cli
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed!"
        exit 1
    fi
    
    # Check docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed!"
        exit 1
    fi
    
    print_success "All prerequisites are installed!"
}

# Function to configure kubectl for EKS
# configure_kubectl() {
#     print_status "Configuring kubectl for EKS cluster: ${CLUSTER_NAME}..."
    
#     aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}
    
#     if [ $? -eq 0 ]; then
#         print_success "kubectl configured successfully!"
#     else
#         print_error "Failed to configure kubectl!"
#         exit 1
#     fi
# }

# Function to apply Kubernetes manifests
apply_manifests() {
    print_status "Applying Kubernetes manifests..."
    
    # Skip namespace creation since 'sbx' already exists
    # kubectl apply -f k8s/namespace.yaml
    
    # Apply services
    kubectl apply -f k8s/service.yaml
    kubectl apply -f k8s/service-blue.yaml
    kubectl apply -f k8s/service-green.yaml
    
    # Apply deployments
    kubectl apply -f k8s/deployment-blue.yaml
    kubectl apply -f k8s/deployment-green.yaml
    
    # Apply ingress
    kubectl apply -f k8s/ingress.yaml
    
    print_success "Kubernetes manifests applied successfully!"
}

# Function to wait for deployments
wait_for_deployments() {
    print_status "Waiting for deployments to be ready..."
    
    kubectl wait --for=condition=available deployment/bluegreen-demo-blue \
        -n ${NAMESPACE} --timeout=300s
    
    kubectl wait --for=condition=available deployment/bluegreen-demo-green \
        -n ${NAMESPACE} --timeout=300s
    
    print_success "All deployments are ready!"
}

# Function to show status
show_status() {
    print_status "Current deployment status:"
    echo ""
    
    echo "Namespace:"
    kubectl get namespace ${NAMESPACE}
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

# Main setup function
setup() {
    print_status "Starting Blue-Green Deployment setup for EKS..."
    
    check_prerequisites
    #configure_kubectl
    apply_manifests
    wait_for_deployments
    show_status
    
    print_success "Setup completed successfully!"
    print_status "You can now use the deployment scripts:"
    print_status "  - ./scripts/build-and-push.sh build"
    print_status "  - ./scripts/blue-green-deploy.sh deploy blue <image-tag>"
}

# Command line interface
case "$1" in
    "setup")
        setup
        ;;
    "status")
        show_status
        ;;
    "clean")
        print_status "Cleaning up resources..."
        kubectl delete namespace ${NAMESPACE} --ignore-not-found=true
        print_success "Cleanup completed!"
        ;;
    *)
        echo "Usage: $0 {setup|status|clean}"
        echo ""
        echo "Commands:"
        echo "  setup   - Set up the blue-green deployment environment"
        echo "  status  - Show current deployment status"
        echo "  clean   - Clean up all resources"
        exit 1
        ;;
esac
