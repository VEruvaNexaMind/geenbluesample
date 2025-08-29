#!/bin/bash

# Load Local Docker Images to EKS Nodes
# This script loads local Docker images to EKS worker nodes for local development

set -e

# Configuration
LOCAL_IMAGE="bluegreen-demo"
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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to get EKS worker node IPs
get_worker_nodes() {
    print_status "Getting EKS worker node information..."
    kubectl get nodes -o wide --no-headers | awk '{print $1 " " $7}'
}

# Function to save Docker image to tar file
save_image() {
    local image_tag=$1
    local tar_file="${LOCAL_IMAGE}-${image_tag}.tar"
    
    print_status "Saving Docker image ${LOCAL_IMAGE}:${image_tag} to ${tar_file}..."
    
    docker save ${LOCAL_IMAGE}:${image_tag} -o ${tar_file}
    
    if [ $? -eq 0 ]; then
        print_success "Image saved to ${tar_file}"
        echo ${tar_file}
    else
        print_error "Failed to save image!"
        exit 1
    fi
}

# Function to load image to a node using kubectl cp and docker load
load_image_to_node() {
    local node_name=$1
    local tar_file=$2
    local image_tag=$3
    
    print_status "Loading image to node: ${node_name}..."
    
    # Create a temporary pod on the specific node
    local pod_name="image-loader-$(date +%s)"
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${pod_name}
  namespace: default
spec:
  nodeSelector:
    kubernetes.io/hostname: ${node_name}
  containers:
  - name: image-loader
    image: docker:dind
    securityContext:
      privileged: true
    volumeMounts:
    - name: docker-socket
      mountPath: /var/run/docker.sock
    command: ["sleep", "300"]
  volumes:
  - name: docker-socket
    hostPath:
      path: /var/run/docker.sock
  restartPolicy: Never
EOF

    # Wait for pod to be ready
    kubectl wait --for=condition=Ready pod/${pod_name} --timeout=60s
    
    # Copy tar file to pod
    kubectl cp ${tar_file} ${pod_name}:/tmp/${tar_file}
    
    # Load image in the pod (which loads it on the node)
    kubectl exec ${pod_name} -- docker load -i /tmp/${tar_file}
    
    # Verify image is loaded
    kubectl exec ${pod_name} -- docker images ${LOCAL_IMAGE}
    
    # Clean up
    kubectl delete pod ${pod_name}
    
    print_success "Image loaded to node: ${node_name}"
}

# Function to load images to all nodes
load_to_all_nodes() {
    local image_tag=$1
    
    if [ -z "$image_tag" ]; then
        print_error "Please provide image tag!"
        echo "Usage: $0 load <image_tag>"
        exit 1
    fi
    
    # Check if image exists locally
    if ! docker images ${LOCAL_IMAGE}:${image_tag} --format "table {{.Repository}}:{{.Tag}}" | grep -q "${LOCAL_IMAGE}:${image_tag}"; then
        print_error "Image ${LOCAL_IMAGE}:${image_tag} not found locally!"
        print_status "Available images:"
        docker images ${LOCAL_IMAGE}
        exit 1
    fi
    
    # Save image to tar file
    local tar_file=$(save_image ${image_tag})
    
    # Get worker nodes
    print_status "Getting worker nodes for cluster: ${CLUSTER_NAME}"
    local nodes=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name")
    
    if [ -z "$nodes" ]; then
        print_error "No worker nodes found!"
        exit 1
    fi
    
    print_status "Found nodes:"
    echo "$nodes"
    
    # Load image to each node
    for node in $nodes; do
        load_image_to_node $node $tar_file $image_tag
    done
    
    # Clean up tar file
    rm -f ${tar_file}
    
    print_success "Image ${LOCAL_IMAGE}:${image_tag} loaded to all nodes!"
}

# Function to check images on nodes
check_images() {
    print_status "Checking ${LOCAL_IMAGE} images on all nodes..."
    
    local nodes=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name")
    
    for node in $nodes; do
        print_status "Checking node: ${node}"
        
        # Create temporary pod to check images
        local pod_name="image-checker-$(date +%s)"
        
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${pod_name}
  namespace: default
spec:
  nodeSelector:
    kubernetes.io/hostname: ${node}
  containers:
  - name: image-checker
    image: docker:dind
    securityContext:
      privileged: true
    volumeMounts:
    - name: docker-socket
      mountPath: /var/run/docker.sock
    command: ["sleep", "60"]
  volumes:
  - name: docker-socket
    hostPath:
      path: /var/run/docker.sock
  restartPolicy: Never
EOF

        kubectl wait --for=condition=Ready pod/${pod_name} --timeout=60s
        kubectl exec ${pod_name} -- docker images ${LOCAL_IMAGE} || true
        kubectl delete pod ${pod_name}
        echo ""
    done
}

# Main function
main() {
    print_status "EKS Local Image Loader"
    print_status "Cluster: ${CLUSTER_NAME}"
    print_status "Image: ${LOCAL_IMAGE}"
    
    # Configure kubectl
    aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}
}

# Command line interface
case "$1" in
    "load")
        main
        load_to_all_nodes $2
        ;;
    "check")
        main
        check_images
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 {load|check|help}"
        echo ""
        echo "Commands:"
        echo "  load <image_tag>  - Load local Docker image to all EKS nodes"
        echo "  check            - Check what images are available on nodes"
        echo "  help             - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 load blue      # Load bluegreen-demo:blue to all nodes"
        echo "  $0 load v1.0.0    # Load bluegreen-demo:v1.0.0 to all nodes"
        echo "  $0 check          # Check available images on all nodes"
        ;;
    *)
        echo "Usage: $0 {load|check|help}"
        echo "Use '$0 help' for more information."
        exit 1
        ;;
esac
