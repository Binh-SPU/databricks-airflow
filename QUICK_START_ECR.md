# Quick Start: Push to Amazon ECR

## One-Time Setup (First time only)

### 1. Create ECR Repository

```bash
aws ecr create-repository \
    --repository-name my-dags \
    --region us-west-1 \
    --image-scanning-configuration scanOnPush=true
```

Note the `repositoryUri` from output (e.g., `123456789012.dkr.ecr.us-west-1.amazonaws.com`)

### 2. Configure GitHub Secrets

In your GitHub repo → Settings → Secrets → Actions, add:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `ECR_REGISTRY` (e.g., `123456789012.dkr.ecr.us-west-1.amazonaws.com`)

## Manual Push (Testing)

```bash
# Set your ECR registry
export ECR_REGISTRY=<your-account-id>.dkr.ecr.us-west-1.amazonaws.com
export AWS_REGION=us-west-1

# Run the push script
./push_to_ecr.sh
```

## Automatic Push (Production)

Simply push to `main` branch:

```bash
git add .
git commit -m "Update dependencies"
git push origin main
```

GitHub Actions will automatically:

- Build the image with only dependencies (no DAGs)
- Push to ECR with timestamp and `latest` tags

## Use ECR Image in Airflow

### Update your values file:

```yaml
# chart/values-override-persistence.yaml
images:
  airflow:
    repository: <account-id>.dkr.ecr.us-west-1.amazonaws.com/my-dags
    tag: latest
    pullPolicy: Always
```

### Create pull secret (for Kind/local):

```bash
kubectl create secret docker-registry ecr-secret \
    --namespace airflow \
    --docker-server=$ECR_REGISTRY \
    --docker-username=AWS \
    --docker-password=$(aws ecr get-login-password --region us-west-1)
```

### Upgrade Airflow:

```bash
helm upgrade airflow apache-airflow/airflow \
    -n airflow \
    -f chart/values-override-persistence.yaml
```

## Key Points

✅ **DAGs are NOT in Docker image** - synced via git-sync from GitHub
✅ **Image only contains dependencies** from requirements.txt
✅ **Two workflows**:

- Dev: Manual push with `push_to_ecr.sh`
- Prod: Automatic on git push to main

## Verify

```bash
# List images in ECR
aws ecr describe-images --repository-name my-dags --region us-west-1

# Check if Airflow is using ECR image
kubectl get pods -n airflow -o yaml | grep image:
```
