#!/bin/bash

# Your AWS account ID and region
AWS_ACCOUNT_ID="054037117483"
REGION="eu-central-1"
REPO_PREFIX="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# All public Docker images to transfer from Docker Hub
IMAGES=(
  "akiltipu/node-app"
  "akiltipu/cartservice"
  "akiltipu/shippingservice"
  "akiltipu/recommendationservice"
  "akiltipu/productcatalogservice"
  "akiltipu/paymentservice"
  "akiltipu/loadgenerator"
  "akiltipu/frontend"
  "akiltipu/emailservice"
  "akiltipu/currencyservice"
  "akiltipu/checkoutservice"
  "akiltipu/src"
  "akiltipu/adservice"
  "akiltipu/boutique-shop-microservice"
)



# Loop through each image
for IMAGE in "${IMAGES[@]}"; do
  SHORT_NAME=$(basename "$IMAGE")

  # Determine correct tag
  if [ "$IMAGE" == "akiltipu/node-app" ]; then
    SOURCE_TAG="1.0.0"
  else
    SOURCE_TAG="latest"
  fi

  TARGET_IMAGE="${REPO_PREFIX}/${SHORT_NAME}:${SOURCE_TAG}"

  echo "📦 Pulling public image: $IMAGE:$SOURCE_TAG"
  docker pull "$IMAGE:$SOURCE_TAG" || { echo "❌ Failed to pull $IMAGE:$SOURCE_TAG"; continue; }

  # ... rest of your logic


  echo "🛰️  Creating ECR repo if not exists: $SHORT_NAME"
  aws ecr describe-repositories --repository-names "$SHORT_NAME" --region "$REGION" > /dev/null 2>&1 \
    || aws ecr create-repository --repository-name "$SHORT_NAME" --region "$REGION"

  echo "🏷️  Tagging image for ECR: $TARGET_IMAGE"
  docker tag "$IMAGE:$SOURCE_TAG" "$TARGET_IMAGE"

  echo "🚀 Pushing to ECR: $TARGET_IMAGE"
  docker push "$TARGET_IMAGE"

  echo "✅ Done: $SHORT_NAME"
  echo "-------------------------------"
done

echo "🎉 All images copied to ECR successfully."
