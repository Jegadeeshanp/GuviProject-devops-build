#!/usr/bin/env bash
# build.sh - build react app, build docker image, tag and push to Docker Hub
# Usage:
#   ./build.sh [tag]
# Examples:
#   ./build.sh latest
#   ./build.sh dev-abc123
set -euo pipefail

REPO="jegadeeshanjeggy"
IMAGE_NAME="dev-app"

# Accept optional tag param, default to 'latest'
TAG="${1:-latest}"
FULL_IMAGE="${REPO}/${IMAGE_NAME}:${TAG}"

echo "=== build.sh starting ==="
echo "Repository root: $(pwd)"
echo "Image to create: ${FULL_IMAGE}"

# 1) Ensure build directory exists (run npm build if source present)
if [ -f package.json ]; then
  echo "package.json found — running npm ci and npm run build"
  # prefer npm ci if lockfile present
  if [ -f package-lock.json ]; then
    npm ci --no-audit --no-fund
  else
    npm install --no-audit --no-fund
  fi

  # Build step (React creates ./build/)
  npm run build
else
  echo "No package.json found. Skipping npm build step (assuming prebuilt 'build/' exists)."
fi

# 2) Build docker image (Dockerfile expects a build/ directory to copy)
echo "Building Docker image ${FULL_IMAGE} ..."
docker build -t "${FULL_IMAGE}" .

# 3) Optionally also tag :latest for convenience (if tag isn't latest)
if [ "${TAG}" != "latest" ]; then
  docker tag "${FULL_IMAGE}" "${REPO}/${IMAGE_NAME}:latest"
  echo "Also tagged ${REPO}/${IMAGE_NAME}:latest"
fi

# 4) Docker login (use env vars if set)
if [ -n "${DOCKERHUB_USER:-}" ] && [ -n "${DOCKERHUB_PASS:-}" ]; then
  echo "Logging into Docker Hub using DOCKERHUB_USER env var"
  echo "${DOCKERHUB_PASS}" | docker login --username "${DOCKERHUB_USER}" --password-stdin
else
  # If no env vars, try interactive login (will prompt)
  echo "DOCKERHUB_USER/DOCKERHUB_PASS not found. You will be prompted to docker login if needed."
fi

# 5) Push the images
echo "Pushing ${FULL_IMAGE} ..."
docker push "${FULL_IMAGE}"

if [ "${TAG}" != "latest" ]; then
  echo "Pushing ${REPO}/${IMAGE_NAME}:latest ..."
  docker push "${REPO}/${IMAGE_NAME}:latest"
fi

echo "=== build.sh finished: pushed ${FULL_IMAGE} ==="

