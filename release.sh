#!/bin/bash
set -e

# Configuration
FRONTEND_IMAGE_NAME="agents/frontend"
BACKEND_IMAGE_NAME="agents/backend"
IMAGE_TAG="latest"
ECR_URL="654553612832.dkr.ecr.eu-central-1.amazonaws.com"
AWS_REGION="eu-central-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists docker; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists aws; then
        print_error "AWS CLI is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists pnpm; then
        print_warning "pnpm not found, will use npm for frontend build"
    fi
    
    print_success "Prerequisites check passed"
}

# Function to build and upload frontend
build_and_upload_frontend() {
    print_status "Building and uploading frontend image..."
    
    cd frontend
    
    # Backup the original .env.local file if it exists
    if [ -f .env.local ]; then
        cp .env.local .env.local.backup
        print_status "Backed up .env.local"
    fi
    
    # Clean previous build
    # rm -rf ./dist ./out ./.next
    
    # # Create/modify the .env.local file with new values
    # echo "VITE_API_URL=https://core-dev.is.directout.eu" > .env.local
    
    # Build the frontend
    # print_status "Building frontend..."
    # if command_exists pnpm; then
    #     pnpm build
    # else
    #     npm run build
    # fi
    
    # Build Docker image
    print_status "Building frontend Docker image..."
    docker buildx build --platform linux/amd64 --load -t "$FRONTEND_IMAGE_NAME:$IMAGE_TAG" .
    
    # Login to ECR
    print_status "Logging in to ECR..."
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "$ECR_URL"
    
    # Tag and push
    print_status "Tagging and pushing frontend image..."
    docker tag "$FRONTEND_IMAGE_NAME:$IMAGE_TAG" "$ECR_URL/$FRONTEND_IMAGE_NAME:$IMAGE_TAG"
    docker push "$ECR_URL/$FRONTEND_IMAGE_NAME:$IMAGE_TAG"
    
    # Restore the original .env.local file
    if [ -f .env.local.backup ]; then
        mv .env.local.backup .env.local
        print_status "Restored .env.local"
    fi
    
    cd ..
    print_success "Frontend image uploaded successfully"
}

# Function to build and upload backend
build_and_upload_backend() {
    print_status "Building and uploading backend image..."
    
    cd backend
    
    # Build Docker image
    print_status "Building backend Docker image..."
    docker buildx build --platform linux/amd64 --load -t "$BACKEND_IMAGE_NAME:$IMAGE_TAG" .
    
    # Login to ECR (if not already logged in)
    print_status "Ensuring ECR login..."
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "$ECR_URL"
    
    # Tag and push
    print_status "Tagging and pushing backend image..."
    docker tag "$BACKEND_IMAGE_NAME:$IMAGE_TAG" "$ECR_URL/$BACKEND_IMAGE_NAME:$IMAGE_TAG"
    docker push "$ECR_URL/$BACKEND_IMAGE_NAME:$IMAGE_TAG"
    
    cd ..
    print_success "Backend image uploaded successfully"
}

# Function to clean up local images
cleanup_local_images() {
    print_status "Cleaning up local images..."
    
    # Remove local images to free up space
    docker rmi "$FRONTEND_IMAGE_NAME:$IMAGE_TAG" 2>/dev/null || true
    docker rmi "$BACKEND_IMAGE_NAME:$IMAGE_TAG" 2>/dev/null || true
    docker rmi "$ECR_URL/$FRONTEND_IMAGE_NAME:$IMAGE_TAG" 2>/dev/null || true
    docker rmi "$ECR_URL/$BACKEND_IMAGE_NAME:$IMAGE_TAG" 2>/dev/null || true
    
    print_success "Local images cleaned up"
}

# Function to display image information
display_image_info() {
    print_status "Image information:"
    echo "Frontend: $ECR_URL/$FRONTEND_IMAGE_NAME:$IMAGE_TAG"
    echo "Backend: $ECR_URL/$BACKEND_IMAGE_NAME:$IMAGE_TAG"
    echo "Region: $AWS_REGION"
}

# Main execution
main() {
    print_status "Starting image upload process..."
    
    # Check prerequisites
    check_prerequisites
    
    # Display configuration
    display_image_info
    
    # Build and upload frontend
    build_and_upload_frontend
    
    # Build and upload backend
    build_and_upload_backend
    
    # Cleanup
    cleanup_local_images
    
    print_success "All images uploaded successfully!"
    print_status "You can now use these images in your deployment."
}

# Handle script arguments
case "${1:-}" in
    --frontend-only)
        print_status "Building and uploading frontend only..."
        check_prerequisites
        build_and_upload_frontend
        cleanup_local_images
        print_success "Frontend image uploaded successfully!"
        ;;
    --backend-only)
        print_status "Building and uploading backend only..."
        check_prerequisites
        build_and_upload_backend
        cleanup_local_images
        print_success "Backend image uploaded successfully!"
        ;;
    --help|-h)
        echo "Usage: $0 [OPTION]"
        echo ""
        echo "Options:"
        echo "  --frontend-only    Build and upload only the frontend image"
        echo "  --backend-only     Build and upload only the backend image"
        echo "  --help, -h         Show this help message"
        echo ""
        echo "Default behavior: Build and upload both frontend and backend images"
        exit 0
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac 