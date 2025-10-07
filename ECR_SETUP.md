# Amazon ECR Setup Guide

## Prerequisites

1. AWS Account with ECR access
2. AWS CLI installed and configured
3. GitHub repository secrets configured

## 1. Create ECR Repository (One-time setup)

```bash
# Set your AWS region
export AWS_REGION=us-west-1
export ECR_REPO_NAME=my-dags

# Create ECR repository
aws ecr create-repository \
    --repository-name $ECR_REPO_NAME \
    --region $AWS_REGION \
    --image-scanning-configuration scanOnPush=true

# Note the "repositoryUri" from the output - this is your ECR_REGISTRY
# Format: <account-id>.dkr.ecr.<region>.amazonaws.com
```

## 2. Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:

- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `ECR_REGISTRY`: Your ECR registry URL (e.g., `123456789012.dkr.ecr.us-west-1.amazonaws.com`)

## 3. Manual Push to ECR (for testing)

```bash
# Set variables
export AWS_REGION=us-west-1
export ECR_REGISTRY=<your-account-id>.dkr.ecr.us-west-1.amazonaws.com
export IMAGE_NAME=my-dags
export IMAGE_TAG=$(date +%Y%m%d%H%M%S)

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $ECR_REGISTRY

# Build the image
docker build --pull \
    --tag $ECR_REGISTRY/$IMAGE_NAME:$IMAGE_TAG \
    --tag $ECR_REGISTRY/$IMAGE_NAME:latest \
    -f cicd/Dockerfile .

# Push to ECR
docker push $ECR_REGISTRY/$IMAGE_NAME:$IMAGE_TAG
docker push $ECR_REGISTRY/$IMAGE_NAME:latest

echo "Image pushed successfully!"
echo "Image: $ECR_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
echo "Image: $ECR_REGISTRY/$IMAGE_NAME:latest"
```

## 4. Update Airflow to Use ECR Image

### For Local Development (Kind)

You need to create an image pull secret for ECR:

```bash
# Create ECR credentials for Kubernetes
kubectl create secret docker-registry ecr-secret \
    --namespace airflow \
    --docker-server=$ECR_REGISTRY \
    --docker-username=AWS \
    --docker-password=$(aws ecr get-login-password --region $AWS_REGION)
```

Then update `chart/values-override-persistence.yaml`:

```yaml
images:
  airflow:
    repository: <your-account-id>.dkr.ecr.us-west-1.amazonaws.com/my-dags
    tag: latest # or specific tag
    pullPolicy: Always
  pullSecret: ecr-secret # Add this line
```

### For Production (EKS)

If using EKS with IAM roles for service accounts, you don't need image pull secrets:

```yaml
images:
  airflow:
    repository: <your-account-id>.dkr.ecr.us-west-1.amazonaws.com/my-dags
    tag: latest
    pullPolicy: Always
```

## 5. Automatic Deployment via GitHub Actions

Once configured, every push to `main` branch will:

1. Build the Docker image (with dependencies only, no DAGs)
2. Push to ECR with timestamp tag (e.g., `20251007143000`)
3. Push to ECR with `latest` tag
4. DAGs are synced via git-sync, not baked into the image

## 6. Verify Image in ECR

```bash
# List images in your ECR repository
aws ecr describe-images \
    --repository-name my-dags \
    --region us-west-1 \
    --output table
```

## Important Notes

- **DAGs are NOT in the Docker image** - they're synced from GitHub via git-sync
- The Docker image only contains:
  - Apache Airflow base image
  - Python dependencies from `requirements.txt`
- ECR authentication tokens expire after 12 hours, so you may need to recreate the pull secret periodically
- For production, use IAM roles with EKS for automatic authentication

## Troubleshooting

### Image pull errors in Kind

```bash
# Check if secret exists
kubectl get secret ecr-secret -n airflow

# Recreate if needed
kubectl delete secret ecr-secret -n airflow
# Then run the create secret command again
```

### Check if image was pushed successfully

```bash
aws ecr list-images --repository-name my-dags --region us-west-1
```

### Pull image locally to test

```bash
docker pull $ECR_REGISTRY/my-dags:latest
```
