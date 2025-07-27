#!/bin/bash

set -e

ECR_PREFIX="054037117483.dkr.ecr.eu-central-1.amazonaws.com"
SOURCE_PREFIX="us-central1-docker.pkg.dev/google-samples/microservices-demo"
TAG="v0.10.3"
SERVICES=(
  adservice cartservice checkoutservice currencyservice emailservice
  frontend loadgenerator paymentservice productcatalogservice
  recommendationservice shippingservice
)

echo "🔐 Logging into AWS ECR..."
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin ${ECR_PREFIX}

for SVC in "${SERVICES[@]}"; do
  SRC="${SOURCE_PREFIX}/${SVC}:${TAG}"
  DST="${ECR_PREFIX}/${SVC}:${TAG}"

  echo "📦 Pulling ${SRC}..."
  docker pull "${SRC}" || { echo "❌ Failed: ${SRC}"; continue; }

  echo "🔁 Tagging as ${DST}..."
  docker tag "${SRC}" "${DST}"

  echo "📤 Pushing to ECR..."
  docker push "${DST}"
  echo "✅ Done with ${SVC}"
done

echo "🎉 All done!"


