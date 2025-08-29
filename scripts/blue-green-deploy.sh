#!/bin/bash

# Blue-Green Deployment Script for EKS
# This script automates the blue-green deployment process

set -e

# Configuration
NAMESPACE="sbx"
APP_NAME="bluegreen-demo"
LOCAL_IMAGE="bluegreen-demo"
CLUSTER_NAME="bluegreen-eks-sbx"
REGION="us-west-2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to get current active version
get_current_version() {
    kubectl get service ${APP_NAME}-service -n ${NAMESPACE} -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "none"
}

# Function to get inactive version
get_inactive_version() {
    current=$(get_current_version)
    if [ "$current" == "blue" ]; then
        echo "green"
    elif [ "$current" == "green" ]; then
        echo "blue"
    else
        echo "blue"  # Default to blue if no current version
    fi
}

# Function to check if deployment is ready
check_deployment_ready() {
    local version=$1
    print_status "Checking if ${version} deployment is ready..."
    
    kubectl wait --for=condition=available deployment/${APP_NAME}-${version} \
        -n ${NAMESPACE} --timeout=300s
    
    if [ $? -eq 0 ]; then
        print_success "${version} deployment is ready!"
        return 0
    else
        print_error "${version} deployment failed to become ready!"
        return 1
    fi
}

# Function to health check
health_check() {
    local version=$1
    print_status "Performing health check for ${version} version..."
    
    # Port forward to test the service
    kubectl port-forward service/${APP_NAME}-${version} 8080:80 -n ${NAMESPACE} &
    local port_forward_pid=$!
    
    sleep 5
    
    # Check health endpoint
    local health_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health || echo "000")
    
    # Kill port forward
    kill $port_forward_pid 2>/dev/null || true
    
    if [ "$health_status" == "200" ]; then
        print_success "Health check passed for ${version} version!"
        return 0
    else
        print_error "Health check failed for ${version} version! HTTP status: $health_status"
        return 1
    fi
}

# Function to switch traffic
switch_traffic() {
    local target_version=$1
    print_status "Switching traffic to ${target_version} version..."
    
    kubectl patch service ${APP_NAME}-service -n ${NAMESPACE} \
        -p '{"spec":{"selector":{"version":"'${target_version}'"}}}'
    
    if [ $? -eq 0 ]; then
        print_success "Traffic switched to ${target_version} version!"
        return 0
    else
        print_error "Failed to switch traffic to ${target_version} version!"
        return 1
    fi
}

# Function to rollback
rollback() {
    local rollback_version=$1
    print_warning "Rolling back to ${rollback_version} version..."
    
    switch_traffic $rollback_version
    
    if [ $? -eq 0 ]; then
        print_success "Rollback to ${rollback_version} completed!"
    else
        print_error "Rollback failed!"
        exit 1
    fi
}

# Main deployment function
deploy() {
    local new_version=$1
    local image_tag=$2
    
    if [ -z "$new_version" ] || [ -z "$image_tag" ]; then
        print_error "Usage: deploy <version> <image_tag>"
        exit 1
    fi
    
    print_status "Starting blue-green deployment..."
    print_status "Deploying version: ${new_version}"
    print_status "Image tag: ${image_tag}"
    
    local current_version=$(get_current_version)
    print_status "Current active version: ${current_version}"
    
    # Update the deployment with new image
    kubectl set image deployment/${APP_NAME}-${new_version} \
        ${APP_NAME}=${LOCAL_IMAGE}:${image_tag} -n ${NAMESPACE}
    
    # Wait for deployment to be ready
    if ! check_deployment_ready $new_version; then
        print_error "Deployment failed!"
        exit 1
    fi
    
    # Perform health check
    if ! health_check $new_version; then
        print_error "Health check failed!"
        exit 1
    fi
    
    # Switch traffic
    if ! switch_traffic $new_version; then
        print_error "Traffic switching failed!"
        exit 1
    fi
    
    # Final verification
    sleep 10
    if ! health_check $new_version; then
        print_warning "Post-deployment health check failed! Rolling back..."
        rollback $current_version
        exit 1
    fi
    
    print_success "Blue-green deployment completed successfully!"
    print_success "Active version is now: ${new_version}"
}

# Command line interface
case "$1" in
    "deploy")
        deploy $2 $3
        ;;
    "status")
        current_version=$(get_current_version)
        inactive_version=$(get_inactive_version)
        echo "Current active version: $current_version"
        echo "Inactive version: $inactive_version"
        ;;
    "switch")
        target_version=$2
        if [ -z "$target_version" ]; then
            target_version=$(get_inactive_version)
        fi
        switch_traffic $target_version
        ;;
    "rollback")
        current_version=$(get_current_version)
        if [ "$current_version" == "blue" ]; then
            rollback "green"
        else
            rollback "blue"
        fi
        ;;
    "health")
        version=${2:-$(get_current_version)}
        health_check $version
        ;;
    *)
        echo "Usage: $0 {deploy|status|switch|rollback|health}"
        echo ""
        echo "Commands:"
        echo "  deploy <version> <image_tag>  - Deploy new version"
        echo "  status                        - Show current deployment status"
        echo "  switch [version]             - Switch traffic to specified version"
        echo "  rollback                     - Rollback to previous version"
        echo "  health [version]             - Check health of specified version"
        exit 1
        ;;
esac
