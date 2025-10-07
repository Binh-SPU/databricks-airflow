#!/bin/bash
# Script to manually build and push Airflow image to Amazon ECR

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if required variables are set
if [ -z "$ECR_REGISTRY" ]; then
    echo -e "${RED}Error: ECR_REGISTRY environment variable is not set${NC}"
    echo "Example: export ECR_REGISTRY=123456789012.dkr.ecr.us-west-1.amazonaws.com"
    exit 1
fi

# Configuration
AWS_REGION=${AWS_REGION:-us-west-1}
IMAGE_NAME=${IMAGE_NAME:-my-dags}
IMAGE_TAG=${IMAGE_TAG:-$(date +%Y%m%d%H%M%S)}
DOCKERFILE=${DOCKERFILE:-cicd/Dockerfile}

echo -e "${YELLOW}=== Building and Pushing Airflow Image to ECR ===${NC}"
echo "Registry: $ECR_REGISTRY"
echo "Image: $IMAGE_NAME"
echo "Tag: $IMAGE_TAG"
echo "Region: $AWS_REGION"
echo ""

# Step 1: Login to ECR
echo -e "${YELLOW}[1/4] Logging in to Amazon ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $ECR_REGISTRY

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully logged in to ECR${NC}"
else
    echo -e "${RED}✗ Failed to login to ECR${NC}"
    exit 1
fi

# Step 2: Build the Docker image
echo -e "\n${YELLOW}[2/4] Building Docker image...${NC}"
docker build --pull \
    --tag $ECR_REGISTRY/$IMAGE_NAME:$IMAGE_TAG \
    --tag $ECR_REGISTRY/$IMAGE_NAME:latest \
    -f $DOCKERFILE .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Docker image built successfully${NC}"
else
    echo -e "${RED}✗ Failed to build Docker image${NC}"
    exit 1
fi

# Step 3: Push timestamped tag
echo -e "\n${YELLOW}[3/4] Pushing timestamped tag...${NC}"
docker push $ECR_REGISTRY/$IMAGE_NAME:$IMAGE_TAG

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Pushed $ECR_REGISTRY/$IMAGE_NAME:$IMAGE_TAG${NC}"
else
    echo -e "${RED}✗ Failed to push timestamped tag${NC}"
    exit 1
fi

# Step 4: Push latest tag
echo -e "\n${YELLOW}[4/4] Pushing latest tag...${NC}"
docker push $ECR_REGISTRY/$IMAGE_NAME:latest

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Pushed $ECR_REGISTRY/$IMAGE_NAME:latest${NC}"
else
    echo -e "${RED}✗ Failed to push latest tag${NC}"
    exit 1
fi

# Summary
echo -e "\n${GREEN}=== SUCCESS ===${NC}"
echo "Images pushed to ECR:"
echo "  • $ECR_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
echo "  • $ECR_REGISTRY/$IMAGE_NAME:latest"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Update chart/values-override-persistence.yaml with ECR image"
echo "2. Create Kubernetes secret for ECR (if using Kind):"
echo "   kubectl create secret docker-registry ecr-secret \\"
echo "     --namespace airflow \\"
echo "     --docker-server=$ECR_REGISTRY \\"
echo "     --docker-username=AWS \\"
echo "     --docker-password=\$(aws ecr get-login-password --region $AWS_REGION)"
echo ""
echo "3. Upgrade Airflow:"
echo "   helm upgrade airflow apache-airflow/airflow -n airflow \\"
echo "     -f chart/values-override-persistence.yaml \\"
echo "     --set images.airflow.repository=$ECR_REGISTRY/$IMAGE_NAME \\"
echo "     --set images.airflow.tag=$IMAGE_TAG"

