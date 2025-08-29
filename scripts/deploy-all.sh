#!/bin/bash

# Deploy Services and Deployments for Blue-Green Setup
# For existing EKS cluster with "sbx" namespace

set -e

NAMESPACE="sbx"
CLUSTER_NAME="bluegreen-eks-sbx"
REGION="us-west-2"

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

deploy_services() {
    print_status "Deploying all services to namespace: ${NAMESPACE}"
    
    echo "1. Deploying main service (traffic router)..."
    kubectl apply -f k8s/service.yaml
    
    echo "2. Deploying blue service..."
    kubectl apply -f k8s/service-blue.yaml
    
    echo "3. Deploying green service..."
    kubectl apply -f k8s/service-green.yaml
    
    print_success "All services deployed!"
    kubectl get services -n ${NAMESPACE}
}

deploy_applications() {
    print_status "Deploying blue and green applications..."
    
    echo "1. Deploying blue deployment..."
    kubectl apply -f k8s/deployment-blue.yaml
    
    echo "2. Deploying green deployment..."
    kubectl apply -f k8s/deployment-green.yaml
    
    print_success "All deployments created!"
    kubectl get deployments -n ${NAMESPACE}
}

deploy_ingress() {
    print_status "Deploying ingress..."
    
    kubectl apply -f k8s/ingress.yaml
    
    print_success "Ingress deployed!"
    kubectl get ingress -n ${NAMESPACE}
}

wait_for_ready() {
    print_status "Waiting for deployments to be ready..."
    
    kubectl wait --for=condition=available deployment/bluegreen-demo-blue -n ${NAMESPACE} --timeout=300s
    kubectl wait --for=condition=available deployment/bluegreen-demo-green -n ${NAMESPACE} --timeout=300s
    
    print_success "All deployments are ready!"
}

show_status() {
    print_status "Current status in namespace: ${NAMESPACE}"
    echo ""
    
    echo "=== SERVICES ==="
    kubectl get services -n ${NAMESPACE}
    echo ""
    
    echo "=== DEPLOYMENTS ==="
    kubectl get deployments -n ${NAMESPACE}
    echo ""
    
    echo "=== PODS ==="
    kubectl get pods -n ${NAMESPACE}
    echo ""
    
    echo "=== INGRESS ==="
    kubectl get ingress -n ${NAMESPACE}
    echo ""
    
    echo "=== ENDPOINTS ==="
    kubectl get endpoints -n ${NAMESPACE}
}

test_services() {
    print_status "Testing services..."
    
    # Test main service
    echo "Testing main service (port 8080)..."
    kubectl port-forward service/bluegreen-demo-service 8080:80 -n ${NAMESPACE} &
    local main_pid=$!
    sleep 3
    
    if curl -s http://localhost:8080/health > /dev/null; then
        print_success "Main service is responding!"
    else
        print_warning "Main service not responding yet"
    fi
    
    kill $main_pid 2>/dev/null || true
    
    # Test blue service
    echo "Testing blue service (port 8081)..."
    kubectl port-forward service/bluegreen-demo-blue 8081:80 -n ${NAMESPACE} &
    local blue_pid=$!
    sleep 3
    
    if curl -s http://localhost:8081/health > /dev/null; then
        print_success "Blue service is responding!"
    else
        print_warning "Blue service not responding yet"
    fi
    
    kill $blue_pid 2>/dev/null || true
    
    # Test green service
    echo "Testing green service (port 8082)..."
    kubectl port-forward service/bluegreen-demo-green 8082:80 -n ${NAMESPACE} &
    local green_pid=$!
    sleep 3
    
    if curl -s http://localhost:8082/health > /dev/null; then
        print_success "Green service is responding!"
    else
        print_warning "Green service not responding yet"
    fi
    
    kill $green_pid 2>/dev/null || true
}

# Main execution
main() {
    print_status "Deploying Blue-Green Services and Deployments"
    print_status "Namespace: ${NAMESPACE}"
    print_status "Cluster: ${CLUSTER_NAME}"
    
    # Configure kubectl
    aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}
    
    # Check if namespace exists
    if ! kubectl get namespace ${NAMESPACE} &> /dev/null; then
        print_warning "Namespace ${NAMESPACE} not found!"
        echo "Please create the namespace first: kubectl create namespace ${NAMESPACE}"
        exit 1
    fi
    
    # Deploy everything
    deploy_services
    deploy_applications
    deploy_ingress
    wait_for_ready
    show_status
    test_services
    
    print_success "Deployment completed successfully!"
    
    echo ""
    echo "Next steps:"
    echo "1. Test application: kubectl port-forward service/bluegreen-demo-service 8080:80 -n ${NAMESPACE}"
    echo "2. Switch to green: kubectl patch service bluegreen-demo-service -n ${NAMESPACE} -p '{\"spec\":{\"selector\":{\"version\":\"green\"}}}'"
    echo "3. Switch to blue: kubectl patch service bluegreen-demo-service -n ${NAMESPACE} -p '{\"spec\":{\"selector\":{\"version\":\"blue\"}}}'"
}

# Command line interface
case "$1" in
    "services")
        deploy_services
        ;;
    "deployments")
        deploy_applications
        ;;
    "ingress")
        deploy_ingress
        ;;
    "all"|"")
        main
        ;;
    "status")
        show_status
        ;;
    "test")
        test_services
        ;;
    "switch-blue")
        kubectl patch service bluegreen-demo-service -n ${NAMESPACE} -p '{"spec":{"selector":{"version":"blue"}}}'
        print_success "Switched traffic to BLUE!"
        ;;
    "switch-green")
        kubectl patch service bluegreen-demo-service -n ${NAMESPACE} -p '{"spec":{"selector":{"version":"green"}}}'
        print_success "Switched traffic to GREEN!"
        ;;
    *)
        echo "Usage: $0 {all|services|deployments|ingress|status|test|switch-blue|switch-green}"
        echo ""
        echo "Commands:"
        echo "  all          - Deploy everything (default)"
        echo "  services     - Deploy only services"
        echo "  deployments  - Deploy only applications"
        echo "  ingress      - Deploy only ingress"
        echo "  status       - Show current status"
        echo "  test         - Test all services"
        echo "  switch-blue  - Switch traffic to blue"
        echo "  switch-green - Switch traffic to green"
        exit 1
        ;;
esac
