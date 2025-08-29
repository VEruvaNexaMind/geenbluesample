#!/bin/bash

# COMPLETE BLUE-GREEN DEPLOYMENT SETUP
# This single script does everything you need

set -e

# Configuration for your existing setup
NAMESPACE="sbx"
CLUSTER_NAME="bluegreen-eks-sbx"
REGION="us-west-2"
ECR_REPO_NAME="bluegreen-demo"
# Use your specified AWS account ID and profile
AWS_ACCOUNT_ID="423623850112"
AWS_PROFILE="sbx-rnd"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_step() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}STEP $1: $2${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Check prerequisites
check_prerequisites() {
    print_step "1" "Checking Prerequisites"
    
    local missing=()
    
    if ! command -v kubectl &> /dev/null; then
        missing+=("kubectl")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing[*]}"
        exit 1
    fi
    
    print_status "Checking if namespace '${NAMESPACE}' exists..."
    if ! kubectl get namespace ${NAMESPACE} &> /dev/null; then
        print_error "Namespace '${NAMESPACE}' not found! Please ensure your EKS cluster is configured and the namespace exists."
        exit 1
    fi
    
    print_success "All prerequisites are installed and namespace verified!"
}

# Step 2: Build and push Docker images to ECR
build_images() {
    print_step "2" "Building and Pushing Docker Images to ECR"
    
    print_status "Building blue version with VERSION=blue..."
    docker build --build-arg VERSION=blue -t bluegreen-demo:blue .
    
    print_status "Building green version with VERSION=green..."
    docker build --build-arg VERSION=green -t bluegreen-demo:green .
    
    print_status "Logging into ECR..."
    aws ecr get-login-password --region ${REGION} --profile ${AWS_PROFILE} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com
    
    # Verify ECR repository exists and is accessible
    print_status "Verifying ECR repository access..."
    if ! aws ecr describe-repositories --repository-names ${ECR_REPO_NAME} --region ${REGION} --profile ${AWS_PROFILE} &>/dev/null; then
        print_status "ECR repository '${ECR_REPO_NAME}' not found. Creating it..."
        aws ecr create-repository --repository-name ${ECR_REPO_NAME} --region ${REGION} --profile ${AWS_PROFILE}
        print_success "ECR repository created successfully!"
    else
        print_success "ECR repository '${ECR_REPO_NAME}' found and accessible!"
    fi
    
    print_status "Tagging images for ECR..."
    docker tag bluegreen-demo:blue ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO_NAME}:blue
    docker tag bluegreen-demo:green ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO_NAME}:green
    
    print_status "Pushing blue image to ECR..."
    if ! docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO_NAME}:blue; then
        print_error "Failed to push blue image. Check your ECR permissions and repository access."
        print_status "Debugging info:"
        echo "  Account ID: ${AWS_ACCOUNT_ID}"
        echo "  Region: ${REGION}"
        echo "  Repository: ${ECR_REPO_NAME}"
        echo "  Full image URL: ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO_NAME}:blue"
        exit 1
    fi
    
    print_status "Pushing green image to ECR..."
    if ! docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO_NAME}:green; then
        print_error "Failed to push green image. Check your ECR permissions and repository access."
        exit 1
    fi
    
    print_success "Docker images built and pushed to ECR successfully!"
    print_status "Images are now truly different - blue contains blue styling, green contains green styling!"
}

# Step 3: Deploy to Kubernetes
deploy_to_kubernetes() {
    print_step "3" "Deploying to Kubernetes"
    
    print_status "Deploying services..."
    kubectl apply -f k8s/service.yaml
    kubectl apply -f k8s/service-blue.yaml
    kubectl apply -f k8s/service-green.yaml
    
    print_status "Deploying applications..."
    kubectl apply -f k8s/deployment-blue.yaml
    kubectl apply -f k8s/deployment-green.yaml
    
    print_status "Deploying ingress..."
    kubectl apply -f k8s/ingress.yaml
    
    print_success "All resources deployed!"
}

# Step 4: Wait for deployments
wait_for_deployments() {
    print_step "4" "Waiting for Deployments"
    
    print_status "Waiting for blue deployment..."
    kubectl wait --for=condition=available deployment/bluegreen-demo-blue -n ${NAMESPACE} --timeout=300s
    
    print_status "Waiting for green deployment..."
    kubectl wait --for=condition=available deployment/bluegreen-demo-green -n ${NAMESPACE} --timeout=300s
    
    print_success "All deployments are ready!"
}

# Step 5: Show final status
show_status() {
    print_step "5" "Final Status Check"
    
    echo -e "\n${YELLOW}=== DEPLOYMENTS ===${NC}"
    kubectl get deployments -n ${NAMESPACE}
    
    echo -e "\n${YELLOW}=== SERVICES ===${NC}"
    kubectl get services -n ${NAMESPACE}
    
    echo -e "\n${YELLOW}=== PODS ===${NC}"
    kubectl get pods -n ${NAMESPACE}
    
    echo -e "\n${YELLOW}=== INGRESS ===${NC}"
    kubectl get ingress -n ${NAMESPACE}
}

# Step 6: Test application
test_application() {
    print_step "6" "Testing Application"
    
    kubectl port-forward service/bluegreen-demo-service 8080:80 -n ${NAMESPACE} &
    local pid=$!
    
    sleep 5
    
    if curl -s http://localhost:8080/health > /dev/null; then
        print_success "✅ Application is working!"
        echo "Response:"
        curl -s http://localhost:8080/health
    else
        print_error "❌ Application not responding"
    fi
    
    kill $pid 2>/dev/null || true
}

# Main execution
main() {
    echo -e "${GREEN}"
    echo "██████╗ ██╗     ██╗   ██╗███████╗      ██████╗ ██████╗ ███████╗███████╗███╗   ██╗"
    echo "██╔══██╗██║     ██║   ██║██╔════╝     ██╔════╝ ██╔══██╗██╔════╝██╔════╝████╗  ██║"
    echo "██████╔╝██║     ██║   ██║█████╗       ██║  ███╗██████╔╝█████╗  █████╗  ██╔██╗ ██║"
    echo "██╔══██╗██║     ██║   ██║██╔══╝       ██║   ██║██╔══██╗██╔══╝  ██╔══╝  ██║╚██╗██║"
    echo "██████╔╝███████╗╚██████╔╝███████╗     ╚██████╔╝██║  ██║███████╗███████╗██║ ╚████║"
    echo "╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝      ╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═══╝"
    echo -e "${NC}"
    echo "🚀 Blue-Green Deployment Setup Starting..."
    echo "=================================="

    check_prerequisites
    build_images
    deploy_to_kubernetes
    wait_for_deployments
    show_status
    test_application
    
    echo -e "\n${GREEN}🎉 DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉${NC}"
    echo ""
    echo "📋 How to access your application:"
    echo ""
    echo "🔗 Option 1 - Port Forward (Quick Test):"
    echo "   kubectl port-forward service/bluegreen-demo-service 8080:80 -n ${NAMESPACE}"
    echo "   Then open: http://localhost:8080"
    echo ""
    echo "🌐 Option 2 - Ingress (if ALB Controller is installed):"
    echo "   kubectl get ingress bluegreen-demo-ingress -n ${NAMESPACE}"
    echo "   Look for the ADDRESS column for the ALB DNS name"
    echo ""
    echo "🔄 Blue-Green Operations:"
    echo ""
    echo "🔄 Switch to green version:"
    echo "   kubectl patch service bluegreen-demo-service -n ${NAMESPACE} -p '{\"spec\":{\"selector\":{\"version\":\"green\"}}}'"
    echo ""
    echo "🔄 Switch back to blue version:"
    echo "   kubectl patch service bluegreen-demo-service -n ${NAMESPACE} -p '{\"spec\":{\"selector\":{\"version\":\"blue\"}}}'"
    echo ""
    echo "📊 Check status anytime:"
    echo "   kubectl get all -n ${NAMESPACE}"
    echo ""
    echo "🧹 Clean up when done:"
    echo "   kubectl delete -f k8s/ || true"
}

main
